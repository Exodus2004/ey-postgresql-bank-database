-- ====================================================================
-- PostgreSQL Conversion: Bank Database Training (DDL)
-- Module 1: Data Definition Language (Structure & Schema)
-- Converted from MySQL 8.0 for EY Training Lab
-- ====================================================================

-- --------------------------------------------------------------------
-- Step 1: Database Setup
-- --------------------------------------------------------------------
-- In MySQL:    CREATE DATABASE IF NOT EXISTS bank_db; USE bank_db;
-- In Postgres: Databases are created, then connected via '\c bank_db'
-- --------------------------------------------------------------------

-- Connect to default postgres database first, then create bank_db if not exists:
-- CREATE DATABASE bank_db;
-- \c bank_db

-- Drop existing tables if re-running (child table first due to Foreign Key)
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- --------------------------------------------------------------------
-- Step 2: Parent Table - customers
-- --------------------------------------------------------------------
-- MySQL:    customer_id INT AUTO_INCREMENT PRIMARY KEY, ENGINE = InnoDB
-- Postgres: customer_id SERIAL PRIMARY KEY (or GENERATED ALWAYS AS IDENTITY)
--           (No ENGINE clause needed - PostgreSQL uses ACID storage by default)
-- --------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    SERIAL PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) UNIQUE,
    phone          VARCHAR(15),
    date_of_birth  DATE,
    city           VARCHAR(50)  DEFAULT 'Bengaluru',
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- Step 3: Child Table - accounts
-- --------------------------------------------------------------------
-- MySQL:    account_no BIGINT AUTO_INCREMENT PRIMARY KEY, ENGINE = InnoDB
-- Postgres: account_no BIGSERIAL PRIMARY KEY
-- --------------------------------------------------------------------
CREATE TABLE accounts (
    account_no    BIGSERIAL PRIMARY KEY,
    customer_id   INT           NOT NULL,
    account_type  VARCHAR(20)   NOT NULL,
    balance       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    branch        VARCHAR(50),
    status        VARCHAR(10)   DEFAULT 'ACTIVE',
    opened_on     DATE          NOT NULL,
    CONSTRAINT chk_acc_type CHECK (account_type IN ('SAVINGS','CURRENT','SALARY')),
    CONSTRAINT chk_balance  CHECK (balance >= 0),
    CONSTRAINT fk_acc_cust  FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- --------------------------------------------------------------------
-- Step 4: Verify Table Structures in PostgreSQL
-- --------------------------------------------------------------------
-- MySQL:    SHOW TABLES; DESCRIBE customers; DESCRIBE accounts;
-- Postgres: In psql use \dt, \d customers, \d accounts
--           Or use standard SQL information_schema queries below:
-- --------------------------------------------------------------------
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';

SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'customers';

-- --------------------------------------------------------------------
-- Step 5: ALTER TABLE Operations
-- --------------------------------------------------------------------

-- 1. Add column kyc_status with default
ALTER TABLE customers ADD COLUMN kyc_status VARCHAR(10) DEFAULT 'PENDING';

-- 2. Modify/Widen column
-- MySQL:    ALTER TABLE customers MODIFY COLUMN phone VARCHAR(20);
-- Postgres: ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);
ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);

-- 3. Add temporary column
ALTER TABLE accounts ADD COLUMN nominee_name VARCHAR(50);

-- 4. Rename column
-- MySQL:    ALTER TABLE accounts CHANGE COLUMN nominee_name nominee VARCHAR(50);
-- Postgres: ALTER TABLE accounts RENAME COLUMN nominee_name TO nominee;
ALTER TABLE accounts RENAME COLUMN nominee_name TO nominee;

-- 5. Drop temporary column
ALTER TABLE accounts DROP COLUMN nominee;

-- 6. Add a CHECK constraint after the table exists
ALTER TABLE accounts 
    ADD CONSTRAINT chk_status CHECK (status IN ('ACTIVE','DORMANT','CLOSED'));

-- --------------------------------------------------------------------
-- Step 6: CREATE INDEX
-- --------------------------------------------------------------------
-- MySQL:    CREATE INDEX idx_customers_city ON customers (city); SHOW INDEX FROM customers;
-- Postgres: In psql use \di or query pg_indexes
-- --------------------------------------------------------------------
CREATE INDEX idx_customers_city ON customers (city);

SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'customers';

-- --------------------------------------------------------------------
-- Step 7: Scratch Table Practice (RENAME, TRUNCATE, DROP)
-- --------------------------------------------------------------------
CREATE TABLE demo_log (
    id INT PRIMARY KEY, 
    note VARCHAR(50)
);

INSERT INTO demo_log VALUES (1, 'first'), (2, 'second');

-- Rename table
-- MySQL:    RENAME TABLE demo_log TO audit_log;
-- Postgres: ALTER TABLE demo_log RENAME TO audit_log;
ALTER TABLE demo_log RENAME TO audit_log;

-- Truncate table (removes all rows, keeps structure)
TRUNCATE TABLE audit_log;

-- Verify table is empty (returns 0)
SELECT COUNT(*) FROM audit_log;

-- Drop table
DROP TABLE IF EXISTS audit_log;
