-- ==============================================================================
-- FIX PAYMENTS TABLE RLS PERMISSION FOR OWNER PORTAL & POS COUNTER
-- Run this in Supabase Dashboard -> SQL Editor
-- This allows the Owner Portal & POS to read granular payment splits (Cash & GPay)
-- ==============================================================================

-- 1. Ensure RLS is active on public.payments
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- 2. Allow public and anon to SELECT payments (for split payment breakdowns)
DROP POLICY IF EXISTS "Allow read payments" ON public.payments;
CREATE POLICY "Allow read payments" ON public.payments FOR SELECT TO public USING (true);

-- 3. Allow public and anon to INSERT/UPDATE payments
DROP POLICY IF EXISTS "Allow write payments" ON public.payments;
CREATE POLICY "Allow write payments" ON public.payments FOR ALL TO public USING (true) WITH CHECK (true);

-- 4. Grant table access to anon, authenticated, service_role
GRANT ALL ON TABLE public.payments TO anon, authenticated, service_role;
