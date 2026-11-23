-- 2026-11-23T19:29:32.055Z params=[15]
SELECT r.receipt_id, r.store_id, s.name AS store_name, s.state,
       r.receipt_ts, r.payment_method, r.bank_account_id,
       r.subtotal, r.tax, r.total
FROM receipt r
JOIN store s ON s.store_id = r.store_id
WHERE r.receipt_ts >= NOW() - ($1 * INTERVAL '1 minute')
ORDER BY r.receipt_ts DESC, r.receipt_id DESC LIMIT 100;

-- 2026-11-23T19:29:54.490Z params=[15]
SELECT t.tx_id, t.account_id, a.owner_name, t.tx_type, t.amount,
       a.balance AS current_balance, t.tx_timestamp
FROM bank.bank_transaction t
JOIN bank.account a ON a.account_id = t.account_id
WHERE t.tx_timestamp >= NOW() - ($1 * INTERVAL '1 minute')
ORDER BY t.tx_timestamp DESC, t.tx_id DESC LIMIT 100;

-- 2026-11-23T19:31:18.505Z
SELECT s.state, COUNT(*) AS receipts, SUM(r.total) AS revenue, SUM(r.tax) AS tax_collected
FROM receipt r JOIN store s ON s.store_id = r.store_id
GROUP BY s.state ORDER BY revenue DESC;

-- 2026-11-23T19:31:23.319Z
SELECT i.sku, i.name, SUM(ri.quantity) AS qty_sold, SUM(ri.line_total) AS revenue
FROM receipt_item ri JOIN item i ON i.sku = ri.sku
GROUP BY i.sku, i.name ORDER BY revenue DESC LIMIT 10;

-- 2026-11-23T19:31:30.810Z
SELECT s.store_id, s.city, s.state, a.aisle_no, a.category, i.name, ss.qty_on_hand
FROM store_stock ss
JOIN store s ON s.store_id = ss.store_id
JOIN aisle a ON a.store_id = ss.store_id AND a.aisle_no = ss.aisle_no
JOIN item i ON i.sku = ss.sku
ORDER BY ss.qty_on_hand ASC LIMIT 10;

-- 2026-11-23T19:31:42.220Z
SELECT a.account_id, a.owner_name, a.balance, COUNT(t.tx_id) AS bank_txs, COALESCE(SUM(t.amount), 0) AS money_moved
FROM bank.account a LEFT JOIN bank.bank_transaction t ON t.account_id = a.account_id
GROUP BY a.account_id, a.owner_name, a.balance ORDER BY bank_txs DESC, a.account_id LIMIT 10;

-- 2026-11-23T19:31:50.270Z
SELECT r.receipt_id, s.city, s.state, r.payment_method, ri.line_no, i.name, ri.quantity,
       ri.unit_price, ri.tax_amount, ri.line_total, r.total
FROM receipt r
JOIN store s ON s.store_id = r.store_id
JOIN receipt_item ri ON ri.receipt_id = r.receipt_id
JOIN item i ON i.sku = ri.sku
WHERE r.receipt_id = (SELECT MAX(receipt_id) FROM receipt)
ORDER BY ri.line_no;

-- 2026-11-23T20:04:48.089Z
SELECT * FROM store LIMIT 10;

-- 2026-11-23T20:05:14.531Z
SELECT * FROM aisle LIMIT 10;

