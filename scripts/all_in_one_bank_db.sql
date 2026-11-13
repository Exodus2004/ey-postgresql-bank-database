-- ====================================================================
-- MASTER POSTGRESQL BANK DATABASE SCRIPT (ALL-IN-ONE)
-- Complete DDL, DML & TCL Workflow converted from MySQL for EY Training
-- ====================================================================

-- 1. CLEANUP PREVIOUS RUNS
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS demo_log CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;

-- 2. DDL: CREATE TABLES
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

-- 3. DDL: ALTER TABLE
ALTER TABLE customers ADD COLUMN kyc_status VARCHAR(10) DEFAULT 'PENDING';
ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);
ALTER TABLE accounts ADD CONSTRAINT chk_status CHECK (status IN ('ACTIVE','DORMANT','CLOSED'));
CREATE INDEX idx_customers_city ON customers (city);

-- 4. DML: INSERT DATA
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city) VALUES
('Arjun',  'Mehta',  'arjun.mehta@example.com',  '9876500001', '1990-04-12', 'Bengaluru'),
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi');

INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on) VALUES
(1001, 1, 'SAVINGS',  50000.00, 'Indiranagar',     '2022-03-15'),
(1002, 1, 'CURRENT', 120000.00, 'Indiranagar',     '2023-01-10'),
(1003, 2, 'SAVINGS',  75000.00, 'T Nagar',         '2021-06-20'),
(1004, 3, 'SALARY',   32000.00, 'Andheri',         '2024-02-01'),
(1005, 4, 'SAVINGS',  15000.00, 'Madhapur',        '2023-09-12'),
(1006, 5, 'CURRENT', 250000.00, 'Connaught Place', '2020-12-05'),
(1007, 2, 'SALARY',   45000.00, 'T Nagar',         '2024-05-18');

SELECT setval('accounts_account_no_seq', (SELECT MAX(account_no) FROM accounts));

-- 5. DML: UPDATE & INTEREST CALCULATION
UPDATE customers SET city = 'Pune' WHERE customer_id = 3;
UPDATE customers SET phone = '9988776655', email = 'priya.n@example.com' WHERE customer_id = 2;
UPDATE customers SET kyc_status = 'VERIFIED' WHERE customer_id IN (1, 2, 3, 4);
UPDATE accounts SET balance = balance * 1.04 WHERE account_type = 'SAVINGS';

-- 6. TCL: FUND TRANSFER TRANSACTION (₹10,000 from 1002 to 1001)
BEGIN;
UPDATE accounts SET balance = balance - 10000 WHERE account_no = 1002;
UPDATE accounts SET balance = balance + 10000 WHERE account_no = 1001;
COMMIT;

-- 7. TCL: SAVEPOINT DEMO
BEGIN;
UPDATE accounts SET balance = balance - 1000 WHERE account_no = 1004;
SAVEPOINT after_debit;
UPDATE accounts SET balance = balance + 1000 WHERE account_no = 1005; -- mistake
ROLLBACK TO SAVEPOINT after_debit;                                   -- undo mistake
UPDATE accounts SET balance = balance + 1000 WHERE account_no = 1007; -- correct
COMMIT;

-- 8. SUMMARY VERIFICATION QUERY
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.city,
       c.kyc_status,
       a.account_no,
       a.account_type,
       a.balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_no;
