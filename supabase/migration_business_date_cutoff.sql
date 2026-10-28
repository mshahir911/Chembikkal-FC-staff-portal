-- ==============================================================================
-- Chembikkal Food Court (CFC) - Business Day Cutoff & Business Date Migration
-- Cutoff: 3:00 AM IST (Offset: 3 hours)
-- Trading hours: 11:00 AM to 2:00 AM (+1 hour safety buffer for day-close)
-- ==============================================================================

-- 1. Helper function to compute business date from any timestamp in Asia/Kolkata
CREATE OR REPLACE FUNCTION public.calculate_business_date(ts TIMESTAMPTZ DEFAULT now())
RETURNS DATE
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT ((COALESCE(ts, now()) AT TIME ZONE 'Asia/Kolkata') - INTERVAL '3 hours')::date;
$$;

-- 2. Add business_date column to public.orders
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS business_date DATE;

-- Set default for new inserts
ALTER TABLE public.orders 
ALTER COLUMN business_date SET DEFAULT public.calculate_business_date(timezone('utc'::text, now()));

-- 3. Add business_date column to public.bills
ALTER TABLE public.bills 
ADD COLUMN IF NOT EXISTS business_date DATE;

-- Set default for new inserts
ALTER TABLE public.bills 
ALTER COLUMN business_date SET DEFAULT public.calculate_business_date(timezone('utc'::text, now()));

-- 4. Backfill historical orders and bills
UPDATE public.orders 
SET business_date = public.calculate_business_date(created_at)
WHERE business_date IS NULL;

UPDATE public.bills 
SET business_date = public.calculate_business_date(created_at)
WHERE business_date IS NULL;

-- Make business_date NOT NULL once backfilled
ALTER TABLE public.orders ALTER COLUMN business_date SET NOT NULL;
ALTER TABLE public.bills ALTER COLUMN business_date SET NOT NULL;

-- 5. Create fast lookup indexes on business_date
CREATE INDEX IF NOT EXISTS idx_orders_business_date ON public.orders (business_date);
CREATE INDEX IF NOT EXISTS idx_bills_business_date ON public.bills (business_date);

-- 5b. Update unique constraint on bills so bill numbers (001, 002, ...) reset daily per business date
ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_bill_number_key;
ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_bill_number_business_date_key;
ALTER TABLE public.bills ADD CONSTRAINT bills_bill_number_business_date_key UNIQUE (business_date, bill_number);


-- 6. Triggers to ensure business_date is automatically computed and kept in sync
CREATE OR REPLACE FUNCTION public.trg_set_business_date()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.created_at IS NOT NULL THEN
        NEW.business_date := public.calculate_business_date(NEW.created_at);
    ELSE
        NEW.business_date := public.calculate_business_date(now());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_orders_business_date ON public.orders;
CREATE TRIGGER set_orders_business_date
BEFORE INSERT OR UPDATE OF created_at ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_set_business_date();

DROP TRIGGER IF EXISTS set_bills_business_date ON public.bills;
CREATE TRIGGER set_bills_business_date
BEFORE INSERT OR UPDATE OF created_at ON public.bills
FOR EACH ROW
EXECUTE FUNCTION public.trg_set_business_date();

-- ==============================================================================
-- 7. UPDATE REPORTING VIEWS TO USE business_date DIRECTLY
-- ==============================================================================

-- Drop existing views to recreate clean definitions
DROP VIEW IF EXISTS public.monthly_shop_sales CASCADE;
DROP VIEW IF EXISTS public.daily_sales CASCADE;
DROP VIEW IF EXISTS public.daily_shop_sales CASCADE;
DROP VIEW IF EXISTS public.daily_shop_product_sales CASCADE;

-- ------------------------------------------------------------------------------
-- VIEW 1: daily_shop_sales
-- Aggregates sales per individual shop per business date.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.daily_shop_sales AS
WITH valid_bills AS (
    SELECT 
        b.id AS bill_id,
        b.bill_number,
        b.subtotal AS bill_subtotal,
        b.total_amount AS bill_total,
        b.status AS bill_status,
        b.payment_status,
        b.business_date AS sale_date
    FROM public.bills b
    WHERE b.status NOT IN ('CANCELLED', 'VOID_PENDING', 'REFUNDED')
),
shop_bill_totals AS (
    SELECT 
        vb.sale_date,
        bi.shop_id,
        s.name AS shop_name,
        s.code AS shop_code,
        s.display_order,
        COUNT(DISTINCT bi.bill_id) AS bill_count,
        SUM(bi.quantity) AS total_items_sold,
        SUM(bi.subtotal) AS total_revenue
    FROM valid_bills vb
    JOIN public.bill_items bi ON bi.bill_id = vb.bill_id
    JOIN public.shops s ON s.id = bi.shop_id
    GROUP BY vb.sale_date, bi.shop_id, s.name, s.code, s.display_order
),
shop_payments AS (
    SELECT 
        vb.sale_date,
        bi.shop_id,
        SUM(CASE WHEN UPPER(p.payment_method) = 'CASH' 
            THEN p.amount * (bi.subtotal / NULLIF(vb.bill_subtotal, 0)) 
            ELSE 0 END) AS cash_amount,
        SUM(CASE WHEN UPPER(p.payment_method) IN ('UPI', 'GPAY') 
            THEN p.amount * (bi.subtotal / NULLIF(vb.bill_subtotal, 0)) 
            ELSE 0 END) AS upi_amount,
        SUM(CASE WHEN UPPER(p.payment_method) = 'CARD' 
            THEN p.amount * (bi.subtotal / NULLIF(vb.bill_subtotal, 0)) 
            ELSE 0 END) AS card_amount,
        SUM(CASE WHEN UPPER(p.payment_method) NOT IN ('CASH', 'UPI', 'GPAY', 'CARD') 
            THEN p.amount * (bi.subtotal / NULLIF(vb.bill_subtotal, 0)) 
            ELSE 0 END) AS other_amount
    FROM valid_bills vb
    JOIN public.bill_items bi ON bi.bill_id = vb.bill_id
    JOIN public.payments p ON p.bill_id = vb.bill_id AND p.status = 'COMPLETED'
    WHERE vb.bill_subtotal > 0
    GROUP BY vb.sale_date, bi.shop_id
)
SELECT 
    sbt.sale_date,
    sbt.shop_id,
    sbt.shop_name,
    sbt.shop_code,
    sbt.display_order,
    sbt.bill_count,
    sbt.total_items_sold,
    ROUND(sbt.total_revenue, 2) AS total_revenue,
    ROUND(COALESCE(sp.cash_amount, 0), 2) AS cash_amount,
    ROUND(COALESCE(sp.upi_amount, 0), 2) AS upi_amount,
    ROUND(COALESCE(sp.card_amount, 0), 2) AS card_amount,
    ROUND(COALESCE(sp.other_amount, 0), 2) AS other_amount
FROM shop_bill_totals sbt
LEFT JOIN shop_payments sp 
    ON sp.sale_date = sbt.sale_date 
   AND sp.shop_id = sbt.shop_id;

-- ------------------------------------------------------------------------------
-- VIEW 2: daily_sales
-- Food-court-wide daily rollup combining all shops by business_date.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.daily_sales AS
WITH daily_bills AS (
    SELECT 
        b.business_date AS sale_date,
        b.id AS bill_id,
        b.total_amount,
        b.status,
        b.payment_status
    FROM public.bills b
    WHERE b.status NOT IN ('CANCELLED', 'VOID_PENDING', 'REFUNDED')
),
daily_payments AS (
    SELECT 
        b.business_date AS sale_date,
        SUM(CASE WHEN UPPER(p.payment_method) = 'CASH' THEN p.amount ELSE 0 END) AS cash_amount,
        SUM(CASE WHEN UPPER(p.payment_method) IN ('UPI', 'GPAY') THEN p.amount ELSE 0 END) AS upi_amount,
        SUM(CASE WHEN UPPER(p.payment_method) = 'CARD' THEN p.amount ELSE 0 END) AS card_amount,
        SUM(CASE WHEN UPPER(p.payment_method) NOT IN ('CASH', 'UPI', 'GPAY', 'CARD') THEN p.amount ELSE 0 END) AS other_amount,
        SUM(p.amount) AS total_collected
    FROM public.payments p
    JOIN public.bills b ON b.id = p.bill_id
    WHERE p.status = 'COMPLETED'
      AND b.status NOT IN ('CANCELLED', 'VOID_PENDING', 'REFUNDED')
    GROUP BY b.business_date
),
daily_bill_rollup AS (
    SELECT 
        db.sale_date,
        COUNT(DISTINCT db.bill_id) AS total_bills,
        SUM(db.total_amount) AS total_revenue,
        COUNT(DISTINCT CASE WHEN db.payment_status = 'PAID' THEN db.bill_id END) AS paid_bills,
        COUNT(DISTINCT CASE WHEN db.payment_status <> 'PAID' THEN db.bill_id END) AS unpaid_bills
    FROM daily_bills db
    GROUP BY db.sale_date
),
active_shops AS (
    SELECT 
        b.business_date AS sale_date,
        COUNT(DISTINCT bi.shop_id) AS active_shops_count
    FROM public.bills b
    JOIN public.bill_items bi ON bi.bill_id = b.id
    WHERE b.status NOT IN ('CANCELLED', 'VOID_PENDING', 'REFUNDED')
    GROUP BY b.business_date
)
SELECT 
    dbr.sale_date,
    ROUND(dbr.total_revenue, 2) AS total_revenue,
    dbr.total_bills,
    dbr.paid_bills,
    dbr.unpaid_bills,
    COALESCE(ash.active_shops_count, 0) AS active_shops_count,
    ROUND(COALESCE(dp.cash_amount, 0), 2) AS cash_amount,
    ROUND(COALESCE(dp.upi_amount, 0), 2) AS upi_amount,
    ROUND(COALESCE(dp.card_amount, 0), 2) AS card_amount,
    ROUND(COALESCE(dp.other_amount, 0), 2) AS other_amount,
    ROUND(COALESCE(dp.total_collected, 0), 2) AS total_collected
FROM daily_bill_rollup dbr
LEFT JOIN daily_payments dp ON dp.sale_date = dbr.sale_date
LEFT JOIN active_shops ash ON ash.sale_date = dbr.sale_date;

-- ------------------------------------------------------------------------------
-- VIEW 3: monthly_shop_sales
-- Monthly revenue breakdown per shop based on business_date.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.monthly_shop_sales AS
SELECT 
    to_char(sale_date, 'YYYY-MM') AS sale_month,
    shop_id,
    shop_name,
    shop_code,
    display_order,
    COUNT(DISTINCT sale_date) AS active_days,
    SUM(bill_count) AS total_bills,
    SUM(total_items_sold) AS total_items_sold,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(SUM(cash_amount), 2) AS cash_amount,
    ROUND(SUM(upi_amount), 2) AS upi_amount,
    ROUND(SUM(card_amount), 2) AS card_amount,
    ROUND(SUM(other_amount), 2) AS other_amount
FROM public.daily_shop_sales
GROUP BY to_char(sale_date, 'YYYY-MM'), shop_id, shop_name, shop_code, display_order;

-- ------------------------------------------------------------------------------
-- VIEW 4: daily_shop_product_sales
-- Item level sales per shop per business date.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.daily_shop_product_sales AS
SELECT 
    b.business_date AS sale_date,
    bi.shop_id,
    s.name AS shop_name,
    s.code AS shop_code,
    bi.product_id,
    bi.product_name,
    SUM(bi.quantity) AS quantity_sold,
    ROUND(SUM(bi.subtotal), 2) AS total_revenue,
    COUNT(DISTINCT bi.bill_id) AS order_count
FROM public.bills b
JOIN public.bill_items bi ON bi.bill_id = b.id
JOIN public.shops s ON s.id = bi.shop_id
WHERE b.status NOT IN ('CANCELLED', 'VOID_PENDING', 'REFUNDED')
GROUP BY 
    b.business_date,
    bi.shop_id,
    s.name,
    s.code,
    bi.product_id,
    bi.product_name;

-- 8. Grant permissions
GRANT SELECT ON public.daily_shop_sales TO anon, authenticated, service_role;
GRANT SELECT ON public.daily_sales TO anon, authenticated, service_role;
GRANT SELECT ON public.monthly_shop_sales TO anon, authenticated, service_role;
GRANT SELECT ON public.daily_shop_product_sales TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 9. Generate Daily Sequential Bill Number: '001', '002', '003'... per business day
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_bill_number()
RETURNS TEXT AS $$
DECLARE
    v_biz_date DATE := public.calculate_business_date(now());
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM public.bills 
    WHERE business_date = v_biz_date;
    
    RETURN lpad((v_count + 1)::text, 3, '0');
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.generate_bill_number TO anon, authenticated, service_role;

