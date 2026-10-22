const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const app = express();
app.use(express.json());
app.use(cors());
app.use(express.static(path.join(__dirname, 'public')));

// Local PostgreSQL. Override with env vars: PGUSER, PGPASSWORD, PGDATABASE, PGHOST, PGPORT
const pool = new Pool({
    host: process.env.PGHOST || 'localhost',
    port: +(process.env.PGPORT || 5432),
    user: process.env.PGUSER || 'postgres',
    password: process.env.PGPASSWORD || 'postgres',
    database: process.env.PGDATABASE || 'supermarket'
});

const MERCHANT = 1; // bank.account id of the supermarket chain
const TABLES = ['state_tax', 'store', 'aisle', 'item', 'store_stock', 'receipt', 'receipt_item',
                'bank.account', 'bank.bank_transaction'];

// Trace files checked by the TAs: every SQL statement sent by the app is appended here
const trace = (file, sql, params) =>
    fs.appendFileSync(path.join(__dirname, file),
        `-- ${new Date().toISOString()}${params && params.length ? ' params=' + JSON.stringify(params) : ''}\n${sql.trim()};\n\n`);

// wraps a handler: JSON response + elapsed milliseconds + error reporting
const wrap = fn => async (req, res) => {
    const t0 = Date.now();
    try { res.json({ success: true, ...(await fn(req)), ms: Date.now() - t0 }); }
    catch (e) { console.error(e); res.status(500).json({ success: false, message: e.message, ms: Date.now() - t0 }); }
};

const runFile = name => wrap(async () => {
    const sql = fs.readFileSync(path.join(__dirname, name), 'utf8');
    await pool.query(sql);               // no parameters => multi-statement script allowed
    return { message: `${name} executed`, sql };
});
app.post('/create-tables', runFile('schema.sql'));
app.post('/init-lookup', runFile('init.sql'));

app.get('/browse/:table', wrap(async req => {
    if (!TABLES.includes(req.params.table)) throw new Error('Unknown table');
    const sql = `SELECT * FROM ${req.params.table} LIMIT 10`;
    trace('query.sql', sql);
    return { message: `First 10 rows of ${req.params.table}`, sql, rows: (await pool.query(sql)).rows };
}));

app.post('/clear/:table', wrap(async req => {
    if (!TABLES.includes(req.params.table)) throw new Error('Unknown table');
    const sql = `TRUNCATE TABLE ${req.params.table} RESTART IDENTITY CASCADE`;
    await pool.query(sql);
    return { message: `${req.params.table} cleared (and dependent tables)`, sql };
}));

// ---------- back office reports (all use joins; most use GROUP BY) ----------
const REPORTS = {
    salesByState: `SELECT s.state, COUNT(*) AS receipts, SUM(r.total) AS revenue, SUM(r.tax) AS tax_collected
FROM receipt r JOIN store s ON s.store_id = r.store_id
GROUP BY s.state ORDER BY revenue DESC`,
    topItems: `SELECT i.sku, i.name, SUM(ri.quantity) AS qty_sold, SUM(ri.line_total) AS revenue
FROM receipt_item ri JOIN item i ON i.sku = ri.sku
GROUP BY i.sku, i.name ORDER BY revenue DESC LIMIT 10`,
    lowStock: `SELECT s.store_id, s.city, s.state, a.aisle_no, a.category, i.name, ss.qty_on_hand
FROM store_stock ss
JOIN store s ON s.store_id = ss.store_id
JOIN aisle a ON a.store_id = ss.store_id AND a.aisle_no = ss.aisle_no
JOIN item i ON i.sku = ss.sku
ORDER BY ss.qty_on_hand ASC LIMIT 10`,
    bankActivity: `SELECT a.account_id, a.owner_name, a.balance, COUNT(t.tx_id) AS bank_txs, COALESCE(SUM(t.amount), 0) AS money_moved
FROM bank.account a LEFT JOIN bank.bank_transaction t ON t.account_id = a.account_id
GROUP BY a.account_id, a.owner_name, a.balance ORDER BY bank_txs DESC, a.account_id LIMIT 10`,
    receiptDetail: `SELECT r.receipt_id, s.city, s.state, r.payment_method, ri.line_no, i.name, ri.quantity,
       ri.unit_price, ri.tax_amount, ri.line_total, r.total
FROM receipt r
JOIN store s ON s.store_id = r.store_id
JOIN receipt_item ri ON ri.receipt_id = r.receipt_id
JOIN item i ON i.sku = ri.sku
WHERE r.receipt_id = (SELECT MAX(receipt_id) FROM receipt)
ORDER BY ri.line_no`
};
app.get('/report/:name', wrap(async req => {
    const sql = REPORTS[req.params.name];
    if (!sql) throw new Error('Unknown report');
    trace('query.sql', sql);
    return { message: `Report: ${req.params.name}`, sql, rows: (await pool.query(sql)).rows };
}));

// ---------- front desk: one customer checkout = ONE ACID transaction ----------
app.post('/simulate-transaction', async (req, res) => {
    const t0 = Date.now();
    const { storeId, accountId, paymentMethod, numItems } = req.body;
    const blank = v => v === undefined || v === null || v === '';
    const method = paymentMethod === 'CASH' ? 'CASH' : 'CARD';
    for (const [name, v] of [['storeId', storeId], ['accountId', accountId], ['numItems', numItems]])
        if (!blank(v) && !(Number.isInteger(+v) && +v > 0))
            return res.status(400).json({ success: false, message: `${name} must be a positive integer` });
    const n = blank(numItems) ? 10 + Math.floor(Math.random() * 11) : +numItems;   // 10-20 random items
    if (n < 10 || n > 20) return res.status(400).json({ success: false, message: 'Items per receipt must be 10-20' });

    const client = await pool.connect();
    const log = [];
    const q = (sql, params = []) => {
        trace('transaction.sql', sql, params);
        log.push(sql.trim() + (params.length ? `\n-- params: ${JSON.stringify(params)}` : ''));
        return client.query(sql, params);
    };
    try {
        await q('BEGIN');

        const sid = blank(storeId) ? (await q('SELECT store_id FROM store ORDER BY random() LIMIT 1')).rows[0]?.store_id : +storeId;
        if (!sid) throw new Error('No stores found - click "Initialize lookup data" first');
        let acct = null;
        if (method === 'CARD') {
            acct = blank(accountId)
                ? (await q('SELECT account_id FROM bank.account WHERE account_id <> $1 ORDER BY random() LIMIT 1', [MERCHANT])).rows[0]?.account_id
                : +accountId;
            if (!acct) throw new Error('No customer bank accounts found - initialize lookup data first');
        }

        // 1) receipt header
        const rid = (await q(
            `INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id`,
            [sid, method, acct])).rows[0].receipt_id;

        // 2) receipt lines: random in-stock items; weighed items get a random weight, others 1-3 units; state tax applied unless item is tax-free
        const lines = await q(
            `INSERT INTO receipt_item (receipt_id, line_no, sku, quantity, unit_price, tax_amount, line_total)
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
                   ORDER BY random() LIMIT $3::int) p`,
            [rid, sid, n]);

        // 3) decrement store stock
        await q(
            `UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku`,
            [rid, sid]);

        // 4) receipt totals
        const total = (await q(
            `UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total`, [rid])).rows[0].total;

        // 5) card payment: customer account -> supermarket account (balance CHECK >= 0 rejects insufficient funds)
        if (method === 'CARD') {
            const w = await q(`UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2`, [total, acct]);
            if (w.rowCount !== 1) throw new Error(`Bank account ${acct} not found`);
            await q(`UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2`, [total, MERCHANT]);
            await q(`INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                     VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT')`, [acct, total, MERCHANT]);
        }

        await q('COMMIT');
        res.json({
            success: true,
            message: `Receipt #${rid} at store ${sid}: ${lines.rowCount} lines, total $${total}, paid by ${method}${acct ? ' (account ' + acct + ')' : ''}`,
            receiptId: rid, total, sql: log.join('\n\n'), ms: Date.now() - t0
        });
    } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        trace('transaction.sql', `ROLLBACK -- ${String(e.message).replace(/\n/g, ' ')}`);
        const declined = e.code === '23514';   // check_violation: insufficient funds or stock
        console.error('Transaction failed:', e.message);
        res.status(declined ? 409 : 500).json({
            success: false,
            message: declined ? `Rolled back - insufficient funds or stock (${e.message})` : `Rolled back - ${e.message}`,
            sql: log.join('\n\n'), ms: Date.now() - t0
        });
    } finally {
        client.release();
    }
});

app.listen(3000, () => console.log('Supermarket App API running on http://localhost:3000/home.html'));
