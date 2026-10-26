DROP SCHEMA IF EXISTS bank CASCADE;
DROP TABLE IF EXISTS receipt_item CASCADE;
DROP TABLE IF EXISTS receipt CASCADE;
DROP TABLE IF EXISTS store_stock CASCADE;
DROP TABLE IF EXISTS item CASCADE;
DROP TABLE IF EXISTS aisle CASCADE;
DROP TABLE IF EXISTS store CASCADE;
DROP TABLE IF EXISTS state_tax CASCADE;

CREATE TABLE state_tax (
    state CHAR(2) PRIMARY KEY,
    tax_rate NUMERIC(5, 4) NOT NULL CHECK (tax_rate >= 0)
);

CREATE TABLE store (
    store_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(150) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state CHAR(2) NOT NULL REFERENCES state_tax(state),
    num_aisles INT NOT NULL CHECK (num_aisles >= 20)
);

CREATE TABLE aisle (
    store_id INT NOT NULL REFERENCES store(store_id) ON DELETE CASCADE,
    aisle_no INT NOT NULL,
    category VARCHAR(50) NOT NULL,
    PRIMARY KEY (store_id, aisle_no)
);

CREATE TABLE item (
    sku INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price NUMERIC(8, 2) NOT NULL CHECK (unit_price > 0),
    sold_by_weight BOOLEAN NOT NULL DEFAULT FALSE,
    taxable BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE store_stock (
    store_id INT NOT NULL,
    sku INT NOT NULL REFERENCES item(sku) ON DELETE CASCADE,
    aisle_no INT NOT NULL,
    qty_on_hand NUMERIC(10, 2) NOT NULL CHECK (qty_on_hand >= 0),
    PRIMARY KEY (store_id, sku),
    FOREIGN KEY (store_id, aisle_no) REFERENCES aisle(store_id, aisle_no)
);

CREATE TABLE receipt (
    receipt_id SERIAL PRIMARY KEY,
    store_id INT NOT NULL REFERENCES store(store_id),
    receipt_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(10) NOT NULL CHECK (payment_method IN ('CARD', 'CASH')),
    bank_account_id INT,
    subtotal NUMERIC(10, 2) DEFAULT 0.00,
    tax NUMERIC(10, 2) DEFAULT 0.00,
    total NUMERIC(10, 2) DEFAULT 0.00
);

CREATE TABLE receipt_item (
    receipt_id INT NOT NULL REFERENCES receipt(receipt_id) ON DELETE CASCADE,
    line_no INT NOT NULL,
    sku INT NOT NULL REFERENCES item(sku),
    quantity NUMERIC(8, 2) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(8, 2) NOT NULL,
    tax_amount NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    line_total NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (receipt_id, line_no)
);

CREATE SCHEMA bank;

CREATE TABLE bank.account (
    account_id INT PRIMARY KEY,
    owner_name VARCHAR(100) NOT NULL,
    balance NUMERIC(12, 2) NOT NULL CHECK (balance >= 0)
);

CREATE TABLE bank.bank_transaction (
    tx_id SERIAL PRIMARY KEY,
    account_id INT NOT NULL REFERENCES bank.account(account_id),
    amount NUMERIC(10, 2) NOT NULL,
    tx_type VARCHAR(20) NOT NULL CHECK (tx_type IN ('WITHDRAW', 'DEPOSIT')),
    tx_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_receipt_store ON receipt(store_id);
CREATE INDEX idx_stock_store_sku ON store_stock(store_id, sku);
CREATE INDEX idx_receipt_item_sku ON receipt_item(sku);