-- 2026-10-26T20:30:46.245Z
SELECT * FROM store LIMIT 10;

-- 2026-10-26T20:31:33.716Z
SELECT s.state, COUNT(*) AS receipts, SUM(r.total) AS revenue, SUM(r.tax) AS tax_collected
FROM receipt r JOIN store s ON s.store_id = r.store_id
GROUP BY s.state ORDER BY revenue DESC;

-- 2026-10-26T20:31:37.040Z
SELECT i.sku, i.name, SUM(ri.quantity) AS qty_sold, SUM(ri.line_total) AS revenue
FROM receipt_item ri JOIN item i ON i.sku = ri.sku
GROUP BY i.sku, i.name ORDER BY revenue DESC LIMIT 10;

-- 2026-10-26T20:31:41.659Z
SELECT a.account_id, a.owner_name, a.balance, COUNT(t.tx_id) AS bank_txs, COALESCE(SUM(t.amount), 0) AS money_moved
FROM bank.account a LEFT JOIN bank.bank_transaction t ON t.account_id = a.account_id
GROUP BY a.account_id, a.owner_name, a.balance ORDER BY bank_txs DESC, a.account_id LIMIT 10;

