# Supermarket chain - HW4 Phase 1

## Run it
1. Install Node.js and PostgreSQL, then create the database: `createdb supermarket`
2. `npm install`
3. `PGPASSWORD=yourpassword npm start` (defaults: user `postgres`, password `postgres`, db `supermarket`, host `localhost`)
4. Open http://localhost:3000/home.html
5. Click **Create tables**, then **Initialize lookup data**, then **Checkout one customer** or **Run simulation**.

`transaction.sql` and `query.sql` are written automatically in this folder as the app runs.

## Preliminary ER model

```mermaid
erDiagram
  STATE_TAX ||--o{ STORE : "taxes"
  STORE ||--o{ AISLE : "has 20-40"
  AISLE ||--o{ STORE_STOCK : "shelves"
  ITEM ||--o{ STORE_STOCK : "stocked as"
  STORE ||--o{ RECEIPT : "rings up"
  RECEIPT ||--|{ RECEIPT_ITEM : "contains"
  ITEM ||--o{ RECEIPT_ITEM : "sold as"
  BANK_ACCOUNT ||--o{ BANK_TRANSACTION : "records"

  STATE_TAX { char state PK
              numeric tax_rate }
  STORE { int store_id PK
          string name
          string address
          string city
          char state FK
          int num_aisles }
  AISLE { int store_id PK
          int aisle_no PK
          string category }
  ITEM { int sku PK
         string name
         string category
         numeric unit_price
         bool sold_by_weight
         bool taxable }
  STORE_STOCK { int store_id PK
                int sku PK
                int aisle_no FK
                numeric qty_on_hand }
  RECEIPT { int receipt_id PK
            int store_id FK
            timestamp receipt_ts
            string payment_method
            int bank_account_id
            numeric subtotal
            numeric tax
            numeric total }
  RECEIPT_ITEM { int receipt_id PK
                 int line_no PK
                 int sku FK
                 numeric quantity
                 numeric unit_price
                 numeric tax_amount
                 numeric line_total }
  BANK_ACCOUNT { int account_id PK
                 string owner_name
                 numeric balance }
  BANK_TRANSACTION { int tx_id PK
                     int account_id FK
                     numeric amount
                     string tx_type
                     timestamp tx_timestamp }
```

The bank is its own set of tables (schema `bank`). `receipt.bank_account_id` references the account by value only, with no cross-system foreign key. Both schemas live in one PostgreSQL database so the checkout can be a single ACID transaction.

Composite keys: `aisle(store_id, aisle_no)`, `store_stock(store_id, sku)`, `receipt_item(receipt_id, line_no)`.
`receipt_item` is the most detailed table: price, quantity or weight, tax and line total for every receipt line.

## Normalization notes (to justify in the report)
- All tables are in BCNF. Every non-key attribute depends on the whole key and nothing else.
- Deliberate 3NF violations (derived or snapshot values):
  - `receipt_item.unit_price` and `tax_amount` are snapshots, so old receipts stay correct when prices or tax rates change.
  - `receipt.subtotal`, `tax` and `total` are derived from the lines, stored for fast reports.

## Checkout transaction (see `transaction.sql` after a run)
`BEGIN` -> insert receipt -> insert 10-20 random receipt lines -> decrement `store_stock` -> compute totals -> debit customer `bank.account` -> credit merchant account -> insert two `bank.bank_transaction` rows -> `COMMIT`. Any error, including insufficient funds (CHECK `balance >= 0`), triggers `ROLLBACK`.

## Phase 1 checklist
- [x] 9 SQL tables (>= 5), keys and referential integrity, composite keys, indexes
- [x] One transaction updating several tables, including the bank account
- [x] 5 report queries, all with joins (most with GROUP BY)
- [x] GUI buttons: create tables, initialize lookup data, browse 10 rows, delete rows (with confirmation), checkout, simulation, stop
- [x] SQL shown in the GUI and logged to `transaction.sql` / `query.sql`
- [ ] TODO (team): copy of 5 real supermarket receipts and how each field maps to the tables
- [ ] TODO (team): polished UML ER diagram (draw.io) based on the model above, plus the team task split
