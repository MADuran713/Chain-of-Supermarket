-- 2026-10-26T20:31:01.816Z
BEGIN;

-- 2026-10-26T20:31:01.819Z params=[101,"CARD",1001]
INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id;

-- 2026-10-26T20:31:01.829Z params=[1,101,12]
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

-- 2026-10-26T20:31:01.845Z params=[1,101]
UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku;

-- 2026-10-26T20:31:01.856Z params=[1]
UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total;

-- 2026-10-26T20:31:01.859Z params=["132.50",1001]
UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2;

-- 2026-10-26T20:31:01.862Z params=["132.50",1]
UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2;

-- 2026-10-26T20:31:01.864Z params=[1001,"132.50",1]
INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                     VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT');

-- 2026-10-26T20:31:01.869Z
COMMIT;

