-- ====================================================================
-- MASTER POSTGRESQL ADVANCED LAB DATABASE SCRIPT (ALL-IN-ONE)
-- Module 2: Advanced Relational Data Modeling, Joins, Window Functions,
--           PL/pgSQL Functions, Views & Enterprise Stored Procedures
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. CLEANUP PREVIOUS OBJECTS (Reverse Relational Order)
-- --------------------------------------------------------------------
DROP VIEW IF EXISTS vw_dormant_accounts CASCADE;
DROP VIEW IF EXISTS vw_active_savings CASCADE;
DROP VIEW IF EXISTS vw_branch_summary CASCADE;
DROP VIEW IF EXISTS vw_customer_portfolio CASCADE;

DROP PROCEDURE IF EXISTS sp_withdraw(BIGINT, DECIMAL, VARCHAR) CASCADE;
DROP PROCEDURE IF EXISTS sp_transfer_funds(BIGINT, BIGINT, DECIMAL) CASCADE;
DROP PROCEDURE IF EXISTS sp_branch_stats(INT, INT, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS sp_customer_accounts(INT) CASCADE;
DROP FUNCTION IF EXISTS fn_interest(DECIMAL, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS fn_total_balance(INT) CASCADE;
DROP FUNCTION IF EXISTS fn_mask_email(VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS fn_age(DATE) CASCADE;
DROP FUNCTION IF EXISTS fn_customer_tier(DECIMAL) CASCADE;

DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS branches CASCADE;

-- --------------------------------------------------------------------
-- 2. DDL: 4-TABLE ENTERPRISE RELATIONAL SCHEMA
-- --------------------------------------------------------------------

-- Table 1: branches (3NF normalized branch master)
CREATE TABLE branches (
    branch_id    SERIAL PRIMARY KEY,
    branch_name  VARCHAR(50) NOT NULL UNIQUE,
    city         VARCHAR(50) NOT NULL
);

-- Table 2: customers (1NF atomic phone & normalized customer master)
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

-- Table 3: accounts (Core banking accounts with FK relationships)
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

-- Table 4: transactions (Double-entry / audit transaction ledger)
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
-- 3. DML: SEED DATA & SEQUENCE SYNCHRONIZATION
-- --------------------------------------------------------------------

-- Seed Branches
INSERT INTO branches (branch_name, city) VALUES
('Indiranagar',     'Bengaluru'),
('T Nagar',         'Chennai'),
('Andheri',         'Mumbai'),
('Madhapur',        'Hyderabad'),
('Connaught Place', 'Delhi'),
('Ernakulam',       'Kochi');

-- Seed Customers
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city, kyc_status) VALUES
('Arjun',  'Mehta',  'arjun.mehta@example.com',  '9876500001', '1990-04-12', 'Bengaluru', 'VERIFIED'),
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai',   'VERIFIED'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai',    'VERIFIED'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad', 'VERIFIED'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi',     'PENDING'),
('Meera',  'Iyer',   'meera.iyer@example.com',   NULL,         '1993-03-09', 'Bengaluru', 'PENDING');

-- Seed Accounts
INSERT INTO accounts (account_no, customer_id, branch_id, account_type, balance, status, opened_on) VALUES
(1001, 1, 1, 'SAVINGS',  52000.00, 'ACTIVE',  '2022-03-15'),
(1002, 1, 1, 'CURRENT', 110000.00, 'ACTIVE',  '2023-01-10'),
(1003, 2, 2, 'SAVINGS',  75000.00, 'ACTIVE',  '2021-06-20'),
(1004, 3, 3, 'SALARY',   31000.00, 'ACTIVE',  '2024-02-01'),
(1005, 4, 4, 'SAVINGS',  15000.00, 'ACTIVE',  '2023-09-12'),
(1006, 5, 5, 'CURRENT', 250000.00, 'ACTIVE',  '2020-12-05'),
(1007, 2, 2, 'SALARY',   46000.00, 'DORMANT', '2024-05-18');

-- Synchronize Account sequence
SELECT setval('accounts_account_no_seq', (SELECT MAX(account_no) FROM accounts));

-- Seed Transactions
INSERT INTO transactions (account_no, txn_type, amount, txn_date, description) VALUES
(1001, 'DEPOSIT',      50000.00, '2022-03-15 10:30:00', 'Opening balance'),
(1001, 'DEPOSIT',      10000.00, '2024-01-05 14:15:00', 'Salary credit'),
(1001, 'WITHDRAWAL',    8000.00, '2024-01-20 18:45:00', 'ATM withdrawal'),
(1002, 'DEPOSIT',     120000.00, '2023-01-10 11:00:00', 'Opening balance'),
(1002, 'TRANSFER_OUT', 10000.00, '2024-02-14 09:30:00', 'Transfer to 1001'),
(1003, 'DEPOSIT',      75000.00, '2021-06-20 12:00:00', 'Opening balance'),
(1004, 'DEPOSIT',      32000.00, '2024-02-01 10:00:00', 'Opening balance'),
(1004, 'WITHDRAWAL',    1000.00, '2024-02-10 16:20:00', 'ATM cash'),
(1005, 'DEPOSIT',      15000.00, '2023-09-12 15:30:00', 'Opening balance'),
(1006, 'DEPOSIT',     250000.00, '2020-12-05 10:00:00', 'Opening balance'),
(1007, 'DEPOSIT',      45000.00, '2024-05-18 11:30:00', 'Opening balance'),
(1007, 'TRANSFER_IN',   1000.00, '2024-05-20 14:00:00', 'Correction credit');

-- --------------------------------------------------------------------
-- 4. USER-DEFINED FUNCTIONS (PL/pgSQL)
-- --------------------------------------------------------------------

-- Function: Customer Tier
CREATE OR REPLACE FUNCTION fn_customer_tier(p_balance DECIMAL(14,2))
RETURNS VARCHAR(10)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN CASE
        WHEN p_balance >= 200000 THEN 'PLATINUM'
        WHEN p_balance >= 100000 THEN 'GOLD'
        WHEN p_balance >= 50000  THEN 'SILVER'
        ELSE 'STANDARD'
    END;
END;
$$;

-- Function: Customer Age
CREATE OR REPLACE FUNCTION fn_age(p_dob DATE)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_dob))::INT;
END;
$$;

-- Function: Mask Email
CREATE OR REPLACE FUNCTION fn_mask_email(p_email VARCHAR(100))
RETURNS VARCHAR(100)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_email IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN LEFT(p_email, 2) || '*****' || SUBSTRING(p_email FROM POSITION('@' IN p_email));
END;
$$;

-- Function: Total Customer Balance
CREATE OR REPLACE FUNCTION fn_total_balance(p_cust_id INT)
RETURNS DECIMAL(14,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total DECIMAL(14,2);
BEGIN
    SELECT COALESCE(SUM(balance), 0.00)
    INTO v_total
    FROM accounts
    WHERE customer_id = p_cust_id;
    
    RETURN v_total;
END;
$$;

-- Function: Interest Calculator (Assessment Task 7)
CREATE OR REPLACE FUNCTION fn_interest(p_balance DECIMAL(12,2), p_rate DECIMAL(5,2))
RETURNS DECIMAL(12,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN ROUND(p_balance * (p_rate / 100.00), 2);
END;
$$;

-- --------------------------------------------------------------------
-- 5. VIEWS
-- --------------------------------------------------------------------

-- View: Customer Portfolio
CREATE OR REPLACE VIEW vw_customer_portfolio AS
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.city                             AS customer_city,
       c.kyc_status,
       COUNT(a.account_no)                AS total_accounts,
       COALESCE(SUM(a.balance), 0.00)     AS portfolio_value
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.city, c.kyc_status;

-- View: Branch Summary
CREATE OR REPLACE VIEW vw_branch_summary AS
SELECT b.branch_id,
       b.branch_name,
       b.city,
       COUNT(a.account_no)                AS total_accounts,
       COALESCE(SUM(a.balance), 0.00)     AS total_deposits,
       COALESCE(AVG(a.balance), 0.00)     AS avg_account_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.city;

-- View: Updatable Active Savings with CHECK OPTION
CREATE OR REPLACE VIEW vw_active_savings AS
SELECT account_no, customer_id, branch_id, balance, opened_on, status
FROM accounts
WHERE account_type = 'SAVINGS' AND status = 'ACTIVE'
WITH CHECK OPTION;

-- View: Dormant Accounts (Assessment Task 9)
CREATE OR REPLACE VIEW vw_dormant_accounts AS
SELECT a.account_no,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.phone,
       b.branch_name,
       a.balance
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches b  ON b.branch_id = a.branch_id
WHERE a.status = 'DORMANT';

-- --------------------------------------------------------------------
-- 6. STORED PROCEDURES
-- --------------------------------------------------------------------

-- Procedure 1: Table Function for Customer Accounts
CREATE OR REPLACE FUNCTION sp_customer_accounts(p_customer_id INT)
RETURNS TABLE (
    account_no   BIGINT,
    account_type VARCHAR(20),
    balance      DECIMAL(12,2),
    status       VARCHAR(10),
    branch_name  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT a.account_no, a.account_type, a.balance, a.status, b.branch_name
    FROM accounts a
    JOIN branches b ON b.branch_id = a.branch_id
    WHERE a.customer_id = p_customer_id
    ORDER BY a.account_no;
END;
$$;

-- Procedure 2: Branch Statistics (INOUT parameters)
CREATE OR REPLACE PROCEDURE sp_branch_stats(
    p_branch_id INT,
    INOUT p_accounts INT DEFAULT NULL,
    INOUT p_total DECIMAL(14,2) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*), COALESCE(SUM(balance), 0)
    INTO p_accounts, p_total
    FROM accounts
    WHERE branch_id = p_branch_id;
END;
$$;

-- Procedure 3: Fund Transfer with Concurrency Locking & Validation
CREATE OR REPLACE PROCEDURE sp_transfer_funds(
    p_from_acc BIGINT,
    p_to_acc   BIGINT,
    p_amount   DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_bal    DECIMAL(12,2);
    v_from_status VARCHAR(10);
    v_to_status   VARCHAR(10);
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be positive. Provided: %', p_amount;
    END IF;

    IF p_from_acc = p_to_acc THEN
        RAISE EXCEPTION 'Source and destination accounts cannot be identical.';
    END IF;

    SELECT balance, status INTO v_from_bal, v_from_status
    FROM accounts
    WHERE account_no = p_from_acc
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % does not exist.', p_from_acc;
    END IF;

    IF v_from_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Source account % is not ACTIVE (status: %)', p_from_acc, v_from_status;
    END IF;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds in account %. Available: ₹%, Requested: ₹%',
            p_from_acc, v_from_bal, p_amount;
    END IF;

    SELECT status INTO v_to_status
    FROM accounts
    WHERE account_no = p_to_acc
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination account % does not exist.', p_to_acc;
    END IF;

    IF v_to_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Destination account % is not ACTIVE (status: %)', p_to_acc, v_to_status;
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_no = p_from_acc;
    UPDATE accounts SET balance = balance + p_amount WHERE account_no = p_to_acc;

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_from_acc, 'TRANSFER_OUT', p_amount, CURRENT_TIMESTAMP, 'Transfer to ' || p_to_acc::TEXT);

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_to_acc, 'TRANSFER_IN', p_amount, CURRENT_TIMESTAMP, 'Transfer from ' || p_from_acc::TEXT);

    COMMIT;
END;
$$;

-- Procedure 4: Withdrawal with Overdraft Protection (Assessment Task 10)
CREATE OR REPLACE PROCEDURE sp_withdraw(
    p_account_no BIGINT,
    p_amount     DECIMAL(12,2),
    p_desc       VARCHAR(100) DEFAULT 'ATM Withdrawal'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_status  VARCHAR(10);
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Withdrawal amount must be greater than zero. Provided: %', p_amount;
    END IF;

    SELECT balance, status INTO v_balance, v_status
    FROM accounts
    WHERE account_no = p_account_no
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % not found.', p_account_no;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Account % is not ACTIVE. Current status: %', p_account_no, v_status;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance in account %. Current: ₹%, Requested: ₹%', 
            p_account_no, v_balance, p_amount;
    END IF;

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_no = p_account_no;

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_account_no, 'WITHDRAWAL', p_amount, CURRENT_TIMESTAMP, p_desc);

    COMMIT;
END;
$$;

-- --------------------------------------------------------------------
-- 7. DEMONSTRATION & VERIFICATION QUERIES
-- --------------------------------------------------------------------

-- Verify Customer Portfolio View with UDF Tiering
SELECT customer_id,
       customer_name,
       customer_city,
       total_accounts,
       portfolio_value,
       fn_customer_tier(portfolio_value) AS tier
FROM vw_customer_portfolio
ORDER BY portfolio_value DESC;

-- Verify Branch Statistics
SELECT * FROM vw_branch_summary;

-- Verify Window Function Ranking
SELECT account_type,
       account_no,
       balance,
       DENSE_RANK() OVER (PARTITION BY account_type ORDER BY balance DESC) AS rank_in_type
FROM accounts;
