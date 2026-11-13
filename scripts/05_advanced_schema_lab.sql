-- ====================================================================
-- PostgreSQL Conversion: Advanced Bank Database Lab (Schema & Seed)
-- Module 5: 4-Table Enterprise Relational Model (bank_lab)
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- Connect / prepare database
-- CREATE DATABASE bank_lab;
-- \c bank_lab

-- Drop tables in reverse relational dependency order
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS branches CASCADE;

-- --------------------------------------------------------------------
-- 1. Table: branches
-- --------------------------------------------------------------------
CREATE TABLE branches (
    branch_id    SERIAL PRIMARY KEY,
    branch_name  VARCHAR(50) NOT NULL UNIQUE,
    city         VARCHAR(50) NOT NULL
);

-- --------------------------------------------------------------------
-- 2. Table: customers
-- --------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    SERIAL PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) UNIQUE,
    phone          VARCHAR(15),
    date_of_birth  DATE,
    city           VARCHAR(50),
    kyc_status     VARCHAR(10)  DEFAULT 'PENDING',
    created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 3. Table: accounts
-- --------------------------------------------------------------------
CREATE TABLE accounts (
    account_no    BIGSERIAL PRIMARY KEY,
    customer_id   INT           NOT NULL,
    branch_id     INT           NOT NULL,
    account_type  VARCHAR(20)   NOT NULL,
    balance       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status        VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    opened_on     DATE          NOT NULL,
    CONSTRAINT chk_acc_type CHECK (account_type IN ('SAVINGS','CURRENT','SALARY')),
    CONSTRAINT chk_balance  CHECK (balance >= 0),
    CONSTRAINT chk_status   CHECK (status IN ('ACTIVE','DORMANT','CLOSED')),
    CONSTRAINT fk_acc_cust   FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT fk_acc_branch FOREIGN KEY (branch_id)   REFERENCES branches (branch_id)
);

-- --------------------------------------------------------------------
-- 4. Table: transactions
-- --------------------------------------------------------------------
CREATE TABLE transactions (
    txn_id       BIGSERIAL PRIMARY KEY,
    account_no   BIGINT        NOT NULL,
    txn_type     VARCHAR(15)   NOT NULL,
    amount       DECIMAL(12,2) NOT NULL,
    txn_date     TIMESTAMP     NOT NULL,
    description  VARCHAR(100),
    CONSTRAINT chk_txn_type   CHECK (txn_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER_IN','TRANSFER_OUT')),
    CONSTRAINT chk_txn_amount CHECK (amount > 0),
    CONSTRAINT fk_txn_acc FOREIGN KEY (account_no) REFERENCES accounts (account_no)
);

-- --------------------------------------------------------------------
-- 5. Seed Data: Branches
-- --------------------------------------------------------------------
INSERT INTO branches (branch_name, city) VALUES
('Indiranagar',     'Bengaluru'),
('T Nagar',         'Chennai'),
('Andheri',         'Mumbai'),
('Madhapur',        'Hyderabad'),
('Connaught Place', 'Delhi'),
('Ernakulam',       'Kochi'); -- Built-in edge case: branch with no accounts

-- --------------------------------------------------------------------
-- 6. Seed Data: Customers
-- --------------------------------------------------------------------
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city, kyc_status) VALUES
('Arjun',  'Mehta',  'arjun.mehta@example.com',  '9876500001', '1990-04-12', 'Bengaluru', 'VERIFIED'),
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai',   'VERIFIED'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai',    'VERIFIED'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad', 'VERIFIED'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi',     'PENDING'),
('Meera',  'Iyer',   'meera.iyer@example.com',   NULL,         '1993-03-09', 'Bengaluru', 'PENDING'); -- Edge case: customer with no accounts and no phone

-- --------------------------------------------------------------------
-- 7. Seed Data: Accounts
-- --------------------------------------------------------------------
INSERT INTO accounts (account_no, customer_id, branch_id, account_type, balance, status, opened_on) VALUES
(1001, 1, 1, 'SAVINGS',  52000.00, 'ACTIVE',  '2022-03-15'),
(1002, 1, 1, 'CURRENT', 110000.00, 'ACTIVE',  '2023-01-10'),
(1003, 2, 2, 'SAVINGS',  78000.00, 'ACTIVE',  '2021-06-20'),
(1004, 3, 3, 'SALARY',   31000.00, 'ACTIVE',  '2024-02-01'),
(1005, 4, 4, 'SAVINGS',  15600.00, 'DORMANT', '2023-09-12'), -- Edge case: dormant account with 0 txns
(1006, 5, 5, 'CURRENT', 250000.00, 'ACTIVE',  '2020-12-05'),
(1007, 2, 2, 'SALARY',   46000.00, 'ACTIVE',  '2024-05-18');

-- Sync account sequence for auto-increment in PostgreSQL
SELECT setval('accounts_account_no_seq', (SELECT MAX(account_no) FROM accounts));

-- --------------------------------------------------------------------
-- 8. Seed Data: Transactions
-- --------------------------------------------------------------------
INSERT INTO transactions (account_no, txn_type, amount, txn_date, description) VALUES
(1001, 'DEPOSIT',      20000.00, '2025-01-05 10:15:00', 'Cash deposit'),
(1001, 'WITHDRAWAL',    5000.00, '2025-01-12 14:30:00', 'ATM withdrawal'),
(1002, 'DEPOSIT',      60000.00, '2025-01-15 09:00:00', 'Cheque deposit'),
(1002, 'TRANSFER_OUT', 10000.00, '2025-02-01 11:45:00', 'Transfer to 1001'),
(1001, 'TRANSFER_IN',  10000.00, '2025-02-01 11:45:00', 'Transfer from 1002'),
(1003, 'DEPOSIT',      30000.00, '2025-02-03 16:20:00', 'Cash deposit'),
(1004, 'DEPOSIT',      32000.00, '2025-02-05 10:00:00', 'Salary credit'),
(1004, 'WITHDRAWAL',    1000.00, '2025-02-10 18:05:00', 'ATM withdrawal'),
(1006, 'DEPOSIT',     100000.00, '2025-02-12 12:00:00', 'RTGS credit'),
(1006, 'WITHDRAWAL',   25000.00, '2025-02-20 15:30:00', 'Cheque payment'),
(1007, 'DEPOSIT',      46000.00, '2025-03-01 09:30:00', 'Salary credit'),
(1003, 'WITHDRAWAL',    2000.00, '2025-03-04 13:10:00', 'ATM withdrawal');

-- --------------------------------------------------------------------
-- 9. Row Count Verification
-- --------------------------------------------------------------------
SELECT 'branches'     AS tbl, COUNT(*) AS row_count FROM branches
UNION ALL 
SELECT 'customers',    COUNT(*) FROM customers
UNION ALL 
SELECT 'accounts',     COUNT(*) FROM accounts
UNION ALL 
SELECT 'transactions', COUNT(*) FROM transactions;
-- Expected row counts: branches: 6, customers: 6, accounts: 7, transactions: 12
