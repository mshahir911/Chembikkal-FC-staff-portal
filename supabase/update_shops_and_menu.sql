-- ==============================================================================
-- CHEMBIIKKAL FOOD COURT: UPDATE SHOPS AND EXACT MENU ITEMS
-- Run this script in the Supabase Dashboard SQL Editor (https://supabase.com/dashboard/project/oyuoqqqsfjfslgbchdfp/sql)
-- ==============================================================================

BEGIN;

-- 1. Ensure Table Structure & Constraints
ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_code_key CASCADE;
ALTER TABLE public.shops ADD CONSTRAINT shops_code_key UNIQUE (code);

-- 2. Upsert the 4 Real Shops
INSERT INTO public.shops (id, name, code, description, status, display_order)
VALUES 
    (
        '11111111-1111-1111-1111-111111111101',
        'Thejaj',
        'THEJAJ',
        'Authentic Shawarma & Shawaya Specialists',
        'ACTIVE',
        1
    ),
    (
        '11111111-1111-1111-1111-111111111102',
        'Fruvia',
        'FRUVIA',
        'Fresh Juices, Coolers & Thick Shakes',
        'ACTIVE',
        2
    ),
    (
        '11111111-1111-1111-1111-111111111103',
        'Chai Latte',
        'CHAI-LATTE',
        'Freshly Brewed Tea, Coffee & Hot Evening Snacks',
        'ACTIVE',
        3
    ),
    (
        '11111111-1111-1111-1111-111111111104',
        'Smoochos',
        'SMOOCHOS',
        'Kunafa Bowls, Flavour Storm Cakes, Signature Desserts & Milk Specials',
        'ACTIVE',
        4
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    code = EXCLUDED.code,
    description = EXCLUDED.description,
    status = EXCLUDED.status,
    display_order = EXCLUDED.display_order;

-- Deactivate Old Fake Shop 5 (Bakery & Desserts)
UPDATE public.shops 
SET status = 'INACTIVE', display_order = 99 
WHERE id = '11111111-1111-1111-1111-111111111105';

-- Safely remove old fake products from all shops
-- (Foreign keys in order_items / bill_items have ON DELETE SET NULL, protecting historical sales data)
DELETE FROM public.products 
WHERE shop_id IN (
    '11111111-1111-1111-1111-111111111101',
    '11111111-1111-1111-1111-111111111102',
    '11111111-1111-1111-1111-111111111103',
    '11111111-1111-1111-1111-111111111104',
    '11111111-1111-1111-1111-111111111105'
);

-- ==============================================================================
-- 3. INSERT PRODUCTS FOR SHOP 1: THEJAJ
-- ==============================================================================
INSERT INTO public.products (shop_id, name, description, category, price, sku, is_active)
VALUES
    -- Shawarma
    ('11111111-1111-1111-1111-111111111101', 'Normal Roll Shawarma', 'Classic rolled shawarma with fresh veggies & garlic sauce', 'Shawarma', 100.00, 'SKU-THJ-001', true),
    ('11111111-1111-1111-1111-111111111101', 'Normal Plate Shawarma', 'Classic plate shawarma served with bread & dips', 'Shawarma', 130.00, 'SKU-THJ-002', true),
    ('11111111-1111-1111-1111-111111111101', 'Full Meat Roll Shawarma', 'Loaded roll with 100% chicken meat and secret sauce', 'Shawarma', 120.00, 'SKU-THJ-003', true),
    ('11111111-1111-1111-1111-111111111101', 'Full Meat Plate Shawarma', 'Generous plate of pure spiced shredded chicken meat', 'Shawarma', 150.00, 'SKU-THJ-004', true),
    ('11111111-1111-1111-1111-111111111101', 'Rumali Roll Shawarma', 'Tender shawarma wrapped in soft thin rumali roti', 'Shawarma', 130.00, 'SKU-THJ-005', true),
    ('11111111-1111-1111-1111-111111111101', 'Rumali Plate Shawarma', 'Plate shawarma served with hot rumali rotis', 'Shawarma', 150.00, 'SKU-THJ-006', true),

    -- Shawaya
    ('11111111-1111-1111-1111-111111111101', 'Shawaya (Full)', 'Full slow-roasted marinated charcoal grilled chicken', 'Shawaya', 550.00, 'SKU-THJ-007', true),
    ('11111111-1111-1111-1111-111111111101', 'Shawaya (Half)', 'Half charcoal slow-roasted spiced chicken', 'Shawaya', 300.00, 'SKU-THJ-008', true),
    ('11111111-1111-1111-1111-111111111101', 'Shawaya (Quarter)', 'Quarter succulent slow-roasted spiced chicken', 'Shawaya', 150.00, 'SKU-THJ-009', true);


-- ==============================================================================
-- 4. INSERT PRODUCTS FOR SHOP 2: FRUVIA
-- ==============================================================================
INSERT INTO public.products (shop_id, name, description, category, price, sku, is_active)
VALUES
    -- Juice
    ('11111111-1111-1111-1111-111111111102', 'Pineapple Juice', 'Freshly pressed sweet tropical pineapple', 'Juice', 80.00, 'SKU-FRU-001', true),
    ('11111111-1111-1111-1111-111111111102', 'Watermelon Juice', 'Crisp chilled pure fresh watermelon juice', 'Juice', 80.00, 'SKU-FRU-002', true),
    ('11111111-1111-1111-1111-111111111102', 'Grape Juice', 'Sweet and chilled fresh black grape crush', 'Juice', 80.00, 'SKU-FRU-003', true),
    ('11111111-1111-1111-1111-111111111102', 'Tender Coconut Juice', 'Refreshing natural elaneer tender coconut cooler', 'Juice', 80.00, 'SKU-FRU-004', true),
    ('11111111-1111-1111-1111-111111111102', 'Musambi Juice', 'Zesty sweet lime freshly extracted juice', 'Juice', 80.00, 'SKU-FRU-005', true),
    ('11111111-1111-1111-1111-111111111102', 'Orange Juice', '100% freshly squeezed vitamin C rich orange', 'Juice', 80.00, 'SKU-FRU-006', true),
    ('11111111-1111-1111-1111-111111111102', 'Anar Juice (Pomegranate)', 'Pure fresh red pomegranate aril juice', 'Juice', 90.00, 'SKU-FRU-007', true),
    ('11111111-1111-1111-1111-111111111102', 'Apple Juice', 'Fresh crisp sweet apple extract', 'Juice', 80.00, 'SKU-FRU-008', true),
    ('11111111-1111-1111-1111-111111111102', 'Dragon Fruit Juice', 'Vibrant magenta exotic dragon fruit cooler', 'Juice', 90.00, 'SKU-FRU-009', true),
    ('11111111-1111-1111-1111-111111111102', 'Chikku Juice', 'Sweet sapota fruit natural juice', 'Juice', 80.00, 'SKU-FRU-010', true),
    ('11111111-1111-1111-1111-111111111102', 'Avocado Juice', 'Healthy fresh buttery avocado blend', 'Juice', 80.00, 'SKU-FRU-011', true),
    ('11111111-1111-1111-1111-111111111102', 'Mango Juice', 'Chilled luscious golden ripe mango juice', 'Juice', 80.00, 'SKU-FRU-012', true),

    -- Shakes
    ('11111111-1111-1111-1111-111111111102', 'Avocado Shake', 'Rich creamy avocado thick shake blended with milk', 'Shakes', 110.00, 'SKU-FRU-013', true),
    ('11111111-1111-1111-1111-111111111102', 'Dates Shake', 'Nutritious Arabian dates blended in thick cold milk', 'Shakes', 110.00, 'SKU-FRU-014', true),
    ('11111111-1111-1111-1111-111111111102', 'Tender Coconut Shake', 'Sweet elaneer pulp shake with velvety coconut cream', 'Shakes', 110.00, 'SKU-FRU-015', true),
    ('11111111-1111-1111-1111-111111111102', 'Dragon Fruit Shake', 'Creamy exotic dragon fruit pink thick shake', 'Shakes', 110.00, 'SKU-FRU-016', true),
    ('11111111-1111-1111-1111-111111111102', 'Snickers Shake', 'Loaded peanut chocolate caramel Snickers thick shake', 'Shakes', 110.00, 'SKU-FRU-017', true),
    ('11111111-1111-1111-1111-111111111102', 'Oreo Shake', 'Decadent cookies and cream Oreo milk shake', 'Shakes', 110.00, 'SKU-FRU-018', true),
    ('11111111-1111-1111-1111-111111111102', 'Chikku Shake', 'Velvety sapota thick shake', 'Shakes', 110.00, 'SKU-FRU-019', true),
    ('11111111-1111-1111-1111-111111111102', 'Mango Shake', 'Classic Alphonso mango thick shake with ice cream', 'Shakes', 110.00, 'SKU-FRU-020', true),
    ('11111111-1111-1111-1111-111111111102', 'Chocolate Shake', 'Rich Dutch cocoa thick chocolate shake', 'Shakes', 110.00, 'SKU-FRU-021', true);


-- ==============================================================================
-- 5. INSERT PRODUCTS FOR SHOP 3: CHAI LATTE
-- ==============================================================================
INSERT INTO public.products (shop_id, name, description, category, price, sku, is_active)
VALUES
    -- Hot Drinks / Chai
    ('11111111-1111-1111-1111-111111111103', 'Tea', 'Special freshly brewed piping hot milk tea', 'Hot Drinks', 15.00, 'SKU-CHL-001', true),
    ('11111111-1111-1111-1111-111111111103', 'Black Tea', 'Aromatic brisk black tea / sulaimani', 'Hot Drinks', 10.00, 'SKU-CHL-002', true),
    ('11111111-1111-1111-1111-111111111103', 'Ginger Tea', 'Cardamom & fresh crushed ginger infused spiced tea', 'Hot Drinks', 15.00, 'SKU-CHL-003', true),
    ('11111111-1111-1111-1111-111111111103', 'Coffee', 'Frothy traditional filter milk coffee', 'Hot Drinks', 20.00, 'SKU-CHL-004', true),
    ('11111111-1111-1111-1111-111111111103', 'Black Coffee', 'Rich bold brewed black coffee', 'Hot Drinks', 15.00, 'SKU-CHL-005', true),
    ('11111111-1111-1111-1111-111111111103', 'Horlicks', 'Warm comforting malt Horlicks milk drink', 'Hot Drinks', 25.00, 'SKU-CHL-006', true),
    ('11111111-1111-1111-1111-111111111103', 'Boost', 'Steaming energizing chocolate Boost drink', 'Hot Drinks', 25.00, 'SKU-CHL-007', true),

    -- Snacks
    ('11111111-1111-1111-1111-111111111103', 'Samoosa', 'Crispy golden fried spiced chicken/meat samosa', 'Snacks', 15.00, 'SKU-CHL-008', true),
    ('11111111-1111-1111-1111-111111111103', 'Parippu Vada', 'Crunchy Kerala style spiced lentil fritter', 'Snacks', 15.00, 'SKU-CHL-009', true),
    ('11111111-1111-1111-1111-111111111103', 'Pazhampori', 'Traditional crispy sweet ripe banana fritters', 'Snacks', 15.00, 'SKU-CHL-010', true),
    ('11111111-1111-1111-1111-111111111103', 'Mutta Bajji', 'Crispy batter-fried spiced egg bajji', 'Snacks', 15.00, 'SKU-CHL-011', true),
    ('11111111-1111-1111-1111-111111111103', 'Cutlet', 'Spicy mashed meat cutlet with crispy crumb crust', 'Snacks', 15.00, 'SKU-CHL-012', true),
    ('11111111-1111-1111-1111-111111111103', 'Ullivada', 'Crisp deep-fried golden onion pakora', 'Snacks', 15.00, 'SKU-CHL-013', true),
    ('11111111-1111-1111-1111-111111111103', 'Elanji', 'Traditional Malabar sweet rolled coconut stuffed pancake', 'Snacks', 25.00, 'SKU-CHL-014', true),
    ('11111111-1111-1111-1111-111111111103', 'Thurakkalappam', 'Authentic delicacy appam snack', 'Snacks', 25.00, 'SKU-CHL-015', true),
    ('11111111-1111-1111-1111-111111111103', 'Pazham Niravu', 'Whole ripe plantain stuffed with sweet coconut & dry fruits', 'Snacks', 30.00, 'SKU-CHL-016', true),
    ('11111111-1111-1111-1111-111111111103', 'Chicken Kabab', 'Juicy spiced fried chicken kabab snack', 'Snacks', 35.00, 'SKU-CHL-017', true),
    ('11111111-1111-1111-1111-111111111103', 'Chicken Wrap', 'Fresh toasted savory chicken snack wrap', 'Snacks', 35.00, 'SKU-CHL-018', true);


-- ==============================================================================
-- 6. INSERT PRODUCTS FOR SHOP 4: SMOOCHOS
-- ==============================================================================
INSERT INTO public.products (shop_id, name, description, category, price, sku, is_active)
VALUES
    -- Kunafa Bowls
    ('11111111-1111-1111-1111-111111111104', 'Pista White Kunafa', 'Crispy spun pastry soaked in syrup topped with white cream & pistachios', 'Kunafa Bowls', 259.00, 'SKU-SMO-001', true),
    ('11111111-1111-1111-1111-111111111104', 'Biscoff Kunafa', 'Golden kunafa bowl layered with rich Lotus Biscoff spread & crumbs', 'Kunafa Bowls', 279.00, 'SKU-SMO-002', true),
    ('11111111-1111-1111-1111-111111111104', 'Pista Biscoff Kunafa', 'Kunafa bowl fusion with pistachios and caramelized Lotus Biscoff', 'Kunafa Bowls', 279.00, 'SKU-SMO-003', true),
    ('11111111-1111-1111-1111-111111111104', 'Hazelnut Pista Kunafa', 'Crisp kunafa drizzled with hazelnut chocolate and roasted pista', 'Kunafa Bowls', 259.00, 'SKU-SMO-004', true),
    ('11111111-1111-1111-1111-111111111104', 'White Chocolate Kunafa', 'Silky white chocolate ganache over warm golden shredded kunafa', 'Kunafa Bowls', 249.00, 'SKU-SMO-005', true),
    ('11111111-1111-1111-1111-111111111104', 'Biscoff Hazelnut Kunafa', 'Crunchy kunafa layered with hazelnut spread and Lotus Biscoff', 'Kunafa Bowls', 259.00, 'SKU-SMO-006', true),
    ('11111111-1111-1111-1111-111111111104', 'Hazelnut White Kunafa', 'White chocolate and nutty hazelnut ganache on crispy kunafa', 'Kunafa Bowls', 259.00, 'SKU-SMO-007', true),
    ('11111111-1111-1111-1111-111111111104', 'Biscoff White Kunafa', 'Lotus Biscoff and smooth white chocolate kunafa bowl', 'Kunafa Bowls', 259.00, 'SKU-SMO-008', true),
    ('11111111-1111-1111-1111-111111111104', 'Pista Kunafa', 'Signature authentic crushed pistachio layered kunafa bowl', 'Kunafa Bowls', 279.00, 'SKU-SMO-009', true),
    ('11111111-1111-1111-1111-111111111104', 'Hazelnut Kunafa', 'Rich melted hazelnut praline over hot crispy kunafa', 'Kunafa Bowls', 249.00, 'SKU-SMO-010', true),

    -- Flavour Storm Series
    ('11111111-1111-1111-1111-111111111104', 'Mango Tsunami', 'Luscious mango cream explosion with diced sweet mango toppings', 'Flavour Storm', 229.00, 'SKU-SMO-011', true),
    ('11111111-1111-1111-1111-111111111104', 'Strawberry Tsunami', 'Bright ruby red strawberry explosion with fresh berry compote', 'Flavour Storm', 249.00, 'SKU-SMO-012', true),
    ('11111111-1111-1111-1111-111111111104', 'Hazelnut Mango Cyclone', 'Dual flavor storm: Nutty hazelnut chocolate meets golden ripe mango', 'Flavour Storm', 249.00, 'SKU-SMO-013', true),
    ('11111111-1111-1111-1111-111111111104', 'Biscoff Mango Hurricane', 'Caramelized Lotus Biscoff swirl combined with tropical mango', 'Flavour Storm', 249.00, 'SKU-SMO-014', true),
    ('11111111-1111-1111-1111-111111111104', 'Pista Hazelnut Earthquake', 'Rich crushed pistachios and decadently layered hazelnut swirl', 'Flavour Storm', 249.00, 'SKU-SMO-015', true),
    ('11111111-1111-1111-1111-111111111104', 'Pista Mango Thunderstorm', 'Vibrant pistachio crema combined with tropical fresh mango', 'Flavour Storm', 249.00, 'SKU-SMO-016', true),
    ('11111111-1111-1111-1111-111111111104', 'Pista Biscoff Tsunami', 'Supreme dessert storm pairing pistachio richness with Lotus Biscoff', 'Flavour Storm', 279.00, 'SKU-SMO-017', true),

    -- Salankatia (349/-)
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Biscoff', 'Signature creamy Salankatia dessert tub loaded with Lotus Biscoff', 'Salankatia', 349.00, 'SKU-SMO-018', true),
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Mango', 'Creamy Salankatia layered with chunks of fresh ripe mangoes', 'Salankatia', 349.00, 'SKU-SMO-019', true),
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Hazelnut', 'Rich decadent hazelnut chocolate poured over velvety Salankatia', 'Salankatia', 349.00, 'SKU-SMO-020', true),
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Pistachio', 'Silky pistachio puree over luscious layered cream dessert', 'Salankatia', 349.00, 'SKU-SMO-021', true),
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Pistachio Hazelnut', 'Split delight of pistachio and hazelnut over Salankatia cream', 'Salankatia', 349.00, 'SKU-SMO-022', true),
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Hazelnut Biscoff', 'Double delight with creamy hazelnut and crunchy Biscoff cookies', 'Salankatia', 349.00, 'SKU-SMO-023', true),
    ('11111111-1111-1111-1111-111111111104', 'Salankatia Pistachio Biscoff', 'Pistachio cream paired with crunchy Lotus Biscoff crumbs', 'Salankatia', 349.00, 'SKU-SMO-024', true),

    -- Hebah Cake (289/-)
    ('11111111-1111-1111-1111-111111111104', 'Hebah Cake Pistachio Kinder', 'Layered square cake with Kinder Bueno and velvety pistachio cream', 'Hebah Cake', 289.00, 'SKU-SMO-025', true),
    ('11111111-1111-1111-1111-111111111104', 'Hebah Cake Pistachio Hazelnut', 'Exquisite square cake topped with pistachio glaze and hazelnut drizzle', 'Hebah Cake', 289.00, 'SKU-SMO-026', true),
    ('11111111-1111-1111-1111-111111111104', 'Hebah Cake Pistachio Biscoff', 'Moist layered cake infused with pistachio spread and Lotus Biscoff', 'Hebah Cake', 289.00, 'SKU-SMO-027', true),

    -- Scoop the Sweetness (79/-)
    ('11111111-1111-1111-1111-111111111104', 'Choco Vanilla Scoop', 'Classic rich vanilla ice cream drizzled with premium chocolate', 'Ice Cream Scoops', 79.00, 'SKU-SMO-028', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Chocolate Scoop', 'Double dark chocolate scoop with warm chocolate sauce', 'Ice Cream Scoops', 79.00, 'SKU-SMO-029', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Strawberry Scoop', 'Refreshing strawberry scoop drizzled with choco syrup', 'Ice Cream Scoops', 79.00, 'SKU-SMO-030', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Mango Scoop', 'Tropical ripe mango ice cream scoop paired with chocolate drizzle', 'Ice Cream Scoops', 79.00, 'SKU-SMO-031', true),

    -- Aseera (150/-)
    ('11111111-1111-1111-1111-111111111104', 'Aseerathul Biscoff', 'Signature bottled cold beverage with rich Lotus Biscoff flavor', 'Aseera Bottles', 150.00, 'SKU-SMO-032', true),
    ('11111111-1111-1111-1111-111111111104', 'Aseerathul Hazelnut', 'Bottled gourmet milk dessert drink infused with roasted hazelnut', 'Aseera Bottles', 150.00, 'SKU-SMO-033', true),
    ('11111111-1111-1111-1111-111111111104', 'Aseerathul Pistachio', 'Bottled velvety pistachio milk drink', 'Aseera Bottles', 150.00, 'SKU-SMO-034', true),
    ('11111111-1111-1111-1111-111111111104', 'Aseerathul Kinder', 'Bottled creamy dessert drink with smooth Kinder chocolate', 'Aseera Bottles', 150.00, 'SKU-SMO-035', true),
    ('11111111-1111-1111-1111-111111111104', 'Aseerathul Coffee', 'Smooth iced aromatic coffee milk bottle', 'Aseera Bottles', 150.00, 'SKU-SMO-036', true),

    -- Fruity Temptations
    ('11111111-1111-1111-1111-111111111104', 'Choco Mixed Fruits (Classic)', 'Fresh seasonal mixed fruits drenched in rich melted chocolate', 'Fruity Temptations', 160.00, 'SKU-SMO-037', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Mixed Fruits (Premium)', 'Premium cut exotic fruits bathed in Belgian chocolate fondue', 'Fruity Temptations', 189.00, 'SKU-SMO-038', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Mango (Classic)', 'Fresh mango cubes layered with chocolate sauce', 'Fruity Temptations', 99.00, 'SKU-SMO-039', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Mango (Premium)', 'Premium sweet mango chunks smothered in thick melted chocolate', 'Fruity Temptations', 129.00, 'SKU-SMO-040', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Robusta (Classic)', 'Sliced ripe robusta bananas coated with chocolate ganache', 'Fruity Temptations', 79.00, 'SKU-SMO-041', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Robusta (Premium)', 'Premium double dipped robusta bananas with hot chocolate fondue', 'Fruity Temptations', 109.00, 'SKU-SMO-042', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Strawberry (Classic)', 'Fresh juicy strawberries dipped in melted chocolate (APM)', 'Fruity Temptations', 120.00, 'SKU-SMO-043', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Strawberry (Premium)', 'Premium imported strawberries smothered in Belgian chocolate (APM)', 'Fruity Temptations', 150.00, 'SKU-SMO-044', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Kiwi (Classic)', 'Tangy fresh kiwi slices layered with chocolate sauce (APM)', 'Fruity Temptations', 110.00, 'SKU-SMO-045', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Kiwi (Premium)', 'Premium fresh kiwi slices smothered in Belgian chocolate (APM)', 'Fruity Temptations', 140.00, 'SKU-SMO-046', true),

    -- Crafted to Refresh (99/-)
    ('11111111-1111-1111-1111-111111111104', 'Milo Dinosaur', 'Cold chocolate malt drink topped with a huge mountain of Milo powder', 'Crafted to Refresh', 99.00, 'SKU-SMO-047', true),
    ('11111111-1111-1111-1111-111111111104', 'Malaysian Mango Milk', 'Authentic creamy Malaysian sweet mango milk cooler', 'Crafted to Refresh', 99.00, 'SKU-SMO-048', true),
    ('11111111-1111-1111-1111-111111111104', 'Korean Strawberry Milk', 'Authentic strawberry milk with fresh macerated berry puree', 'Crafted to Refresh', 99.00, 'SKU-SMO-049', true),
    ('11111111-1111-1111-1111-111111111104', 'Vietnamese Iced Coffee', 'Bold dark roast coffee slowly dripped over sweetened condensed milk & ice', 'Crafted to Refresh', 99.00, 'SKU-SMO-050', true),

    -- Smoocho Signature
    ('11111111-1111-1111-1111-111111111104', 'Choco Tsunami', 'Signature chocolate dessert overflow with chocolate pearls & cream', 'Smoocho Signature', 229.00, 'SKU-SMO-051', true),
    ('11111111-1111-1111-1111-111111111104', 'Cheese Bomb', 'Decadent melted sweet cheese explosion with golden crispy toppings', 'Smoocho Signature', 279.00, 'SKU-SMO-052', true),
    ('11111111-1111-1111-1111-111111111104', 'French Kiss (Medium)', 'Artisanal layered pastry with delicate cream, berries & chocolate', 'Smoocho Signature', 449.00, 'SKU-SMO-053', true),
    ('11111111-1111-1111-1111-111111111104', 'French Kiss (Large)', 'Grand size artisanal French pastry loaded with premium ganache', 'Smoocho Signature', 799.00, 'SKU-SMO-054', true),
    ('11111111-1111-1111-1111-111111111104', 'Matilda Tsunami', 'Incredibly rich chocolate fudge cake drenched in molten chocolate ganache', 'Smoocho Signature', 259.00, 'SKU-SMO-055', true),
    ('11111111-1111-1111-1111-111111111104', 'Matilda Cup', 'Convenient take-along cup of super moist Matilda fudge chocolate cake', 'Smoocho Signature', 199.00, 'SKU-SMO-056', true),
    ('11111111-1111-1111-1111-111111111104', 'Smoocho Bueno', 'Signature dessert cup featuring Kinder Bueno cream & crunchy wafers', 'Smoocho Signature', 199.00, 'SKU-SMO-057', true),
    ('11111111-1111-1111-1111-111111111104', 'Ferrero Brownie', 'Fudgy warm brownie layered with hazelnut spread & Ferrero Rocher', 'Smoocho Signature', 199.00, 'SKU-SMO-058', true),

    -- Choco Desserts
    ('11111111-1111-1111-1111-111111111104', 'Choco Spunge (Classic)', 'Soft moist sponge cake soaked in milk chocolate sauce', 'Choco Desserts', 79.00, 'SKU-SMO-059', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Spunge (Premium)', 'Premium warm sponge cake layered with rich dark chocolate ganache', 'Choco Desserts', 109.00, 'SKU-SMO-060', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Brownie (Classic)', 'Classic fudgy chocolate brownie with chocolate drizzle', 'Choco Desserts', 99.00, 'SKU-SMO-061', true),
    ('11111111-1111-1111-1111-111111111104', 'Choco Brownie (Premium)', 'Gourmet walnut chocolate brownie drenched in molten Belgian fudge', 'Choco Desserts', 129.00, 'SKU-SMO-062', true),

    -- Add-ons
    ('11111111-1111-1111-1111-111111111104', 'Add Ice Cream Scoop', 'Extra scoop of delicious vanilla ice cream to accompany any dessert', 'Add-ons', 39.00, 'SKU-SMO-063', true);

-- 7. Ensure RLS Permissions
DROP POLICY IF EXISTS "Allow read shops" ON public.shops;
CREATE POLICY "Allow read shops" ON public.shops FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Allow read products" ON public.products;
CREATE POLICY "Allow read products" ON public.products FOR SELECT TO public USING (true);

COMMIT;
