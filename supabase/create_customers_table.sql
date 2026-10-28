-- ==============================================================================
-- CUSTOMER DIRECTORY & DATA COLLECTION TABLE
-- Stores unique customers by phone for CRM, repeat visits & order history
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    total_orders INT DEFAULT 1,
    total_spent NUMERIC(10, 2) DEFAULT 0.00,
    last_order_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- Enable RLS and public access policy
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read/write to customers"
    ON public.customers
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Index for instant phone number lookups
CREATE INDEX IF NOT EXISTS idx_customers_phone ON public.customers(phone);
