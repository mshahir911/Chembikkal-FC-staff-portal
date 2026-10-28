-- ==============================================================================
-- MULTI-SHOP RESTAURANT POS & BILLING SYSTEM
-- SUPABASE POSTGRESQL COMPLETE DATABASE SCHEMA & STORED PROCEDURES
-- ==============================================================================
-- Designed for:
--  * 5+ physically separate shops located next to each other
--  * Single unified POS / common billing counter
--  * Dine-In (with Table Management & Multi-Table Merging), Take Away, Delivery
--  * Guaranteed Shop-Level Revenue Tracking (every bill item retains shop_id)
--  * 100% Atomic Transactions (Order completion, Billing, Table Release)
--  * Supabase Auth, Profiles, and Row Level Security (RLS)
--  * Comprehensive Reporting (Daily, Monthly, Custom Range, Shop-wise, Order-type-wise)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. ENUMS & DOMAINS
-- ==============================================================================
DO $$ BEGIN
    CREATE TYPE order_type_enum AS ENUM ('DINE_IN', 'TAKE_AWAY', 'DELIVERY');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE order_status_enum AS ENUM ('OPEN', 'IN_PROGRESS', 'READY', 'COMPLETED', 'CANCELLED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE table_status_enum AS ENUM ('AVAILABLE', 'OCCUPIED', 'MERGED', 'RESERVED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE session_status_enum AS ENUM ('OPEN', 'CLOSED', 'MERGED', 'CANCELLED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_method_enum AS ENUM ('CASH', 'UPI', 'CARD', 'OTHER');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE user_role_enum AS ENUM ('ADMIN', 'CASHIER', 'KITCHEN');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ==============================================================================
-- 3. PROFILES / USERS (RBAC)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role user_role_enum NOT NULL DEFAULT 'CASHIER',
    phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 4. SHOPS TABLE (Dynamic: 5, 6, 10+ shops supported without redesign)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE, -- e.g. 'SHOP-1', 'SHOP-2'
    description TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    display_order INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 5. PRODUCTS TABLE (Belongs to exactly one shop; stores CURRENT active price)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'General',
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    sku TEXT,
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 6. DINING TABLES (Dynamic: 10 tables initially, scalable to 20, 30+)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.dining_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number INT NOT NULL UNIQUE,
    table_name TEXT NOT NULL, -- e.g. 'Table 1'
    capacity INT NOT NULL DEFAULT 4 CHECK (capacity > 0),
    status table_status_enum NOT NULL DEFAULT 'AVAILABLE',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 7. TABLE SESSIONS (Represents customer seating context: 1 table or merged tables)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.table_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_number TEXT NOT NULL UNIQUE,
    status session_status_enum NOT NULL DEFAULT 'OPEN',
    guest_count INT DEFAULT 1,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    closed_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 8. TABLE SESSION TABLES (Junction table linking 1 or MULTIPLE tables to a session)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.table_session_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.table_sessions(id) ON DELETE CASCADE,
    table_id UUID NOT NULL REFERENCES public.dining_tables(id) ON DELETE RESTRICT,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    left_at TIMESTAMPTZ,
    CONSTRAINT unique_active_session_table UNIQUE (session_id, table_id)
);

-- ==============================================================================
-- 9. TABLE MERGE & TRANSFER AUDIT HISTORY
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.table_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action_type TEXT NOT NULL CHECK (action_type IN ('MERGE', 'UNMERGE', 'TRANSFER', 'RELEASE')),
    session_id UUID REFERENCES public.table_sessions(id) ON DELETE SET NULL,
    primary_table_id UUID REFERENCES public.dining_tables(id) ON DELETE SET NULL,
    secondary_table_id UUID REFERENCES public.dining_tables(id) ON DELETE SET NULL,
    details JSONB DEFAULT '{}'::jsonb,
    performed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 10. ORDERS TABLE (Unified Order Model for DINE_IN, TAKE_AWAY, DELIVERY)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT NOT NULL UNIQUE,
    order_type order_type_enum NOT NULL,
    status order_status_enum NOT NULL DEFAULT 'OPEN',
    table_session_id UUID REFERENCES public.table_sessions(id) ON DELETE SET NULL,
    
    -- Customer & Delivery Details (required if DELIVERY, optional for TAKEAWAY)
    customer_name TEXT,
    customer_phone TEXT,
    delivery_address TEXT,
    delivery_notes TEXT,
    
    -- Aggregated Financials
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    tax NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax >= 0),
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (total_amount >= 0),
    
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ
);

-- ==============================================================================
-- 11. ORDER ITEMS (Multi-Shop Order Items: retains shop_id & historical sale price)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL, -- Preserves product name at sale time
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0), -- Historical price
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    notes TEXT, -- Item specific instructions, e.g. "Less spicy"
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 12. BILLS TABLE (1 Customer = 1 Bill, Atomic & Idempotent)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_number TEXT NOT NULL UNIQUE,
    order_id UUID NOT NULL UNIQUE REFERENCES public.orders(id) ON DELETE RESTRICT,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0),
    discount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount >= 0),
    tax NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    payment_method payment_method_enum NOT NULL,
    payment_status TEXT NOT NULL DEFAULT 'PAID' CHECK (payment_status IN ('PAID', 'REFUNDED')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 13. BILL ITEMS (Shop-Wise Financial Breakdown, Guaranteed Immutable Record)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.bill_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id UUID NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
    shop_id UUID NOT NULL REFERENCES public.shops(id) ON DELETE RESTRICT,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 14. PERFORMANCE INDEXES (Optimized for Real-Time POS & Fast Reports)
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_bill_items_shop_id ON public.bill_items(shop_id);
CREATE INDEX IF NOT EXISTS idx_bill_items_created_at ON public.bill_items(created_at);
CREATE INDEX IF NOT EXISTS idx_bill_items_shop_created ON public.bill_items(shop_id, created_at);

CREATE INDEX IF NOT EXISTS idx_bills_created_at ON public.bills(created_at);
CREATE INDEX IF NOT EXISTS idx_bills_payment_method ON public.bills(payment_method);
CREATE INDEX IF NOT EXISTS idx_bills_order_id ON public.bills(order_id);

CREATE INDEX IF NOT EXISTS idx_orders_order_type ON public.orders(order_type);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_table_session_id ON public.orders(table_session_id);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_shop_id ON public.order_items(shop_id);

CREATE INDEX IF NOT EXISTS idx_dining_tables_status ON public.dining_tables(status);
CREATE INDEX IF NOT EXISTS idx_dining_tables_number ON public.dining_tables(table_number);

CREATE INDEX IF NOT EXISTS idx_table_session_tables_session ON public.table_session_tables(session_id);
CREATE INDEX IF NOT EXISTS idx_table_session_tables_table ON public.table_session_tables(table_id);
CREATE INDEX IF NOT EXISTS idx_table_sessions_status ON public.table_sessions(status);

-- ==============================================================================
-- 15. SEQUENCES & AUTO-NUMBER GENERATORS
-- ==============================================================================
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.bill_number_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.session_number_seq START 1;

-- Function: Generate Order Number (ORD-YYYYMMDD-XXXX)
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TEXT AS $$
DECLARE
    seq_val INT;
    date_part TEXT;
BEGIN
    SELECT nextval('public.order_number_seq') INTO seq_val;
    SELECT to_char(timezone('utc'::text, now()), 'YYYYMMDD') INTO date_part;
    RETURN 'ORD-' || date_part || '-' || lpad(seq_val::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Function: Generate Bill Number ('001', '002', '003'... per business day)
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

-- Function: Generate Session Number (SESS-YYYYMMDD-XXXX)
CREATE OR REPLACE FUNCTION public.generate_session_number()
RETURNS TEXT AS $$
DECLARE
    seq_val INT;
    date_part TEXT;
BEGIN
    SELECT nextval('public.session_number_seq') INTO seq_val;
    SELECT to_char(timezone('utc'::text, now()), 'YYYYMMDD') INTO date_part;
    RETURN 'SESS-' || date_part || '-' || lpad(seq_val::text, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 16. ATOMIC TRANSACTION STORED PROCEDURES (BUSINESS LOGIC)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Procedure 1: Open Dine-In Session and Order
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_dine_in_session(
    p_table_id UUID,
    p_guest_count INT DEFAULT 1,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_table_record RECORD;
    v_session_id UUID;
    v_session_number TEXT;
    v_order_id UUID;
    v_order_number TEXT;
BEGIN
    -- Check table availability
    SELECT * INTO v_table_record FROM public.dining_tables WHERE id = p_table_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Table not found.';
    END IF;

    IF v_table_record.status <> 'AVAILABLE' THEN
        RAISE EXCEPTION 'Table % is not available (Current status: %).', v_table_record.table_name, v_table_record.status;
    END IF;

    -- Generate numbers
    v_session_number := public.generate_session_number();
    v_order_number := public.generate_order_number();

    -- Create Table Session
    INSERT INTO public.table_sessions (session_number, status, guest_count, created_by)
    VALUES (v_session_number, 'OPEN', p_guest_count, p_created_by)
    RETURNING id INTO v_session_id;

    -- Link Table to Session
    INSERT INTO public.table_session_tables (session_id, table_id, joined_at)
    VALUES (v_session_id, p_table_id, now());

    -- Mark Table OCCUPIED
    UPDATE public.dining_tables
    SET status = 'OCCUPIED', updated_at = now()
    WHERE id = p_table_id;

    -- Create Dine-In Order
    INSERT INTO public.orders (
        order_number,
        order_type,
        status,
        table_session_id,
        created_by
    )
    VALUES (
        v_order_number,
        'DINE_IN',
        'OPEN',
        v_session_id,
        p_created_by
    )
    RETURNING id INTO v_order_id;

    RETURN jsonb_build_object(
        'session_id', v_session_id,
        'session_number', v_session_number,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'table_id', p_table_id,
        'table_name', v_table_record.table_name
    );
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Procedure 2: Merge Tables Atomically
-- Merges secondary_table_id into primary_table_id's session
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_tables(
    p_primary_table_id UUID,
    p_table_ids_to_merge UUID[],
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_primary_session_id UUID;
    v_secondary_session_id UUID;
    v_sec_table_id UUID;
    v_primary_order_id UUID;
    v_sec_order_id UUID;
    v_primary_table RECORD;
    v_session_number TEXT;
    v_order_number TEXT;
BEGIN
    -- 1. Lock and validate primary table
    SELECT * INTO v_primary_table FROM public.dining_tables WHERE id = p_primary_table_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Primary table not found.';
    END IF;

    -- 2. Check if primary table already has an active open session
    SELECT tst.session_id INTO v_primary_session_id
    FROM public.table_session_tables tst
    JOIN public.table_sessions ts ON ts.id = tst.session_id
    WHERE tst.table_id = p_primary_table_id 
      AND ts.status = 'OPEN' 
      AND tst.left_at IS NULL
    LIMIT 1;

    -- 3. If primary table does not have an active session, check if any of the tables to merge has one
    IF v_primary_session_id IS NULL THEN
        SELECT tst.session_id INTO v_primary_session_id
        FROM public.table_session_tables tst
        JOIN public.table_sessions ts ON ts.id = tst.session_id
        WHERE tst.table_id = ANY(p_table_ids_to_merge)
          AND ts.status = 'OPEN' 
          AND tst.left_at IS NULL
        LIMIT 1;

        -- If found an existing session among secondary tables, attach primary table to it
        IF v_primary_session_id IS NOT NULL THEN
            INSERT INTO public.table_session_tables (session_id, table_id, joined_at)
            VALUES (v_primary_session_id, p_primary_table_id, now())
            ON CONFLICT (session_id, table_id) DO UPDATE SET left_at = NULL;
        ELSE
            -- Neither primary nor secondary tables have an active session!
            -- Automatically CREATE a new combined Dine-In session and order:
            v_session_number := public.generate_session_number();
            v_order_number := public.generate_order_number();

            INSERT INTO public.table_sessions (session_number, status, guest_count, created_by)
            VALUES (v_session_number, 'OPEN', v_primary_table.capacity, p_user_id)
            RETURNING id INTO v_primary_session_id;

            INSERT INTO public.table_session_tables (session_id, table_id, joined_at)
            VALUES (v_primary_session_id, p_primary_table_id, now());

            INSERT INTO public.orders (order_number, order_type, status, table_session_id, created_by)
            VALUES (v_order_number, 'DINE_IN', 'OPEN', v_primary_session_id, p_user_id)
            RETURNING id INTO v_primary_order_id;
        END IF;
    END IF;

    -- Mark primary table as OCCUPIED
    UPDATE public.dining_tables
    SET status = 'OCCUPIED', updated_at = now()
    WHERE id = p_primary_table_id;

    -- Ensure we have the primary open order ID
    IF v_primary_order_id IS NULL THEN
        SELECT id INTO v_primary_order_id
        FROM public.orders
        WHERE table_session_id = v_primary_session_id AND status = 'OPEN'
        LIMIT 1;

        IF v_primary_order_id IS NULL THEN
            v_order_number := public.generate_order_number();
            INSERT INTO public.orders (order_number, order_type, status, table_session_id, created_by)
            VALUES (v_order_number, 'DINE_IN', 'OPEN', v_primary_session_id, p_user_id)
            RETURNING id INTO v_primary_order_id;
        END IF;
    END IF;

    -- 4. Merge all selected secondary tables into primary session
    FOREACH v_sec_table_id IN ARRAY p_table_ids_to_merge LOOP
        IF v_sec_table_id = p_primary_table_id THEN
            CONTINUE;
        END IF;

        -- Find secondary table active session if any
        SELECT tst.session_id INTO v_secondary_session_id
        FROM public.table_session_tables tst
        JOIN public.table_sessions ts ON ts.id = tst.session_id
        WHERE tst.table_id = v_sec_table_id 
          AND ts.status = 'OPEN' 
          AND tst.left_at IS NULL
        LIMIT 1;

        -- If secondary table had an active session with an open order, migrate items
        IF v_secondary_session_id IS NOT NULL AND v_secondary_session_id <> v_primary_session_id THEN
            SELECT id INTO v_sec_order_id
            FROM public.orders
            WHERE table_session_id = v_secondary_session_id AND status = 'OPEN'
            LIMIT 1;

            IF v_sec_order_id IS NOT NULL AND v_primary_order_id IS NOT NULL THEN
                -- Move items to primary order
                UPDATE public.order_items
                SET order_id = v_primary_order_id
                WHERE order_id = v_sec_order_id;

                -- Cancel secondary empty order
                UPDATE public.orders
                SET status = 'CANCELLED', updated_at = now()
                WHERE id = v_sec_order_id;
            END IF;

            -- Close secondary session
            UPDATE public.table_sessions
            SET status = 'MERGED', closed_at = now(), updated_at = now()
            WHERE id = v_secondary_session_id;

            UPDATE public.table_session_tables
            SET left_at = now()
            WHERE session_id = v_secondary_session_id;
        END IF;

        -- Attach table to primary session
        INSERT INTO public.table_session_tables (session_id, table_id, joined_at)
        VALUES (v_primary_session_id, v_sec_table_id, now())
        ON CONFLICT (session_id, table_id) DO UPDATE SET left_at = NULL;

        -- Mark table as MERGED
        UPDATE public.dining_tables
        SET status = 'MERGED', updated_at = now()
        WHERE id = v_sec_table_id;

        -- Log merge activity
        INSERT INTO public.table_activity_logs (
            action_type,
            session_id,
            primary_table_id,
            secondary_table_id,
            performed_by,
            details
        ) VALUES (
            'MERGE',
            v_primary_session_id,
            p_primary_table_id,
            v_sec_table_id,
            p_user_id,
            jsonb_build_object('merged_into_session', v_primary_session_id)
        );
    END LOOP;

    -- 5. Recalculate primary order totals if items were migrated
    IF v_primary_order_id IS NOT NULL THEN
        UPDATE public.orders o
        SET 
            subtotal = COALESCE((SELECT SUM(subtotal) FROM public.order_items WHERE order_id = v_primary_order_id), 0),
            total_amount = COALESCE((SELECT SUM(subtotal) FROM public.order_items WHERE order_id = v_primary_order_id), 0) - o.discount + o.tax,
            updated_at = now()
        WHERE o.id = v_primary_order_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_primary_session_id,
        'order_id', v_primary_order_id
    );
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Function: Unmerge a Table
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unmerge_table(
    p_table_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_session_id UUID;
    v_remaining_count INT;
    v_primary_table_id UUID;
BEGIN
    SELECT session_id INTO v_session_id
    FROM public.table_session_tables
    WHERE table_id = p_table_id AND left_at IS NULL
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Table is not currently part of an active session.';
    END IF;

    UPDATE public.table_session_tables
    SET left_at = now()
    WHERE session_id = v_session_id AND table_id = p_table_id;

    UPDATE public.dining_tables
    SET status = 'AVAILABLE', updated_at = now()
    WHERE id = p_table_id;

    SELECT COUNT(*) INTO v_remaining_count
    FROM public.table_session_tables
    WHERE session_id = v_session_id AND left_at IS NULL;

    IF v_remaining_count = 1 THEN
        SELECT table_id INTO v_primary_table_id
        FROM public.table_session_tables
        WHERE session_id = v_session_id AND left_at IS NULL
        LIMIT 1;

        UPDATE public.dining_tables
        SET status = 'OCCUPIED', updated_at = now()
        WHERE id = v_primary_table_id;
    END IF;

    INSERT INTO public.table_activity_logs (
        action_type, session_id, primary_table_id, performed_by, details
    ) VALUES (
        'UNMERGE', v_session_id, p_table_id, p_user_id,
        jsonb_build_object('unmerged_table_id', p_table_id)
    );

    RETURN jsonb_build_object('success', true, 'unmerged_table_id', p_table_id);
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Procedure 3: Table Transfer / Move Order
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.transfer_table(
    p_from_table_id UUID,
    p_to_table_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_session_id UUID;
    v_to_table RECORD;
BEGIN
    -- Check target table availability
    SELECT * INTO v_to_table FROM public.dining_tables WHERE id = p_to_table_id FOR UPDATE;
    IF NOT FOUND OR v_to_table.status <> 'AVAILABLE' THEN
        RAISE EXCEPTION 'Target table is not available.';
    END IF;

    -- Find active session for from_table
    SELECT tst.session_id INTO v_session_id
    FROM public.table_session_tables tst
    JOIN public.table_sessions ts ON ts.id = tst.session_id
    WHERE tst.table_id = p_from_table_id 
      AND ts.status = 'OPEN' 
      AND tst.left_at IS NULL
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Origin table does not have an active session.';
    END IF;

    -- Release from_table
    UPDATE public.table_session_tables
    SET left_at = now()
    WHERE session_id = v_session_id AND table_id = p_from_table_id;

    UPDATE public.dining_tables
    SET status = 'AVAILABLE', updated_at = now()
    WHERE id = p_from_table_id;

    -- Attach to_table
    INSERT INTO public.table_session_tables (session_id, table_id, joined_at)
    VALUES (v_session_id, p_to_table_id, now());

    UPDATE public.dining_tables
    SET status = 'OCCUPIED', updated_at = now()
    WHERE id = p_to_table_id;

    -- Log Transfer
    INSERT INTO public.table_activity_logs (
        action_type, session_id, primary_table_id, secondary_table_id, performed_by, details
    ) VALUES (
        'TRANSFER', v_session_id, p_from_table_id, p_to_table_id, p_user_id,
        jsonb_build_object('from_table_id', p_from_table_id, 'to_table_id', p_to_table_id)
    );

    RETURN jsonb_build_object('success', true, 'session_id', v_session_id);
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Procedure 4: Atomic Complete Bill & Payment
--  * Creates Bill and copies items with shop_id to bill_items
--  * Closes Order & Table Session
--  * Releases all related tables back to 'AVAILABLE'
--  * Idempotent: checks for double-billing
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_bill_transaction(
    p_order_id UUID,
    p_payment_method payment_method_enum,
    p_discount NUMERIC(10, 2) DEFAULT 0.00,
    p_tax NUMERIC(10, 2) DEFAULT 0.00,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_order RECORD;
    v_bill_id UUID;
    v_bill_number TEXT;
    v_subtotal NUMERIC(10, 2);
    v_total NUMERIC(10, 2);
    v_item RECORD;
    v_session_id UUID;
    v_table_record RECORD;
BEGIN
    -- 1. Lock and validate order
    SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    IF v_order.status = 'COMPLETED' THEN
        RAISE EXCEPTION 'Order % is already completed and billed.', v_order.order_number;
    END IF;

    -- Check if bill already exists (Double-click / Idempotency protection)
    IF EXISTS (SELECT 1 FROM public.bills WHERE order_id = p_order_id) THEN
        RAISE EXCEPTION 'Bill has already been generated for this order.';
    END IF;

    -- 2. Validate Order Items
    SELECT COALESCE(SUM(subtotal), 0) INTO v_subtotal
    FROM public.order_items
    WHERE order_id = p_order_id;

    IF v_subtotal <= 0 THEN
        RAISE EXCEPTION 'Cannot bill an order with zero or no items.';
    END IF;

    v_total := GREATEST(0, (v_subtotal - COALESCE(p_discount, 0)) + COALESCE(p_tax, 0));

    -- 3. Generate Bill Number
    v_bill_number := public.generate_bill_number();

    -- 4. Create Bill
    INSERT INTO public.bills (
        bill_number,
        order_id,
        subtotal,
        discount,
        tax,
        total_amount,
        payment_method,
        payment_status,
        created_by
    )
    VALUES (
        v_bill_number,
        p_order_id,
        v_subtotal,
        COALESCE(p_discount, 0),
        COALESCE(p_tax, 0),
        v_total,
        p_payment_method,
        'PAID',
        p_user_id
    )
    RETURNING id INTO v_bill_id;

    -- 5. Copy Order Items to Bill Items (Preserving shop_id and price snapshot)
    FOR v_item IN (SELECT * FROM public.order_items WHERE order_id = p_order_id) LOOP
        INSERT INTO public.bill_items (
            bill_id,
            shop_id,
            product_id,
            product_name,
            quantity,
            unit_price,
            subtotal
        )
        VALUES (
            v_bill_id,
            v_item.shop_id,
            v_item.product_id,
            v_item.product_name,
            v_item.quantity,
            v_item.unit_price,
            v_item.subtotal
        );
    END LOOP;

    -- 6. Update Order Status
    UPDATE public.orders
    SET 
        status = 'COMPLETED',
        subtotal = v_subtotal,
        discount = COALESCE(p_discount, 0),
        tax = COALESCE(p_tax, 0),
        total_amount = v_total,
        completed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_order_id;

    -- 7. If Dine-In: Close Table Session & Release ALL Tables (both primary & merged)
    IF v_order.table_session_id IS NOT NULL THEN
        v_session_id := v_order.table_session_id;

        -- Close Session
        UPDATE public.table_sessions
        SET 
            status = 'CLOSED',
            closed_at = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = v_session_id;

        -- Mark end time on session tables
        UPDATE public.table_session_tables
        SET left_at = timezone('utc'::text, now())
        WHERE session_id = v_session_id AND left_at IS NULL;

        -- Release every table that was part of this session
        FOR v_table_record IN (
            SELECT table_id FROM public.table_session_tables WHERE session_id = v_session_id
        ) LOOP
            UPDATE public.dining_tables
            SET 
                status = 'AVAILABLE',
                updated_at = timezone('utc'::text, now())
            WHERE id = v_table_record.table_id;
        END LOOP;
    END IF;

    -- Return JSON result for UI
    RETURN jsonb_build_object(
        'success', true,
        'bill_id', v_bill_id,
        'bill_number', v_bill_number,
        'order_id', p_order_id,
        'total_amount', v_total,
        'payment_method', p_payment_method
    );
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 17. REPORTING & ANALYTICS VIEWS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- View 1: Complete Bill Summary with Shops Breakdown
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.view_bill_details AS
SELECT 
    b.id AS bill_id,
    b.bill_number,
    b.created_at AS bill_time,
    b.payment_method,
    b.total_amount,
    b.discount,
    b.tax,
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

-- ------------------------------------------------------------------------------
-- Function: Shop-Wise Sales for any Date Range
-- Accurately calculates from bill_items.shop_id without dividing bills
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_shop_sales_report(
    p_start_date TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
    shop_id UUID,
    shop_name TEXT,
    shop_code TEXT,
    items_sold BIGINT,
    total_sales NUMERIC(12, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id AS shop_id,
        s.name AS shop_name,
        s.code AS shop_code,
        COALESCE(SUM(bi.quantity), 0)::BIGINT AS items_sold,
        COALESCE(SUM(bi.subtotal), 0.00)::NUMERIC(12, 2) AS total_sales
    FROM public.shops s
    LEFT JOIN public.bill_items bi ON bi.shop_id = s.id 
      AND bi.created_at >= p_start_date 
      AND bi.created_at <= p_end_date
    GROUP BY s.id, s.name, s.code
    ORDER BY s.display_order ASC;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Function: Order-Type-Wise Sales Breakdown
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_order_type_sales_report(
    p_start_date TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
    order_type order_type_enum,
    bill_count BIGINT,
    total_sales NUMERIC(12, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.order_type,
        COUNT(b.id)::BIGINT AS bill_count,
        COALESCE(SUM(b.total_amount), 0.00)::NUMERIC(12, 2) AS total_sales
    FROM public.orders o
    JOIN public.bills b ON b.order_id = o.id
    WHERE b.created_at >= p_start_date AND b.created_at <= p_end_date
    GROUP BY o.order_type;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Function: Combined Shop + Order-Type Matrix Report
-- (Section 51 of specification: Shop 1..5 vs Dine-In, Takeaway, Delivery)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_shop_order_type_matrix(
    p_start_date TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
    shop_id UUID,
    shop_name TEXT,
    dine_in_sales NUMERIC(12, 2),
    take_away_sales NUMERIC(12, 2),
    delivery_sales NUMERIC(12, 2),
    total_sales NUMERIC(12, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id AS shop_id,
        s.name AS shop_name,
        COALESCE(SUM(CASE WHEN o.order_type = 'DINE_IN' THEN bi.subtotal ELSE 0 END), 0.00)::NUMERIC(12, 2) AS dine_in_sales,
        COALESCE(SUM(CASE WHEN o.order_type = 'TAKE_AWAY' THEN bi.subtotal ELSE 0 END), 0.00)::NUMERIC(12, 2) AS take_away_sales,
        COALESCE(SUM(CASE WHEN o.order_type = 'DELIVERY' THEN bi.subtotal ELSE 0 END), 0.00)::NUMERIC(12, 2) AS delivery_sales,
        COALESCE(SUM(bi.subtotal), 0.00)::NUMERIC(12, 2) AS total_sales
    FROM public.shops s
    LEFT JOIN public.bill_items bi ON bi.shop_id = s.id 
      AND bi.created_at >= p_start_date 
      AND bi.created_at <= p_end_date
    LEFT JOIN public.bills b ON b.id = bi.bill_id
    LEFT JOIN public.orders o ON o.id = b.order_id
    GROUP BY s.id, s.name, s.display_order
    ORDER BY s.display_order ASC;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 18. SUPABASE ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dining_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_session_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.table_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view all active staff profiles, update their own
CREATE POLICY "Allow authenticated read profiles" ON public.profiles
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow user update own profile" ON public.profiles
    FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Shops & Products: Authenticated staff can view; Admins can modify
CREATE POLICY "Allow authenticated read shops" ON public.shops
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow admin modify shops" ON public.shops
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN')
    );

CREATE POLICY "Allow authenticated read products" ON public.products
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow admin modify products" ON public.products
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN')
    );

-- Dining Tables: All staff can read & update status
CREATE POLICY "Allow authenticated read tables" ON public.dining_tables
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated update tables" ON public.dining_tables
    FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow admin manage tables" ON public.dining_tables
    FOR ALL TO authenticated USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'ADMIN')
    );

-- Table Sessions & Junction: Staff can read and write
CREATE POLICY "Allow authenticated read table_sessions" ON public.table_sessions
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated write table_sessions" ON public.table_sessions
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow authenticated read table_session_tables" ON public.table_session_tables
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated write table_session_tables" ON public.table_session_tables
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow authenticated read table_activity_logs" ON public.table_activity_logs
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert table_activity_logs" ON public.table_activity_logs
    FOR INSERT TO authenticated WITH CHECK (true);

-- Orders & Order Items: Staff can read, create, update
CREATE POLICY "Allow authenticated read orders" ON public.orders
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated write orders" ON public.orders
    FOR ALL TO authenticated USING (true);

CREATE POLICY "Allow authenticated read order_items" ON public.order_items
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated write order_items" ON public.order_items
    FOR ALL TO authenticated USING (true);

-- Bills & Bill Items: Staff can read and insert bills
CREATE POLICY "Allow authenticated read bills" ON public.bills
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert bills" ON public.bills
    FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated read bill_items" ON public.bill_items
    FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow authenticated insert bill_items" ON public.bill_items
    FOR INSERT TO authenticated WITH CHECK (true);

-- ==============================================================================
-- 19. REALTIME ENABLEMENT (For live table status & kitchen sync)
-- ==============================================================================
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.dining_tables;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.table_sessions;
EXCEPTION
    WHEN others THEN null;
END $$;
