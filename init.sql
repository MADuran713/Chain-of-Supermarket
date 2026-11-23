-- 1. State sales tax jurisdictions (6 states >= 4 required)
INSERT INTO state_tax (state, tax_rate) VALUES
('TX', 0.0825),
('CA', 0.0725),
('NY', 0.0887),
('FL', 0.0600),
('IL', 0.0625),
('WA', 0.0650)
ON CONFLICT (state) DO UPDATE SET tax_rate = EXCLUDED.tax_rate;

-- 2. 100 supermarket stores across 6 states, each with 20-40 aisles
INSERT INTO store (store_id, name, address, city, state, num_aisles)
SELECT
    g AS store_id,
    'MegaMart #' || g || ' - ' ||
    (ARRAY['Houston','Dallas','Austin','San Antonio','Los Angeles','San Diego','San Francisco',
           'New York','Brooklyn','Buffalo','Miami','Orlando','Tampa','Chicago','Naperville',
           'Seattle','Bellevue'])[1 + (g % 17)] AS name,
    (100 + ((g * 37) % 8900)) || ' ' ||
    (ARRAY['Main St','Commerce Blvd','Market Ave','Oak Dr','Broadway','Washington St',
           'Parkway Rd','University Ave','Harbor Blvd','Highland Ave'])[1 + (g % 10)] AS address,
    (ARRAY['Houston','Dallas','Austin','San Antonio','Los Angeles','San Diego','San Francisco',
           'New York','Brooklyn','Buffalo','Miami','Orlando','Tampa','Chicago','Naperville',
           'Seattle','Bellevue'])[1 + (g % 17)] AS city,
    (ARRAY['TX','TX','TX','TX','CA','CA','CA','NY','NY','NY','FL','FL','FL','IL','IL','WA','WA'])[1 + (g % 17)] AS state,
    20 + ((g * 7) % 21) AS num_aisles
FROM generate_series(101, 200) AS g
ON CONFLICT (store_id) DO NOTHING;

-- 3. Aisles for every store matching its exact num_aisles (20 to 40)
INSERT INTO aisle (store_id, aisle_no, category)
SELECT s.store_id, a.aisle_no,
       CASE 
         WHEN a.aisle_no BETWEEN 1 AND 5 THEN 'Produce'
         WHEN a.aisle_no BETWEEN 6 AND 10 THEN 'Dairy & Bakery'
         WHEN a.aisle_no BETWEEN 11 AND 15 THEN 'Meat & Seafood'
         WHEN a.aisle_no BETWEEN 16 AND 20 THEN 'Pantry & Canned Goods'
         WHEN a.aisle_no BETWEEN 21 AND 28 THEN 'Beverages & Snacks'
         WHEN a.aisle_no BETWEEN 29 AND 34 THEN 'Household & Cleaning'
         ELSE 'Frozen & Specialty'
       END
FROM store s
CROSS JOIN generate_series(1, 40) AS a(aisle_no)
WHERE a.aisle_no <= s.num_aisles
ON CONFLICT (store_id, aisle_no) DO NOTHING;

-- 4. Product catalog (30 SKUs: weighed produce/meat vs packaged, tax-exempt groceries vs taxable goods)
INSERT INTO item (sku, name, category, unit_price, sold_by_weight, taxable) VALUES
(1001, 'Organic Bananas', 'Produce', 0.69, TRUE, FALSE),
(1002, 'Honeycrisp Apples', 'Produce', 2.49, TRUE, FALSE),
(1003, 'Hass Avocados', 'Produce', 1.25, FALSE, FALSE),
(1004, 'Roma Tomatoes', 'Produce', 1.49, TRUE, FALSE),
(1005, 'Russet Potatoes 5lb Bag', 'Produce', 3.99, FALSE, FALSE),
(1006, 'Whole Milk 1 Gal', 'Dairy', 3.89, FALSE, FALSE),
(1007, 'Large Grade A Eggs 12ct', 'Dairy', 4.19, FALSE, FALSE),
(1008, 'Cheddar Cheese Block 8oz', 'Dairy', 3.49, FALSE, FALSE),
(1009, 'Greek Yogurt Plain 32oz', 'Dairy', 5.29, FALSE, FALSE),
(1010, 'Artisan Sourdough Bread', 'Bakery', 4.99, FALSE, FALSE),
(1011, 'Whole Wheat Sandwich Bread', 'Bakery', 3.29, FALSE, FALSE),
(1012, 'Ribeye Steak Choice', 'Meat', 14.99, TRUE, FALSE),
(1013, 'Boneless Chicken Breast', 'Meat', 3.99, TRUE, FALSE),
(1014, 'Atlantic Salmon Fillet', 'Meat', 9.99, TRUE, FALSE),
(1015, 'Ground Turkey Lean 1lb', 'Meat', 4.79, FALSE, FALSE),
(1016, 'Jasmine Rice 5lb', 'Pantry', 6.49, FALSE, FALSE),
(1017, 'Olive Oil Extra Virgin 500ml', 'Pantry', 9.29, FALSE, FALSE),
(1018, 'Organic Marinara Sauce', 'Pantry', 3.79, FALSE, FALSE),
(1019, 'Penne Rigate Pasta 16oz', 'Pantry', 1.89, FALSE, FALSE),
(1020, 'Black Beans Canned 15oz', 'Pantry', 1.29, FALSE, FALSE),
(1021, 'Sparkling Spring Water 12pk', 'Beverages', 5.99, FALSE, TRUE),
(1022, 'Craft Cola 6pk', 'Beverages', 4.49, FALSE, TRUE),
(1023, 'Dark Roast Coffee Beans 12oz', 'Beverages', 8.99, FALSE, FALSE),
(1024, 'Orange Juice Pulp Free 52oz', 'Beverages', 4.29, FALSE, FALSE),
(1025, 'Tortilla Chips Party Size', 'Snacks', 4.29, FALSE, TRUE),
(1026, 'Roasted Almonds Sea Salt 16oz', 'Snacks', 7.49, FALSE, TRUE),
(1027, 'Paper Towels 6 Rolls', 'Household', 11.49, FALSE, TRUE),
(1028, 'Dish Soap Lavender 24oz', 'Household', 3.99, FALSE, TRUE),
(1029, 'Laundry Detergent Pods 42ct', 'Household', 14.99, FALSE, TRUE),
(1030, 'Trash Bags Tall Kitchen 45ct', 'Household', 9.79, FALSE, TRUE)
ON CONFLICT (sku) DO NOTHING;

-- 5. Shelf stock across all 100 stores x 30 items = 3,000 inventory records
INSERT INTO store_stock (store_id, sku, aisle_no, qty_on_hand)
SELECT s.store_id, i.sku,
       CASE 
         WHEN i.category = 'Produce' THEN 2
         WHEN i.category = 'Dairy' THEN 7
         WHEN i.category = 'Bakery' THEN 9
         WHEN i.category = 'Meat' THEN 12
         WHEN i.category = 'Pantry' THEN 17
         WHEN i.category = 'Beverages' THEN 19
         WHEN i.category = 'Snacks' THEN 20
         ELSE 18
       END,
       250.00
FROM store s
CROSS JOIN item i
ON CONFLICT (store_id, sku) DO NOTHING;

-- 6. Corporate treasury account (#1) + 50 customer accounts (#1001-#1050)
INSERT INTO bank.account (account_id, owner_name, balance) VALUES
(1, 'Supermarket Chain Corporate', 500000.00),
(1001, 'Alice Smith', 2500.00),
(1002, 'Bob Johnson', 1850.50),
(1003, 'Carlos Rodriguez', 3100.00),
(1004, 'Diana Patel', 1430.25),
(1005, 'Evan Williams (Low Balance Test)', 25.00)
ON CONFLICT (account_id) DO NOTHING;

INSERT INTO bank.account (account_id, owner_name, balance)
SELECT g, 'Customer #' || g, ROUND((800 + ((g * 137) % 3500))::numeric, 2)
FROM generate_series(1006, 1050) AS g
ON CONFLICT (account_id) DO NOTHING;