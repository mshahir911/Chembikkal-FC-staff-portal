-- ==============================================================================
-- RLS PERMISSION PATCH FOR POS TERMINALS (ANON & AUTHENTICATED ACCESS)
-- Run this in Supabase SQL Editor so your POS terminals can read/write data
-- seamlessly using the Anon key without being blocked by RLS.
-- ==============================================================================

-- 1. Shops (Public read)
DROP POLICY IF EXISTS "Allow authenticated read shops" ON public.shops;
DROP POLICY IF EXISTS "Allow read shops" ON public.shops;
CREATE POLICY "Allow read shops" ON public.shops FOR SELECT TO public USING (true);

-- 2. Products (Public read)
DROP POLICY IF EXISTS "Allow authenticated read products" ON public.products;
DROP POLICY IF EXISTS "Allow read products" ON public.products;
CREATE POLICY "Allow read products" ON public.products FOR SELECT TO public USING (true);

-- 3. Dining Tables (Public read & update status)
DROP POLICY IF EXISTS "Allow authenticated read tables" ON public.dining_tables;
DROP POLICY IF EXISTS "Allow read tables" ON public.dining_tables;
CREATE POLICY "Allow read tables" ON public.dining_tables FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated update tables" ON public.dining_tables;
DROP POLICY IF EXISTS "Allow update tables" ON public.dining_tables;
CREATE POLICY "Allow update tables" ON public.dining_tables FOR ALL TO public USING (true) WITH CHECK (true);

-- 4. Table Sessions & Junction
DROP POLICY IF EXISTS "Allow authenticated read table_sessions" ON public.table_sessions;
DROP POLICY IF EXISTS "Allow read table_sessions" ON public.table_sessions;
CREATE POLICY "Allow read table_sessions" ON public.table_sessions FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated write table_sessions" ON public.table_sessions;
DROP POLICY IF EXISTS "Allow write table_sessions" ON public.table_sessions;
CREATE POLICY "Allow write table_sessions" ON public.table_sessions FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read table_session_tables" ON public.table_session_tables;
DROP POLICY IF EXISTS "Allow read table_session_tables" ON public.table_session_tables;
CREATE POLICY "Allow read table_session_tables" ON public.table_session_tables FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated write table_session_tables" ON public.table_session_tables;
DROP POLICY IF EXISTS "Allow write table_session_tables" ON public.table_session_tables;
CREATE POLICY "Allow write table_session_tables" ON public.table_session_tables FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read table_activity_logs" ON public.table_activity_logs;
DROP POLICY IF EXISTS "Allow read table_activity_logs" ON public.table_activity_logs;
CREATE POLICY "Allow read table_activity_logs" ON public.table_activity_logs FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated insert table_activity_logs" ON public.table_activity_logs;
DROP POLICY IF EXISTS "Allow insert table_activity_logs" ON public.table_activity_logs;
CREATE POLICY "Allow insert table_activity_logs" ON public.table_activity_logs FOR INSERT TO public WITH CHECK (true);

-- 5. Orders & Order Items
DROP POLICY IF EXISTS "Allow authenticated read orders" ON public.orders;
DROP POLICY IF EXISTS "Allow read orders" ON public.orders;
CREATE POLICY "Allow read orders" ON public.orders FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated write orders" ON public.orders;
DROP POLICY IF EXISTS "Allow write orders" ON public.orders;
CREATE POLICY "Allow write orders" ON public.orders FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow read order_items" ON public.order_items;
CREATE POLICY "Allow read order_items" ON public.order_items FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated write order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow write order_items" ON public.order_items;
CREATE POLICY "Allow write order_items" ON public.order_items FOR ALL TO public USING (true) WITH CHECK (true);

-- 6. Bills & Bill Items
DROP POLICY IF EXISTS "Allow authenticated read bills" ON public.bills;
DROP POLICY IF EXISTS "Allow read bills" ON public.bills;
CREATE POLICY "Allow read bills" ON public.bills FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated insert bills" ON public.bills;
DROP POLICY IF EXISTS "Allow insert bills" ON public.bills;
CREATE POLICY "Allow insert bills" ON public.bills FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated read bill_items" ON public.bill_items;
DROP POLICY IF EXISTS "Allow read bill_items" ON public.bill_items;
CREATE POLICY "Allow read bill_items" ON public.bill_items FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow authenticated insert bill_items" ON public.bill_items;
DROP POLICY IF EXISTS "Allow insert bill_items" ON public.bill_items;
CREATE POLICY "Allow insert bill_items" ON public.bill_items FOR ALL TO public USING (true) WITH CHECK (true);

-- 7. Grant execution on stored procedures to public/anon
GRANT EXECUTE ON FUNCTION public.create_dine_in_session(UUID, INT, UUID) TO public;
GRANT EXECUTE ON FUNCTION public.merge_tables(UUID, UUID[], UUID) TO public;
GRANT EXECUTE ON FUNCTION public.transfer_table(UUID, UUID, UUID) TO public;
GRANT EXECUTE ON FUNCTION public.complete_bill_transaction(UUID, payment_method_enum, NUMERIC, NUMERIC, UUID) TO public;
GRANT EXECUTE ON FUNCTION public.get_shop_sales_report(TIMESTAMPTZ, TIMESTAMPTZ) TO public;
GRANT EXECUTE ON FUNCTION public.get_order_type_sales_report(TIMESTAMPTZ, TIMESTAMPTZ) TO public;
GRANT EXECUTE ON FUNCTION public.get_shop_order_type_matrix(TIMESTAMPTZ, TIMESTAMPTZ) TO public;

-- 8. Payments Table (Full Anon & Authenticated access for POS terminals)
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow read payments" ON public.payments;
CREATE POLICY "Allow read payments" ON public.payments FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow write payments" ON public.payments;
CREATE POLICY "Allow write payments" ON public.payments FOR ALL TO public USING (true) WITH CHECK (true);

GRANT ALL ON TABLE public.payments TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_bill_payment_transaction(UUID, JSONB, UUID) TO public, anon, authenticated;

