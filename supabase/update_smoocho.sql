-- ==============================================================================
-- UPDATE SHOP NAME FROM 'Smoochos' TO 'Smoocho'
-- Run this in Supabase Dashboard -> SQL Editor
-- ==============================================================================

-- 1. Update the official shop record in the shops table
UPDATE public.shops
SET name = 'Smoocho',
    code = 'SMOOCHO',
    updated_at = NOW()
WHERE id = '11111111-1111-1111-1111-111111111104' 
   OR LOWER(name) LIKE 'smoocho%';

-- 2. Update any products category references
UPDATE public.products
SET category = 'Smoocho Signature'
WHERE category ILIKE 'smoochos%';

-- Note: 'bill_items' and 'order_items' link to shops via 'shop_id' foreign key,
-- so updating public.shops above automatically updates all bill and order history!

