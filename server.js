const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');
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
    database: process.env.PGDATABASE || 'supermarket',
    max: 30
});

const MERCHANT = 1; // bank.account id of the supermarket chain
const TABLES = ['state_tax', 'store', 'aisle', 'item', 'store_stock', 'receipt', 'receipt_item',
                'bank.account', 'bank.bank_transaction'];

let abortRequested = false;

// Trace files checked by the TAs: SQL statements sent by the app are appended here
const trace = (file, sql, params) =>
    fs.appendFileSync(path.join(__dirname, file),
        `-- ${new Date().toISOString()}${params && params.length ? ' params=' + JSON.stringify(params) : ''}\n${sql.trim()};\n\n`);

const elapsedMs = t0 => +(performance.now() - t0).toFixed(2);

// Wraps standard handlers: JSON response + elapsed milliseconds + error reporting
const wrap = fn => async (req, res) => {
    const t0 = performance.now();
    try {
        res.json({ success: true, ...(await fn(req)), ms: elapsedMs(t0) });
    } catch (e) {
        console.error(e);
        res.status(500).json({ success: false, message: e.message, ms: elapsedMs(t0) });
    }
};

// Serve README.md directly from GUI link
app.get('/readme', (req, res) => {
    res.type('text/plain; charset=utf-8');
    res.sendFile(path.join(__dirname, 'README.md'));
});

// Emergency stop / cancel flag for running simulations
app.post('/stop', (req, res) => {
    abortRequested = true;
    res.json({ success: true, message: 'Stop signal received. Halting active operations.', ms: 0 });
});

const runFile = name => wrap(async () => {
    const sql = fs.readFileSync(path.join(__dirname, name), 'utf8');
    await pool.query(sql);
    return { message: `${name} executed successfully`, sql };
});
app.post('/create-tables', runFile('schema.sql'));
app.post('/init-lookup', runFile('init.sql'));

// Transactional reset of operational tables so simulations can be repeated cleanly
app.post('/reset-transactions', wrap(async () => {
    const client = await pool.connect();
    const sql = `BEGIN;
TRUNCATE TABLE receipt_item, receipt, bank.bank_transaction RESTART IDENTITY;
UPDATE store_stock SET qty_on_hand = 250.00;
UPDATE bank.account SET balance = 500000.00 WHERE account_id = 1;
UPDATE bank.account SET balance = 25.00 WHERE account_id = 1005;
UPDATE bank.account SET balance = 2000.00 WHERE account_id NOT IN (1, 1005);
COMMIT;`;
    try {
        await client.query(sql);
        trace('transaction.sql', sql);
        return { message: 'Transaction tables cleared and stock/account balances reset', sql };
    } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        throw e;
    } finally {
        client.release();
    }
}));

app.get('/browse/:table', wrap(async req => {
    if (!TABLES.includes(req.params.table)) throw new Error('Unknown table');
    const sql = `SELECT * FROM ${req.params.table} LIMIT 10`;
    trace('query.sql', sql);
    return { message: `First 10 rows of ${req.params.table}`, sql, rows: (await pool.query(sql)).rows };
}));

app.post('/clear/:table', wrap(async req => {
    if (!TABLES.includes(req.params.table)) throw new Error('Unknown table');
    const client = await pool.connect();
    const sql = `BEGIN; TRUNCATE TABLE ${req.params.table} RESTART IDENTITY CASCADE; COMMIT;`;
    try {
        await client.query(sql);
        return { message: `${req.params.table} cleared (and dependent tables)`, sql };
    } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        throw e;
    } finally {
        client.release();
    }
}));

// ---------- View transactions within a recent time interval (minutes/hours) ----------
app.get('/recent-transactions', wrap(async req => {
    const mins = Math.max(1, Math.min(10080, parseInt(req.query.minutes || '15', 10) || 15));
    const type = req.query.type === 'bank' ? 'bank' : 'receipt';
    let sql, rows;

    if (type === 'bank') {
        sql = `SELECT t.tx_id, t.account_id, a.owner_name, t.tx_type, t.amount,
       a.balance AS current_balance, t.tx_timestamp
FROM bank.bank_transaction t
JOIN bank.account a ON a.account_id = t.account_id
WHERE t.tx_timestamp >= NOW() - ($1 * INTERVAL '1 minute')
ORDER BY t.tx_timestamp DESC, t.tx_id DESC LIMIT 100`;
    } else {
        sql = `SELECT r.receipt_id, r.store_id, s.name AS store_name, s.state,
       r.receipt_ts, r.payment_method, r.bank_account_id,
       r.subtotal, r.tax, r.total
FROM receipt r
JOIN store s ON s.store_id = r.store_id
WHERE r.receipt_ts >= NOW() - ($1 * INTERVAL '1 minute')
ORDER BY r.receipt_ts DESC, r.receipt_id DESC LIMIT 100`;
    }
    trace('query.sql', sql, [mins]);
    rows = (await pool.query(sql, [mins])).rows;
    return {
        message: `Found ${rows.length} ${type === 'bank' ? 'bank transactions' : 'receipts'} in the last ${mins} minute(s)`,
        sql: `${sql}\n-- params: [${mins}]`,
        rows
    };
}));

// ---------- Back office reports (all use joins; most use GROUP BY) ----------
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

// ---------- Core ACID Checkout Helper (Reusable for Single, Batch & Concurrent Runs) ----------
async function executeCheckout(client, { storeId, accountId, paymentMethod, numItems, logTrace = true }) {
    const t0 = performance.now();
    const blank = v => v === undefined || v === null || v === '';
    const method = paymentMethod === 'CASH' ? 'CASH' : (paymentMethod === 'CARD' ? 'CARD' : (Math.random() < 0.75 ? 'CARD' : 'CASH'));
    const n = blank(numItems) ? 10 + Math.floor(Math.random() * 11) : +numItems;

    const log = [];
    const q = (sql, params = []) => {
        if (logTrace) trace('transaction.sql', sql, params);
        log.push(sql.trim() + (params.length ? `\n-- params: ${JSON.stringify(params)}` : ''));
        return client.query(sql, params);
    };

    try {
        await q('BEGIN');

        const sid = blank(storeId)
            ? (await q('SELECT store_id FROM store ORDER BY random() LIMIT 1')).rows[0]?.store_id
            : +storeId;
        if (!sid) throw new Error('No stores found - click "Initialize Lookup Data" first');

        let acct = null;
        if (method === 'CARD') {
            acct = blank(accountId)
                ? (await q('SELECT account_id FROM bank.account WHERE account_id <> $1 ORDER BY random() LIMIT 1', [MERCHANT])).rows[0]?.account_id
                : +accountId;
            if (!acct) throw new Error('No customer bank accounts found - initialize lookup data first');
        }

        // 1) Insert receipt header
        const rid = (await q(
            `INSERT INTO receipt (store_id, payment_method, bank_account_id) VALUES ($1, $2, $3) RETURNING receipt_id`,
            [sid, method, acct]
        )).rows[0].receipt_id;

        // 2) Insert 10-20 random in-stock receipt lines with state tax calculation
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
            [rid, sid, n]
        );

        if (lines.rowCount === 0) {
            throw new Error(`Store ${sid} has insufficient stock to fulfill items`);
        }

        // 3) Decrement store shelf stock (CHECK qty_on_hand >= 0 enforces solvency)
        await q(
            `UPDATE store_stock ss SET qty_on_hand = ss.qty_on_hand - ri.quantity
             FROM receipt_item ri
             WHERE ri.receipt_id = $1 AND ss.store_id = $2 AND ss.sku = ri.sku`,
            [rid, sid]
        );

        // 4) Update receipt totals
        const total = (await q(
            `UPDATE receipt r SET subtotal = x.sub, tax = x.tax, total = x.sub + x.tax
             FROM (SELECT SUM(line_total) AS sub, SUM(tax_amount) AS tax FROM receipt_item WHERE receipt_id = $1) x
             WHERE r.receipt_id = $1 RETURNING r.total`,
            [rid]
        )).rows[0].total;

        // 5) Electronic card settlement (CHECK balance >= 0 rejects overdrafts)
        if (method === 'CARD') {
            const w = await q(`UPDATE bank.account SET balance = balance - $1 WHERE account_id = $2`, [total, acct]);
            if (w.rowCount !== 1) throw new Error(`Bank account ${acct} not found`);
            await q(`UPDATE bank.account SET balance = balance + $1 WHERE account_id = $2`, [total, MERCHANT]);
            await q(
                `INSERT INTO bank.bank_transaction (account_id, amount, tx_type)
                 VALUES ($1, $2, 'WITHDRAW'), ($3, $2, 'DEPOSIT')`,
                [acct, total, MERCHANT]
            );
        }

        await q('COMMIT');
        return {
            success: true,
            receiptId: rid,
            storeId: sid,
            accountId: acct,
            paymentMethod: method,
            lines: lines.rowCount,
            total,
            ms: elapsedMs(t0),
            sql: log.join('\n\n')
        };
    } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        if (logTrace) trace('transaction.sql', `ROLLBACK -- ${String(e.message).replace(/\n/g, ' ')}`);
        const declined = e.code === '23514';
        return {
            success: false,
            declined,
            message: declined ? `Rolled back (insufficient funds or stock): ${e.message}` : `Rolled back: ${e.message}`,
            ms: elapsedMs(t0),
            sql: log.join('\n\n')
        };
    }
}

// ---------- 1. Single Customer Checkout ----------
app.post('/simulate-transaction', async (req, res) => {
    const { storeId, accountId, paymentMethod, numItems } = req.body;
    const blank = v => v === undefined || v === null || v === '';
    for (const [name, v] of [['storeId', storeId], ['accountId', accountId], ['numItems', numItems]]) {
        if (!blank(v) && !(Number.isInteger(+v) && +v > 0)) {
            return res.status(400).json({ success: false, message: `${name} must be a positive integer`, ms: 0 });
        }
    }
    if (!blank(numItems) && (+numItems < 10 || +numItems > 20)) {
        return res.status(400).json({ success: false, message: 'Items per receipt must be 10-20', ms: 0 });
    }

    const client = await pool.connect();
    try {
        const result = await executeCheckout(client, {
            storeId,
            accountId,
            paymentMethod: paymentMethod === 'CASH' ? 'CASH' : 'CARD',
            numItems,
            logTrace: true
        });
        if (result.success) {
            res.json({
                success: true,
                message: `Receipt #${result.receiptId} at store ${result.storeId}: ${result.lines} lines, total $${result.total}, paid by ${result.paymentMethod}${result.accountId ? ' (acct ' + result.accountId + ')' : ''}`,
                sql: result.sql,
                ms: result.ms
            });
        } else {
            res.status(result.declined ? 409 : 500).json({
                success: false,
                message: result.message,
                sql: result.sql,
                ms: result.ms
            });
        }
    } finally {
        client.release();
    }
});

// ---------- 2. Real Business Simulation (e.g. 100 Customers Across Locations) ----------
app.post('/simulate-business', async (req, res) => {
    const t0 = performance.now();
    abortRequested = false;
    const count = Math.max(1, Math.min(500, parseInt(req.body.numCustomers || '100', 10) || 100));
    const scope = req.body.storeScope === 'three' ? 'three' : 'all';

    const client = await pool.connect();
    let succeeded = 0;
    let rolledBack = 0;
    let totalRevenue = 0;
    let sampleSql = '';
    const recentRows = [];

    try {
        const storeRes = await client.query(
            scope === 'three'
                ? 'SELECT store_id FROM store ORDER BY random() LIMIT 3'
                : 'SELECT store_id FROM store'
        );
        const storeIds = storeRes.rows.map(r => r.store_id);
        if (storeIds.length === 0) throw new Error('No stores found - click "Initialize Lookup Data" first');

        for (let i = 0; i < count; i++) {
            if (abortRequested) break;
            const targetStore = storeIds[Math.floor(Math.random() * storeIds.length)];
            const outcome = await executeCheckout(client, {
                storeId: targetStore,
                paymentMethod: 'RANDOM',
                logTrace: i < 2 // Log full SQL of first 2 transactions in batch to keep trace readable
            });
            if (i === 0) sampleSql = outcome.sql;

            if (outcome.success) {
                succeeded++;
                totalRevenue += parseFloat(outcome.total);
                if (recentRows.length < 15) {
                    recentRows.push({
                        customer_no: i + 1,
                        receipt_id: outcome.receiptId,
                        store_id: outcome.storeId,
                        payment: outcome.paymentMethod,
                        items: outcome.lines,
                        total: `$${outcome.total}`,
                        tx_time_ms: outcome.ms
                    });
                }
            } else {
                rolledBack++;
            }
        }

        const totalMs = elapsedMs(t0);
        const avgMs = succeeded + rolledBack > 0 ? +(totalMs / (succeeded + rolledBack)).toFixed(2) : 0;
        trace('transaction.sql', `-- BUSINESS SIMULATION: ${succeeded} committed, ${rolledBack} rolled back across ${storeIds.length} stores in ${totalMs} ms`);

        res.json({
            success: true,
            message: `${abortRequested ? '[STOPPED EARLY] ' : ''}Simulated ${succeeded + rolledBack} customers across ${storeIds.length} stores: ${succeeded} committed, ${rolledBack} rolled back, gross sales $${totalRevenue.toFixed(2)} (avg ${avgMs} ms/tx)`,
            rows: recentRows,
            sql: sampleSql,
            ms: totalMs
        });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message, ms: elapsedMs(t0) });
    } finally {
        client.release();
    }
});

// ---------- 3. Concurrent Processing Simulation (Parallel DB Connections) ----------
app.post('/simulate-concurrent', async (req, res) => {
    const t0 = performance.now();
    abortRequested = false;
    const workers = Math.max(2, Math.min(25, parseInt(req.body.concurrency || '8', 10) || 8));
    const targetStore = parseInt(req.body.storeId || '101', 10) || 101;
    const sameAccount = req.body.sameAccount === true || req.body.sameAccount === 'true';

    try {
        // Launch N parallel database connections simultaneously via Promise.all
        const tasks = Array.from({ length: workers }, async (_, idx) => {
            const client = await pool.connect();
            try {
                const outcome = await executeCheckout(client, {
                    storeId: targetStore,
                    accountId: sameAccount ? 1001 : undefined,
                    paymentMethod: 'CARD',
                    numItems: 12,
                    logTrace: idx === 0
                });
                return {
                    worker_conn: `Conn #${idx + 1}`,
                    store_id: targetStore,
                    account_id: outcome.accountId || (sameAccount ? 1001 : 'Random'),
                    status: outcome.success ? 'COMMITTED' : 'ROLLED BACK',
                    receipt_id: outcome.receiptId || '-',
                    total: outcome.total ? `$${outcome.total}` : '-',
                    latency_ms: outcome.ms,
                    detail: outcome.success ? `${outcome.lines} items settled` : outcome.message
                };
            } finally {
                client.release();
            }
        });

        const results = await Promise.all(tasks);
        const committed = results.filter(r => r.status === 'COMMITTED').length;
        const rolledBack = results.length - committed;
        const totalMs = elapsedMs(t0);

        trace('transaction.sql', `-- CONCURRENT TEST (${workers} parallel connections on store ${targetStore}): ${committed} committed, ${rolledBack} rolled back in ${totalMs} ms`);

        res.json({
            success: true,
            message: `Concurrent test (${workers} parallel connections at Store ${targetStore}): ${committed} COMMITTED, ${rolledBack} ROLLED BACK in ${totalMs} ms`,
            rows: results,
            sql: `-- Executed ${workers} concurrent BEGIN...COMMIT/ROLLBACK transactions on separate pool connections targeting Store ${targetStore}${sameAccount ? ' and Account #1001' : ''}`,
            ms: totalMs
        });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message, ms: elapsedMs(t0) });
    }
});

app.listen(3000, () => console.log('Supermarket App API running on http://localhost:3000/home.html'));