-- ==============================================================================
-- FIX TABLE MERGING & UNMERGING STORED PROCEDURES
-- Run this in Supabase SQL Editor to support merging:
--   1) Available + Available tables (creates a new combined session automatically)
--   2) Occupied + Available tables
--   3) Occupied + Occupied tables (combines items into primary order)
-- ==============================================================================

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
            -- If session exists but no open order, create one
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
-- Function: Unmerge a Table from a Session
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
    -- Find active session for this table
    SELECT session_id INTO v_session_id
    FROM public.table_session_tables
    WHERE table_id = p_table_id AND left_at IS NULL
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Table is not currently part of an active session.';
    END IF;

    -- Mark this table as left from session
    UPDATE public.table_session_tables
    SET left_at = now()
    WHERE session_id = v_session_id AND table_id = p_table_id;

    -- Mark table as AVAILABLE
    UPDATE public.dining_tables
    SET status = 'AVAILABLE', updated_at = now()
    WHERE id = p_table_id;

    -- Check how many tables remain active in this session
    SELECT COUNT(*) INTO v_remaining_count
    FROM public.table_session_tables
    WHERE session_id = v_session_id AND left_at IS NULL;

    -- If only 1 table remains, make sure it is marked OCCUPIED (not MERGED)
    IF v_remaining_count = 1 THEN
        SELECT table_id INTO v_primary_table_id
        FROM public.table_session_tables
        WHERE session_id = v_session_id AND left_at IS NULL
        LIMIT 1;

        UPDATE public.dining_tables
        SET status = 'OCCUPIED', updated_at = now()
        WHERE id = v_primary_table_id;
    END IF;

    -- Log activity
    INSERT INTO public.table_activity_logs (
        action_type, session_id, primary_table_id, performed_by, details
    ) VALUES (
        'UNMERGE', v_session_id, p_table_id, p_user_id,
        jsonb_build_object('unmerged_table_id', p_table_id)
    );

    RETURN jsonb_build_object('success', true, 'unmerged_table_id', p_table_id);
END;
$$ LANGUAGE plpgsql;

-- Grant execution to public / anon
GRANT EXECUTE ON FUNCTION public.merge_tables(UUID, UUID[], UUID) TO public;
GRANT EXECUTE ON FUNCTION public.unmerge_table(UUID, UUID) TO public;
