INSERT INTO state_tax (state, tax_rate) VALUES
('TX', 0.0825),
('CA', 0.0725),
('NY', 0.0887),
('FL', 0.0600)
ON CONFLICT (state) DO UPDATE SET tax_rate = EXCLUDED.tax_rate;

INSERT INTO store (store_id, name, address, city, state, num_aisles) VALUES
(101, 'MegaMart Houston Central', '4800 Calhoun Rd', 'Houston', 'TX', 25),
(102, 'MegaMart Dallas North', '1200 Main St', 'Dallas', 'TX', 30),
(103, 'MegaMart Austin West', '500 Lamar Blvd', 'Austin', 'TX', 24),
(104, 'MegaMart Los Angeles Downtown', '700 Figueroa St', 'Los Angeles', 'CA', 32),
(105, 'MegaMart San Francisco Bay', '300 Market St', 'San Francisco', 'CA', 28),
(106, 'MegaMart Manhattan Midtown', '350 5th Ave', 'New York', 'NY', 22),
(107, 'MegaMart Brooklyn South', '100 Atlantic Ave', 'Brooklyn', 'NY', 26),
(108, 'MegaMart Miami Beach', '1100 Ocean Dr', 'Miami', 'FL', 25),
(109, 'MegaMart Orlando Lakes', '400 Orange Ave', 'Orlando', 'FL', 27),
(110, 'MegaMart Tampa Bay', '600 Tampa St', 'Tampa', 'FL', 24)
ON CONFLICT (store_id) DO NOTHING;

INSERT INTO aisle (store_id, aisle_no, category)
SELECT s.store_id, a.aisle_no,
       CASE 
         WHEN a.aisle_no BETWEEN 1 AND 5 THEN 'Produce'
         WHEN a.aisle_no BETWEEN 6 AND 10 THEN 'Dairy & Bakery'
         WHEN a.aisle_no BETWEEN 11 AND 15 THEN 'Meat & Seafood'
         WHEN a.aisle_no BETWEEN 16 AND 20 THEN 'Pantry & Canned Goods'
         ELSE 'Beverages & Snacks'
       END
FROM store s
CROSS JOIN generate_series(1, 25) AS a(aisle_no)
ON CONFLICT (store_id, aisle_no) DO NOTHING;

INSERT INTO item (sku, name, category, unit_price, sold_by_weight, taxable) VALUES
(1001, 'Organic Bananas', 'Produce', 0.69, TRUE, FALSE),
(1002, 'Honeycrisp Apples', 'Produce', 2.49, TRUE, FALSE),
(1003, 'Hass Avocados', 'Produce', 1.25, FALSE, FALSE),
(1004, 'Whole Milk 1 Gal', 'Dairy', 3.89, FALSE, FALSE),
(1005, 'Large Grade A Eggs 12ct', 'Dairy', 4.19, FALSE, FALSE),
(1006, 'Cheddar Cheese Block 8oz', 'Dairy', 3.49, FALSE, FALSE),
(1007, 'Artisan Sourdough Bread', 'Bakery', 4.99, FALSE, FALSE),
(1008, 'Ribeye Steak Choice', 'Meat', 14.99, TRUE, FALSE),
(1009, 'Boneless Chicken Breast', 'Meat', 3.99, TRUE, FALSE),
(1010, 'Atlantic Salmon Fillet', 'Meat', 9.99, TRUE, FALSE),
(1011, 'Jasmine Rice 5lb', 'Pantry', 6.49, FALSE, FALSE),
(1012, 'Olive Oil Extra Virgin 500ml', 'Pantry', 9.29, FALSE, FALSE),
(1013, 'Organic Marinara Sauce', 'Pantry', 3.79, FALSE, FALSE),
(1014, 'Sparkling Spring Water 12pk', 'Beverages', 5.99, FALSE, TRUE),
(1015, 'Craft Cola 6pk', 'Beverages', 4.49, FALSE, TRUE),
(1016, 'Tortilla Chips Party Size', 'Snacks', 4.29, FALSE, TRUE),
(1017, 'Dark Roast Coffee Beans 12oz', 'Beverages', 8.99, FALSE, FALSE),
(1018, 'Paper Towels 6 Rolls', 'Household', 11.49, FALSE, TRUE),
(1019, 'Dish Soap Lavender 24oz', 'Household', 3.99, FALSE, TRUE),
(1020, 'Laundry Detergent Pods 42ct', 'Household', 14.99, FALSE, TRUE)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO store_stock (store_id, sku, aisle_no, qty_on_hand)
SELECT s.store_id, i.sku,
       CASE 
         WHEN i.category = 'Produce' THEN 2
         WHEN i.category = 'Dairy' THEN 7
         WHEN i.category = 'Bakery' THEN 9
         WHEN i.category = 'Meat' THEN 12
         WHEN i.category = 'Pantry' THEN 18
         ELSE 22
       END,
       150.00
FROM store s
CROSS JOIN item i
ON CONFLICT (store_id, sku) DO NOTHING;

INSERT INTO bank.account (account_id, owner_name, balance) VALUES
(1, 'Supermarket Chain Corporate', 500000.00),
(1001, 'Alice Smith', 1250.00),
(1002, 'Bob Johnson', 850.50),
(1003, 'Carlos Rodriguez', 2100.00),
(1004, 'Diana Patel', 430.25),
(1005, 'Evan Williams', 95.00)
ON CONFLICT (account_id) DO NOTHING;