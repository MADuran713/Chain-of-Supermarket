-- 2026-11-23T19:27:37.287Z
BEGIN;

-- 2026-11-23T19:27:37.288Z params=[101,"CARD",1001]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-11-23T19:27:37.298Z params=[1,101,12]
INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
             SELECT $1::int, ROW_NUMBER() OVER (ORDER BY p.sku), p.sku, p.qty, p.unit_price,
                    ROUND(p.qty * p.unit_price * CASE WHEN p.taxable THEN p.tax_rate ELSE 0 END, 2),
                    ROUND(p.qty * p.unit_price, 2)
             FROM (SELECT i.sku, i.unit_price, i.taxable, t.tax_rate,
                          CASE WHEN i.sold_by_weight THEN ROUND((0.5 + random() * 3.5)::numeric, 2)
                               ELSE (1 + floor(random() * 3))::numeric END AS qty
                   FROM store_stock ss
                   JOIN item i ON i.sku = ss.sku
                   JOIN store s ON s.store_id = ss.store_id
                   JOIN state_tax t ON t.state = s.state
                   WHERE ss.store_id = $2::int AND ss.qty_on_hand >= 5
                   ORDER BY random() LIMIT $3::int) p;

-- 2026-11-23T19:27:37.316Z params=[1,101]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-11-23T19:27:37.318Z params=[1]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-11-23T19:27:37.322Z params=["80.12",1001]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-11-23T19:27:37.326Z params=["80.12",1]
UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2;

-- 2026-11-23T19:27:37.327Z params=[1001,"80.12",1]
INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                 VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT');

-- 2026-11-23T19:27:37.331Z
COMMIT;

-- 2026-11-23T19:28:06.337Z
BEGIN;

-- 2026-11-23T19:28:06.338Z params=[101,"CARD",1005]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-11-23T19:28:06.344Z params=[2,101,12]
INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
             SELECT $1::int, ROW_NUMBER() OVER (ORDER BY p.sku), p.sku, p.qty, p.unit_price,
                    ROUND(p.qty * p.unit_price * CASE WHEN p.taxable THEN p.tax_rate ELSE 0 END, 2),
                    ROUND(p.qty * p.unit_price, 2)
             FROM (SELECT i.sku, i.unit_price, i.taxable, t.tax_rate,
                          CASE WHEN i.sold_by_weight THEN ROUND((0.5 + random() * 3.5)::numeric, 2)
                               ELSE (1 + floor(random() * 3))::numeric END AS qty
                   FROM store_stock ss
                   JOIN item i ON i.sku = ss.sku
                   JOIN store s ON s.store_id = ss.store_id
                   JOIN state_tax t ON t.state = s.state
                   WHERE ss.store_id = $2::int AND ss.qty_on_hand >= 5
                   ORDER BY random() LIMIT $3::int) p;

-- 2026-11-23T19:28:06.358Z params=[2,101]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-11-23T19:28:06.362Z params=[2]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-11-23T19:28:06.364Z params=["78.91",1005]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-11-23T19:28:06.368Z
ROLLBACK -- new row for relation "account" violates check constraint "account_balance_check";

-- 2026-11-23T19:28:29.720Z
BEGIN;

-- 2026-11-23T19:28:29.721Z params=[1]
SELECT account_id FROM bank.account WHERE account_id <> $1 ORDER BY random() LIMIT 1;

-- 2026-11-23T19:28:29.725Z params=[194,"CARD",1027]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-11-23T19:28:29.727Z params=[3,194,15]
INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
             SELECT $1::int, ROW_NUMBER() OVER (ORDER BY p.sku), p.sku, p.qty, p.unit_price,
                    ROUND(p.qty * p.unit_price * CASE WHEN p.taxable THEN p.tax_rate ELSE 0 END, 2),
                    ROUND(p.qty * p.unit_price, 2)
             FROM (SELECT i.sku, i.unit_price, i.taxable, t.tax_rate,
                          CASE WHEN i.sold_by_weight THEN ROUND((0.5 + random() * 3.5)::numeric, 2)
                               ELSE (1 + floor(random() * 3))::numeric END AS qty
                   FROM store_stock ss
                   JOIN item i ON i.sku = ss.sku
                   JOIN store s ON s.store_id = ss.store_id
                   JOIN state_tax t ON t.state = s.state
                   WHERE ss.store_id = $2::int AND ss.qty_on_hand >= 5
                   ORDER BY random() LIMIT $3::int) p;

-- 2026-11-23T19:28:29.739Z params=[3,194]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-11-23T19:28:29.744Z params=[3]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-11-23T19:28:29.745Z params=["122.54",1027]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-11-23T19:28:29.746Z params=["122.54",1]
UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2;

-- 2026-11-23T19:28:29.747Z params=[1027,"122.54",1]
INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                 VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT');

-- 2026-11-23T19:28:29.749Z
COMMIT;

-- 2026-11-23T19:28:29.752Z
BEGIN;

-- 2026-11-23T19:28:29.752Z params=[1]
SELECT account_id FROM bank.account WHERE account_id <> $1 ORDER BY random() LIMIT 1;

-- 2026-11-23T19:28:29.753Z params=[180,"CARD",1030]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-11-23T19:28:29.754Z params=[4,180,16]
INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
             SELECT $1::int, ROW_NUMBER() OVER (ORDER BY p.sku), p.sku, p.qty, p.unit_price,
                    ROUND(p.qty * p.unit_price * CASE WHEN p.taxable THEN p.tax_rate ELSE 0 END, 2),
                    ROUND(p.qty * p.unit_price, 2)
             FROM (SELECT i.sku, i.unit_price, i.taxable, t.tax_rate,
                          CASE WHEN i.sold_by_weight THEN ROUND((0.5 + random() * 3.5)::numeric, 2)
                               ELSE (1 + floor(random() * 3))::numeric END AS qty
                   FROM store_stock ss
                   JOIN item i ON i.sku = ss.sku
                   JOIN store s ON s.store_id = ss.store_id
                   JOIN state_tax t ON t.state = s.state
                   WHERE ss.store_id = $2::int AND ss.qty_on_hand >= 5
                   ORDER BY random() LIMIT $3::int) p;

-- 2026-11-23T19:28:29.756Z params=[4,180]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-11-23T19:28:29.757Z params=[4]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-11-23T19:28:29.758Z params=["134.46",1030]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-11-23T19:28:29.759Z params=["134.46",1]
UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2;

-- 2026-11-23T19:28:29.760Z params=[1030,"134.46",1]
INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                 VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT');

-- 2026-11-23T19:28:29.760Z
COMMIT;

-- 2026-11-23T19:28:30.306Z
-- BUSINESS SIMULATION: 99 committed, 1 rolled back across 100 stores in 638.21 ms;

-- 2026-11-23T19:29:05.444Z
BEGIN;

-- 2026-11-23T19:29:05.445Z params=[1]
SELECT account_id FROM bank.account WHERE account_id <> $1 ORDER BY random() LIMIT 1;

-- 2026-11-23T19:29:05.449Z params=[101,"CARD",1007]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-11-23T19:29:05.464Z params=[103,101,12]
INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
             SELECT $1::int, ROW_NUMBER() OVER (ORDER BY p.sku), p.sku, p.qty, p.unit_price,
                    ROUND(p.qty * p.unit_price * CASE WHEN p.taxable THEN p.tax_rate ELSE 0 END, 2),
                    ROUND(p.qty * p.unit_price, 2)
             FROM (SELECT i.sku, i.unit_price, i.taxable, t.tax_rate,
                          CASE WHEN i.sold_by_weight THEN ROUND((0.5 + random() * 3.5)::numeric, 2)
                               ELSE (1 + floor(random() * 3))::numeric END AS qty
                   FROM store_stock ss
                   JOIN item i ON i.sku = ss.sku
                   JOIN store s ON s.store_id = ss.store_id
                   JOIN state_tax t ON t.state = s.state
                   WHERE ss.store_id = $2::int AND ss.qty_on_hand >= 5
                   ORDER BY random() LIMIT $3::int) p;

-- 2026-11-23T19:29:05.488Z params=[103,101]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-11-23T19:29:05.492Z params=[103]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-11-23T19:29:05.493Z params=["58.59",1007]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-11-23T19:29:05.494Z params=["58.59",1]
UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2;

-- 2026-11-23T19:29:05.495Z params=[1007,"58.59",1]
INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                 VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT');

-- 2026-11-23T19:29:05.506Z
COMMIT;

-- 2026-11-23T19:29:05.546Z
-- CONCURRENT TEST (8 parallel connections on store 101): 8 committed, 0 rolled back in 158.46 ms;

-- 2026-11-23T19:30:56.049Z
BEGIN;

-- 2026-11-23T19:30:56.050Z params=[101,"CARD",1001]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-11-23T19:30:56.065Z params=[111,101,12]
INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
             SELECT $1::int, ROW_NUMBER() OVER (ORDER BY p.sku), p.sku, p.qty, p.unit_price,
                    ROUND(p.qty * p.unit_price * CASE WHEN p.taxable THEN p.tax_rate ELSE 0 END, 2),
                    ROUND(p.qty * p.unit_price, 2)
             FROM (SELECT i.sku, i.unit_price, i.taxable, t.tax_rate,
                          CASE WHEN i.sold_by_weight THEN ROUND((0.5 + random() * 3.5)::numeric, 2)
                               ELSE (1 + floor(random() * 3))::numeric END AS qty
                   FROM store_stock ss
                   JOIN item i ON i.sku = ss.sku
                   JOIN store s ON s.store_id = ss.store_id
                   JOIN state_tax t ON t.state = s.state
                   WHERE ss.store_id = $2::int AND ss.qty_on_hand >= 5
                   ORDER BY random() LIMIT $3::int) p;

-- 2026-11-23T19:30:56.086Z params=[111,101]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-11-23T19:30:56.111Z params=[111]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-11-23T19:30:56.113Z params=["89.07",1001]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-11-23T19:30:56.115Z params=["89.07",1]
UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2;

-- 2026-11-23T19:30:56.116Z params=[1001,"89.07",1]
INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                 VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT');

-- 2026-11-23T19:30:56.118Z
COMMIT;

-- 2026-11-23T19:30:56.151Z
-- CONCURRENT TEST (8 parallel connections on store 101): 8 committed, 0 rolled back in 157.69 ms;

