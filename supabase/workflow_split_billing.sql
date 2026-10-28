-- ==============================================================================
-- CFC RESTAURANT POS: SPLIT PRINT & PAYMENT WORKFLOW MIGRATION
-- ==============================================================================
-- Implements:
--   1. Separate Print Bill from Payment:
--      Order -> Print Bill (UNPAID / Locked Snapshot) -> Payment Counter -> Finalize
--   2. Bill Versioning:
--      Editing a printed bill preserves the SAME bill_number and creates Version 2, 3...
--   3. Split Payments:
--      Supports CASH, GPAY, and SPLIT (Cash + GPay) recorded against the bill
--   4. Void / Refund with Owner Approvals:
--      Unpaid -> VOID_PENDING -> Approved -> CANCELLED
--      Paid -> REFUND_PENDING -> Approved -> REFUNDED
--   5. Multi-Shop Accounting Preservation:
--      Line items retain shop_id for accurate multi-shop financial breakdowns
-- ==============================================================================

-- 1. DROP EXISTING VIEW TO ALLOW TABLE COLUMN TYPE MODIFICATIONS
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.view_bill_details CASCADE;

-- 2. ENHANCE BILLS & ORDERS TABLES
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    ALTER TYPE order_status_enum ADD VALUE IF NOT EXISTS 'PRINTED';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE public.bills ALTER COLUMN payment_method DROP NOT NULL;
ALTER TABLE public.bills ALTER COLUMN payment_method TYPE TEXT USING payment_method::text;
ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_payment_status_check;

ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS current_version INT NOT NULL DEFAULT 1;
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'PRINTED';
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS printed_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());
ALTER TABLE public.bills ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Update status check constraint to support full lifecycle
ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_status_check;
ALTER TABLE public.bills ADD CONSTRAINT bills_status_check 
    CHECK (status IN ('PRINTED', 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'VOID_PENDING', 'CANCELLED', 'REFUND_PENDING', 'REFUNDED'));

-- 2. CREATE BILL VERSIONS TABLE (Immutable historical print snapshots)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bill_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    tax NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    print_reason TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE (bill_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_bill_versions_bill_id ON public.bill_versions(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_versions_created_at ON public.bill_versions(created_at);

-- 3. LINK BILL ITEMS TO BILL VERSIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.bill_items ADD COLUMN IF NOT EXISTS bill_version_id UUID REFERENCES public.bill_versions(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_bill_items_version_id ON public.bill_items(bill_version_id);

-- 4. CREATE PAYMENTS TABLE (Supports Cash, GPay, and Split Payments)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL, -- 'CASH', 'GPAY', 'CARD', 'UPI', 'OTHER'
    amount NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'COMPLETED', -- 'COMPLETED', 'REFUNDED'
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_payments_bill_id ON public.payments(bill_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON public.payments(created_at);

-- 5. CREATE VOID / REFUND REQUESTS TABLE (Audit trail & Owner Approvals)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.void_refund_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL CHECK (request_type IN ('VOID', 'REFUND')),
    reason TEXT NOT NULL,
    requested_by UUID REFERENCES auth.users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_void_refund_bill_id ON public.void_refund_requests(bill_id);
CREATE INDEX IF NOT EXISTS idx_void_refund_status ON public.void_refund_requests(status);

-- 6. MIGRATE EXISTING BILLS TO VERSION 1 AND PAYMENTS IF NOT PRESENT
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    v_b RECORD;
    v_version_id UUID;
BEGIN
    FOR v_b IN SELECT * FROM public.bills LOOP
        -- Ensure version 1 exists
        IF NOT EXISTS (SELECT 1 FROM public.bill_versions WHERE bill_id = v_b.id AND version_number = 1) THEN
            INSERT INTO public.bill_versions (bill_id, version_number, subtotal, discount, tax, total_amount, created_at, created_by)
            VALUES (v_b.id, 1, v_b.subtotal, v_b.discount, v_b.tax, v_b.total_amount, v_b.created_at, v_b.created_by)
            RETURNING id INTO v_version_id;

            -- Associate existing bill items with version 1
            UPDATE public.bill_items
            SET bill_version_id = v_version_id
            WHERE bill_id = v_b.id AND bill_version_id IS NULL;
        END IF;

        -- If bill was marked PAID, ensure paid_amount and payment record exist
        IF v_b.payment_status = 'PAID' THEN
            UPDATE public.bills 
            SET status = 'PAID', paid_amount = v_b.total_amount 
            WHERE id = v_b.id AND paid_amount = 0.00;

            IF NOT EXISTS (SELECT 1 FROM public.payments WHERE bill_id = v_b.id) THEN
                INSERT INTO public.payments (bill_id, payment_method, amount, created_at, created_by)
                VALUES (v_b.id, COALESCE(v_b.payment_method::text, 'CASH'), v_b.total_amount, v_b.created_at, v_b.created_by);
            END IF;
        END IF;
    END LOOP;
END $$;

-- 7. ATOMIC STORED PROCEDURE: print_bill_transaction
-- Initial bill print. Generates bill number, creates Version 1, locks order, marks UNPAID.
-- Does NOT require payment method.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.print_bill_transaction(
    p_order_id UUID,
    p_discount NUMERIC(10, 2) DEFAULT 0.00,
    p_tax NUMERIC(10, 2) DEFAULT 0.00,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_order RECORD;
    v_bill_id UUID;
    v_bill_number TEXT;
    v_version_id UUID;
    v_subtotal NUMERIC(10, 2);
    v_total NUMERIC(10, 2);
    v_item RECORD;
BEGIN
    -- 1. Lock and validate order
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    -- If bill already exists for this order, return the existing bill
    SELECT id, bill_number INTO v_bill_id, v_bill_number 
    FROM public.bills 
    WHERE order_id = p_order_id 
    LIMIT 1;

    IF v_bill_id IS NOT NULL THEN
        SELECT total_amount INTO v_total FROM public.bills WHERE id = v_bill_id;
        RETURN jsonb_build_object(
            'success', true,
            'bill_id', v_bill_id,
            'bill_number', v_bill_number,
            'version_number', 1,
            'total_amount', v_total,
            'status', 'PRINTED'
        );
    END IF;

    -- 2. Validate Order Items
    SELECT COALESCE(SUM(subtotal), 0) INTO v_subtotal
    FROM public.order_items
    WHERE order_id = p_order_id;

    IF v_subtotal <= 0 THEN
        RAISE EXCEPTION 'Cannot print a bill for an order with no items.';
    END IF;

    v_total := GREATEST(0, (v_subtotal - COALESCE(p_discount, 0)) + COALESCE(p_tax, 0));

    -- 3. Generate Bill Number (e.g. BILL-20260925-0045)
    v_bill_number := public.generate_bill_number();

    -- 4. Create Master Bill (Marked PRINTED / UNPAID, NO payment method attached)
    INSERT INTO public.bills (
        bill_number,
        order_id,
        subtotal,
        discount,
        tax,
        total_amount,
        paid_amount,
        current_version,
        status,
        payment_method,
        payment_status,
        created_by,
        printed_at
    )
    VALUES (
        v_bill_number,
        p_order_id,
        v_subtotal,
        COALESCE(p_discount, 0),
        COALESCE(p_tax, 0),
        v_total,
        0.00,
        1,
        'PRINTED',
        NULL,
        'UNPAID',
        p_user_id,
        timezone('utc'::text, now())
    )
    RETURNING id INTO v_bill_id;

    -- 5. Create Bill Version 1 Snapshot
    INSERT INTO public.bill_versions (
        bill_id,
        version_number,
        subtotal,
        discount,
        tax,
        total_amount,
        print_reason,
        created_by,
        created_at
    )
    VALUES (
        v_bill_id,
        1,
        v_subtotal,
        COALESCE(p_discount, 0),
        COALESCE(p_tax, 0),
        v_total,
        'Initial Print',
        p_user_id,
        timezone('utc'::text, now())
    )
    RETURNING id INTO v_version_id;

    -- 6. Copy Order Items to Bill Items snapshot (Preserving shop_id and price)
    FOR v_item IN (SELECT * FROM public.order_items WHERE order_id = p_order_id) LOOP
        INSERT INTO public.bill_items (
            bill_id,
            bill_version_id,
            shop_id,
            product_id,
            product_name,
            quantity,
            unit_price,
            subtotal
        )
        VALUES (
            v_bill_id,
            v_version_id,
            v_item.shop_id,
            v_item.product_id,
            v_item.product_name,
            v_item.quantity,
            v_item.unit_price,
            v_item.subtotal
        );
    END LOOP;

    -- 7. Update Order status to indicate it has been printed
    UPDATE public.orders
    SET 
        status = 'PRINTED',
        subtotal = v_subtotal,
        discount = COALESCE(p_discount, 0),
        tax = COALESCE(p_tax, 0),
        total_amount = v_total,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'bill_id', v_bill_id,
        'bill_number', v_bill_number,
        'version_number', 1,
        'total_amount', v_total,
        'status', 'PRINTED'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. ATOMIC STORED PROCEDURE: update_bill_version_transaction
-- Reopens an existing bill after modifications.
-- PRESERVES the same bill_number, increments current_version to 2, 3...
-- Retains prior versions in history for auditing.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_bill_version_transaction(
    p_bill_id UUID,
    p_discount NUMERIC(10, 2) DEFAULT 0.00,
    p_tax NUMERIC(10, 2) DEFAULT 0.00,
    p_user_id UUID DEFAULT NULL,
    p_print_reason TEXT DEFAULT 'Items updated'
)
RETURNS JSONB AS $$
DECLARE
    v_bill RECORD;
    v_new_version INT;
    v_version_id UUID;
    v_subtotal NUMERIC(10, 2);
    v_total NUMERIC(10, 2);
    v_new_status TEXT;
    v_item RECORD;
BEGIN
    -- 1. Lock and validate master bill
    SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bill not found.';
    END IF;

    IF v_bill.status IN ('CANCELLED', 'REFUNDED') THEN
        RAISE EXCEPTION 'Cannot edit a cancelled or refunded bill.';
    END IF;

    -- 2. Calculate subtotal from current order_items
    SELECT COALESCE(SUM(subtotal), 0) INTO v_subtotal
    FROM public.order_items
    WHERE order_id = v_bill.order_id;

    IF v_subtotal <= 0 THEN
        RAISE EXCEPTION 'Order has no items.';
    END IF;

    v_total := GREATEST(0, (v_subtotal - COALESCE(p_discount, 0)) + COALESCE(p_tax, 0));
    v_new_version := v_bill.current_version + 1;

    -- 3. Determine new payment status based on amount already paid
    IF v_bill.paid_amount >= v_total THEN
        v_new_status := 'PAID';
    ELSIF v_bill.paid_amount > 0 THEN
        v_new_status := 'PARTIALLY_PAID';
    ELSE
        v_new_status := 'PRINTED';
    END IF;

    -- 4. Update master bill (preserves same bill_number, increments version)
    UPDATE public.bills
    SET
        current_version = v_new_version,
        subtotal = v_subtotal,
        discount = COALESCE(p_discount, 0),
        tax = COALESCE(p_tax, 0),
        total_amount = v_total,
        status = v_new_status,
        payment_status = CASE WHEN v_new_status = 'PAID' THEN 'PAID' ELSE 'UNPAID' END,
        printed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_bill_id;

    -- 5. Insert new Version record
    INSERT INTO public.bill_versions (
        bill_id,
        version_number,
        subtotal,
        discount,
        tax,
        total_amount,
        print_reason,
        created_by,
        created_at
    )
    VALUES (
        p_bill_id,
        v_new_version,
        v_subtotal,
        COALESCE(p_discount, 0),
        COALESCE(p_tax, 0),
        v_total,
        p_print_reason,
        p_user_id,
        timezone('utc'::text, now())
    )
    RETURNING id INTO v_version_id;

    -- 6. Insert new items snapshot tied to this version
    FOR v_item IN (SELECT * FROM public.order_items WHERE order_id = v_bill.order_id) LOOP
        INSERT INTO public.bill_items (
            bill_id,
            bill_version_id,
            shop_id,
            product_id,
            product_name,
            quantity,
            unit_price,
            subtotal
        )
        VALUES (
            p_bill_id,
            v_version_id,
            v_item.shop_id,
            v_item.product_id,
            v_item.product_name,
            v_item.quantity,
            v_item.unit_price,
            v_item.subtotal
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'bill_id', p_bill_id,
        'bill_number', v_bill.bill_number,
        'version_number', v_new_version,
        'total_amount', v_total,
        'paid_amount', v_bill.paid_amount,
        'status', v_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. ATOMIC STORED PROCEDURE: record_bill_payment_transaction
-- Records payment at the Payment Counter.
-- Supports CASH, GPAY, and SPLIT payments.
-- When paid in full, marks bill PAID and releases table session.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_bill_payment_transaction(
    p_bill_id UUID,
    p_payments JSONB, -- Array of {"method": "CASH"|"GPAY"|..., "amount": 400.0}
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_bill RECORD;
    v_order RECORD;
    v_pay RECORD;
    v_new_paid_total NUMERIC(10, 2);
    v_payment_method TEXT;
    v_new_status TEXT;
    v_table_record RECORD;
    v_payment_count INT;
BEGIN
    -- 1. Lock and validate bill
    SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bill not found.';
    END IF;

    IF v_bill.status IN ('CANCELLED', 'REFUNDED') THEN
        RAISE EXCEPTION 'Cannot record payment for a cancelled or refunded bill.';
    END IF;

    IF v_bill.status = 'PAID' AND v_bill.paid_amount >= v_bill.total_amount THEN
        RAISE EXCEPTION 'Bill % is already paid in full.', v_bill.bill_number;
    END IF;

    -- 2. Insert payment entries into payments table
    v_payment_count := jsonb_array_length(p_payments);
    IF v_payment_count = 0 THEN
        RAISE EXCEPTION 'No payment details provided.';
    END IF;

    FOR v_pay IN SELECT * FROM jsonb_to_recordset(p_payments) AS x(method TEXT, amount NUMERIC) LOOP
        IF v_pay.amount > 0 THEN
            INSERT INTO public.payments (
                bill_id,
                payment_method,
                amount,
                status,
                created_by,
                created_at
            )
            VALUES (
                p_bill_id,
                UPPER(v_pay.method),
                v_pay.amount,
                'COMPLETED',
                p_user_id,
                timezone('utc'::text, now())
            );
        END IF;
    END LOOP;

    -- 3. Calculate new total paid from all payments on this bill
    SELECT COALESCE(SUM(amount), 0) INTO v_new_paid_total
    FROM public.payments
    WHERE bill_id = p_bill_id AND status = 'COMPLETED';

    -- Determine primary payment method name
    IF v_payment_count > 1 THEN
        v_payment_method := 'SPLIT';
    ELSE
        SELECT payment_method INTO v_payment_method 
        FROM public.payments 
        WHERE bill_id = p_bill_id 
        ORDER BY created_at DESC 
        LIMIT 1;
    END IF;

    -- Determine new status
    IF v_new_paid_total >= v_bill.total_amount THEN
        v_new_status := 'PAID';
    ELSE
        v_new_status := 'PARTIALLY_PAID';
    END IF;

    -- 4. Update Bill
    UPDATE public.bills
    SET
        paid_amount = v_new_paid_total,
        status = v_new_status,
        payment_status = v_new_status,
        payment_method = COALESCE(v_payment_method, 'CASH'),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_bill_id;

    -- 5. If Bill is fully paid: complete order & release table session
    IF v_new_status = 'PAID' THEN
        SELECT * INTO v_order FROM public.orders WHERE id = v_bill.order_id;
        
        UPDATE public.orders
        SET 
            status = 'COMPLETED',
            completed_at = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = v_bill.order_id;

        IF v_order.table_session_id IS NOT NULL THEN
            -- Close table session
            UPDATE public.table_sessions
            SET 
                status = 'CLOSED',
                closed_at = timezone('utc'::text, now()),
                updated_at = timezone('utc'::text, now())
            WHERE id = v_order.table_session_id;

            -- Mark left_at on session tables
            UPDATE public.table_session_tables
            SET left_at = timezone('utc'::text, now())
            WHERE session_id = v_order.table_session_id AND left_at IS NULL;

            -- Release all tables in this session back to AVAILABLE
            FOR v_table_record IN (
                SELECT table_id FROM public.table_session_tables 
                WHERE session_id = v_order.table_session_id
            ) LOOP
                UPDATE public.dining_tables
                SET status = 'AVAILABLE', updated_at = timezone('utc'::text, now())
                WHERE id = v_table_record.table_id;
            END LOOP;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'bill_id', p_bill_id,
        'bill_number', v_bill.bill_number,
        'total_amount', v_bill.total_amount,
        'paid_amount', v_new_paid_total,
        'status', v_new_status,
        'payment_method', v_payment_method
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. ATOMIC STORED PROCEDURE: request_void_or_refund
-- Staff requests a VOID (for unpaid bill) or REFUND (for paid bill)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_void_or_refund(
    p_bill_id UUID,
    p_request_type TEXT, -- 'VOID' or 'REFUND'
    p_reason TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_bill RECORD;
    v_req_id UUID;
    v_new_status TEXT;
BEGIN
    SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bill not found.';
    END IF;

    IF UPPER(p_request_type) = 'VOID' THEN
        IF v_bill.status = 'PAID' THEN
            RAISE EXCEPTION 'Paid bills must use REFUND request, not VOID.';
        END IF;
        v_new_status := 'VOID_PENDING';
    ELSIF UPPER(p_request_type) = 'REFUND' THEN
        IF v_bill.status != 'PAID' AND v_bill.paid_amount <= 0 THEN
            RAISE EXCEPTION 'Only paid bills can be refunded.';
        END IF;
        v_new_status := 'REFUND_PENDING';
    ELSE
        RAISE EXCEPTION 'Invalid request type. Must be VOID or REFUND.';
    END IF;

    -- Update bill status to pending approval
    UPDATE public.bills
    SET status = v_new_status, updated_at = timezone('utc'::text, now())
    WHERE id = p_bill_id;

    -- Insert audit request
    INSERT INTO public.void_refund_requests (
        bill_id,
        request_type,
        reason,
        requested_by,
        status,
        requested_at
    )
    VALUES (
        p_bill_id,
        UPPER(p_request_type),
        p_reason,
        p_user_id,
        'PENDING',
        timezone('utc'::text, now())
    )
    RETURNING id INTO v_req_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_req_id,
        'bill_id', p_bill_id,
        'status', v_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. ATOMIC STORED PROCEDURE: approve_void_or_refund
-- Owner / Admin approves or rejects the pending request
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_void_or_refund(
    p_request_id UUID,
    p_approve BOOLEAN,
    p_admin_user_id UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_req RECORD;
    v_bill RECORD;
    v_order RECORD;
    v_table_record RECORD;
    v_new_status TEXT;
BEGIN
    SELECT * INTO v_req FROM public.void_refund_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Request not found.';
    END IF;

    IF v_req.status != 'PENDING' THEN
        RAISE EXCEPTION 'Request has already been processed.';
    END IF;

    SELECT * INTO v_bill FROM public.bills WHERE id = v_req.bill_id FOR UPDATE;

    IF p_approve THEN
        IF v_req.request_type = 'VOID' THEN
            v_new_status := 'CANCELLED';
        ELSE
            v_new_status := 'REFUNDED';
        END IF;

        -- Update bill
        UPDATE public.bills
        SET 
            status = v_new_status,
            payment_status = CASE WHEN v_new_status = 'REFUNDED' THEN 'REFUNDED' ELSE 'CANCELLED' END,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_bill.id;

        -- If voiding an order that held tables, release tables
        SELECT * INTO v_order FROM public.orders WHERE id = v_bill.order_id;
        IF v_order.table_session_id IS NOT NULL THEN
            UPDATE public.table_sessions
            SET status = 'CLOSED', closed_at = timezone('utc'::text, now())
            WHERE id = v_order.table_session_id;

            FOR v_table_record IN (
                SELECT table_id FROM public.table_session_tables 
                WHERE session_id = v_order.table_session_id
            ) LOOP
                UPDATE public.dining_tables
                SET status = 'AVAILABLE', updated_at = timezone('utc'::text, now())
                WHERE id = v_table_record.table_id;
            END LOOP;
        END IF;

        UPDATE public.void_refund_requests
        SET 
            status = 'APPROVED',
            approved_by = p_admin_user_id,
            approved_at = timezone('utc'::text, now()),
            notes = p_notes
        WHERE id = p_request_id;
    ELSE
        -- Rejected: Revert bill back to normal state
        IF v_req.request_type = 'VOID' THEN
            v_new_status := 'PRINTED';
        ELSE
            v_new_status := 'PAID';
        END IF;

        UPDATE public.bills
        SET status = v_new_status, updated_at = timezone('utc'::text, now())
        WHERE id = v_bill.id;

        UPDATE public.void_refund_requests
        SET 
            status = 'REJECTED',
            approved_by = p_admin_user_id,
            approved_at = timezone('utc'::text, now()),
            notes = p_notes
        WHERE id = p_request_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'approved', p_approve,
        'bill_status', v_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. UPDATE VIEW: view_bill_details
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.view_bill_details CASCADE;

CREATE VIEW public.view_bill_details AS
SELECT 
    b.id AS bill_id,
    b.id,
    b.bill_number,
    b.created_at AS bill_time,
    b.created_at,
    b.printed_at,
    b.updated_at,
    b.current_version,
    b.status,
    b.payment_status,
    b.payment_method,
    b.subtotal,
    b.discount,
    b.tax,
    b.total_amount,
    b.paid_amount,
    o.id AS order_id,
    o.order_number,
    o.order_type,
    o.customer_name,
    o.customer_phone,
    o.delivery_address,
    ts.session_number,
    COALESCE(
        string_agg(DISTINCT dt.table_name, ' + ' ORDER BY dt.table_name),
        'N/A'
    ) AS tables_display
FROM public.bills b
JOIN public.orders o ON o.id = b.order_id
LEFT JOIN public.table_sessions ts ON ts.id = o.table_session_id
LEFT JOIN public.table_session_tables tst ON tst.session_id = ts.id
LEFT JOIN public.dining_tables dt ON dt.id = tst.table_id
GROUP BY b.id, o.id, ts.session_number;

-- 13. GRANT SECURITY & PERMISSIONS
-- ------------------------------------------------------------------------------
GRANT ALL ON TABLE public.bill_versions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payments TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.void_refund_requests TO anon, authenticated, service_role;
GRANT SELECT ON public.view_bill_details TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.print_bill_transaction TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_bill_version_transaction TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_bill_payment_transaction TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_void_or_refund TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.approve_void_or_refund TO anon, authenticated, service_role;
