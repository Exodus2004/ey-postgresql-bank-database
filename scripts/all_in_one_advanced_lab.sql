-- ====================================================================
-- MASTER POSTGRESQL ADVANCED LAB DATABASE SCRIPT (ALL-IN-ONE)
-- Complete Module: Relational Modeling, DDL, DML, Joins, Window Functions,
--                  PL/pgSQL Functions, Views, Procedures & Normalization Lab
-- 100% Comprehensive: Contains ALL code from scripts 05 through 10
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- ====================================================================
-- SECTION 1: CLEANUP PREVIOUS OBJECTS (Reverse Relational Order)
-- ====================================================================
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

DROP TABLE IF EXISTS n_accounts CASCADE;
DROP TABLE IF EXISTS n_customer_phones CASCADE;
DROP TABLE IF EXISTS n_customers CASCADE;
DROP TABLE IF EXISTS n_branches CASCADE;
DROP TABLE IF EXISTS bank_flat CASCADE;

-- ====================================================================
-- SECTION 2: DDL — 4-TABLE ENTERPRISE RELATIONAL SCHEMA
-- ====================================================================

-- 1. branches (3NF normalized branch master)
CREATE TABLE branches (
    branch_id    SERIAL PRIMARY KEY,
    branch_name  VARCHAR(50) NOT NULL UNIQUE,
    city         VARCHAR(50) NOT NULL
);

-- 2. customers (1NF atomic phone & normalized customer master)
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

-- 3. accounts (Core banking accounts with FK relationships)
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

-- 4. transactions (Double-entry / audit transaction ledger)
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

-- ====================================================================
-- SECTION 3: DML — SEED DATA & SEQUENCE SYNCHRONIZATION
-- ====================================================================

-- Seed Branches
INSERT INTO branches (branch_name, city) VALUES
('Indiranagar',     'Bengaluru'),
('T Nagar',         'Chennai'),
('Andheri',         'Mumbai'),
('Madhapur',        'Hyderabad'),
('Connaught Place', 'Delhi'),
('Ernakulam',       'Kochi'); -- Branch with no accounts (edge case)

-- Seed Customers
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city, kyc_status) VALUES
('Arjun',  'Mehta',  'arjun.mehta@example.com',  '9876500001', '1990-04-12', 'Bengaluru', 'VERIFIED'),
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai',   'VERIFIED'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai',    'VERIFIED'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad', 'VERIFIED'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi',     'PENDING'),
('Meera',  'Iyer',   'meera.iyer@example.com',   NULL,         '1993-03-09', 'Bengaluru', 'PENDING'); -- No accounts & no phone (edge case)

-- Seed Accounts
INSERT INTO accounts (account_no, customer_id, branch_id, account_type, balance, status, opened_on) VALUES
(1001, 1, 1, 'SAVINGS',  52000.00, 'ACTIVE',  '2022-03-15'),
(1002, 1, 1, 'CURRENT', 110000.00, 'ACTIVE',  '2023-01-10'),
(1003, 2, 2, 'SAVINGS',  75000.00, 'ACTIVE',  '2021-06-20'),
(1004, 3, 3, 'SALARY',   31000.00, 'ACTIVE',  '2024-02-01'),
(1005, 4, 4, 'SAVINGS',  15000.00, 'ACTIVE',  '2023-09-12'),
(1006, 5, 5, 'CURRENT', 250000.00, 'ACTIVE',  '2020-12-05'),
(1007, 2, 2, 'SALARY',   46000.00, 'DORMANT', '2024-05-18');

-- Sync account sequence
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

-- Sync transaction sequence
SELECT setval('transactions_txn_id_seq', (SELECT MAX(txn_id) FROM transactions));

-- Row count verification
SELECT 'branches' AS tbl, COUNT(*) AS row_count FROM branches
UNION ALL SELECT 'customers',    COUNT(*) FROM customers
UNION ALL SELECT 'accounts',     COUNT(*) FROM accounts
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions;

-- ====================================================================
-- SECTION 4: USER-DEFINED FUNCTIONS (PL/pgSQL)
-- ====================================================================

-- Function 1: Customer tier based on balance
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

-- Function 2: Calculate age from Date of Birth
CREATE OR REPLACE FUNCTION fn_age(p_dob DATE)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_dob))::INT;
END;
$$;

-- Function 3: Mask email for privacy display
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

-- Function 4: Customer Total Balance across all accounts
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

-- Function 5: Yearly Interest calculation (Assessment Task 7)
CREATE OR REPLACE FUNCTION fn_interest(p_balance DECIMAL(12,2), p_rate DECIMAL(5,2))
RETURNS DECIMAL(12,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN ROUND(p_balance * (p_rate / 100.00), 2);
END;
$$;

-- ====================================================================
-- SECTION 5: VIEWS (With & Without CHECK OPTION)
-- ====================================================================

-- View 1: Customer Portfolio
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

-- View 2: Branch Summary
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

-- View 3: Updatable Active Savings with WITH CHECK OPTION
CREATE OR REPLACE VIEW vw_active_savings AS
SELECT account_no, customer_id, branch_id, balance, opened_on, status
FROM accounts
WHERE account_type = 'SAVINGS' AND status = 'ACTIVE'
WITH CHECK OPTION;

-- View 4: Dormant Accounts (Assessment Task 9)
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

-- ====================================================================
-- SECTION 6: STORED PROCEDURES & PL/pgSQL ROUTINES
-- ====================================================================

-- Procedure 1: Table Function returning customer accounts
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

-- Procedure 3: Full Enterprise Fund Transfer with Row Locking (FOR UPDATE)
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

    -- Concurrency row lock on source account
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

    -- Concurrency row lock on destination account
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

    -- Execute transfer
    UPDATE accounts SET balance = balance - p_amount WHERE account_no = p_from_acc;
    UPDATE accounts SET balance = balance + p_amount WHERE account_no = p_to_acc;

    -- Double-entry audit ledger entries
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

-- ====================================================================
-- SECTION 7: ADVANCED DQL QUERIES, SUBQUERIES, CTES & WINDOW FUNCTIONS
-- ====================================================================

-- 1. Query Execution Demonstration & Filter
SELECT customer_id,
       c.first_name || ' ' || c.last_name AS full_name,
       city
FROM customers c
WHERE city IN ('Bengaluru', 'Chennai')
ORDER BY full_name;

-- 2. Case-insensitive Search, Range & NULL checks
SELECT * FROM customers WHERE first_name ILIKE 'P%';
SELECT * FROM accounts WHERE balance BETWEEN 30000 AND 80000 ORDER BY balance DESC;
SELECT * FROM customers WHERE phone IS NULL;

-- 3. Pagination (LIMIT & OFFSET)
SELECT account_no, balance FROM accounts ORDER BY balance DESC LIMIT 3 OFFSET 2;

-- 4. Scalar Subquery
SELECT account_no, customer_id, balance
FROM accounts
WHERE balance > (SELECT AVG(balance) FROM accounts);

-- 5. Multi-Row Subquery
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM accounts WHERE balance > 100000
);

-- 6. Correlated Subquery
SELECT a.account_no, a.account_type, a.balance
FROM accounts a
WHERE a.balance > (
    SELECT AVG(a2.balance)
    FROM accounts a2
    WHERE a2.account_type = a.account_type
);

-- 7. Common Table Expression (CTE)
WITH customer_totals AS (
    SELECT customer_id, SUM(balance) AS total_balance, COUNT(*) AS num_accounts
    FROM accounts
    GROUP BY customer_id
)
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       ct.total_balance,
       ct.num_accounts
FROM customers c
JOIN customer_totals ct ON ct.customer_id = c.customer_id
WHERE ct.total_balance > 60000;

-- 8. Window Functions: ROW_NUMBER, RANK, DENSE_RANK
SELECT a.account_no,
       b.branch_name,
       a.balance,
       ROW_NUMBER() OVER (PARTITION BY a.branch_id ORDER BY a.balance DESC) AS row_num,
       RANK()       OVER (PARTITION BY a.branch_id ORDER BY a.balance DESC) AS balance_rank,
       DENSE_RANK() OVER (PARTITION BY a.branch_id ORDER BY a.balance DESC) AS dense_rank
FROM accounts a
JOIN branches b ON b.branch_id = a.branch_id;

-- 9. Running Balance Window Function
SELECT txn_id,
       account_no,
       txn_date,
       amount,
       txn_type,
       SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount ELSE -amount END)
           OVER (PARTITION BY account_no ORDER BY txn_date) AS running_balance
FROM transactions;

-- ====================================================================
-- SECTION 8: ALL JOIN STRATEGIES & EXECUTION PLANS
-- ====================================================================

-- 1. INNER JOIN
SELECT c.first_name, a.account_no, a.balance
FROM customers c
INNER JOIN accounts a ON a.customer_id = c.customer_id;

-- 2. LEFT JOIN
SELECT c.customer_id, c.first_name, a.account_no
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id;

-- 3. RIGHT JOIN
SELECT a.account_no, b.branch_name
FROM accounts a
RIGHT JOIN branches b ON b.branch_id = a.branch_id;

-- 4. Native PostgreSQL FULL OUTER JOIN
SELECT c.customer_id, c.first_name, a.account_no, a.balance
FROM customers c
FULL OUTER JOIN accounts a ON a.customer_id = c.customer_id;

-- 5. CROSS JOIN (Cartesian Product)
SELECT b.branch_name, t.type_name
FROM branches b
CROSS JOIN (VALUES ('SAVINGS'), ('CURRENT'), ('SALARY')) AS t(type_name);

-- 6. SELF JOIN (Customer pairs in same city)
SELECT c1.first_name || ' ' || c1.last_name AS customer_1,
       c2.first_name || ' ' || c2.last_name AS customer_2,
       c1.city
FROM customers c1
JOIN customers c2 ON c1.city = c2.city AND c1.customer_id < c2.customer_id;

-- 7. SEMI-JOIN via EXISTS
SELECT b.branch_id, b.branch_name
FROM branches b
WHERE EXISTS (
    SELECT 1 FROM accounts a WHERE a.branch_id = b.branch_id
);

-- 8. ANTI-JOIN via NOT EXISTS
SELECT b.branch_id, b.branch_name, b.city
FROM branches b
WHERE NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.branch_id = b.branch_id
);

-- 9. Execution Plan Analysis
EXPLAIN ANALYZE
SELECT a.account_no, c.first_name, b.branch_name
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id;

-- ====================================================================
-- SECTION 9: BUILT-IN FUNCTIONS DEMONSTRATION
-- ====================================================================

-- String & Formatting
SELECT customer_id,
       UPPER(last_name) AS surname_upper,
       LEFT(first_name, 1) || '. ' || last_name AS short_name,
       LENGTH(email) AS email_length,
       SUBSTRING(email FROM POSITION('@' IN email) + 1) AS email_domain
FROM customers;

-- Numeric & Interest
SELECT account_no, balance,
       ROUND(balance * 0.035, 2) AS yearly_interest,
       FLOOR(balance / 10000)    AS ten_thousand_blocks
FROM accounts;

-- Date & Age Arithmetic
SELECT customer_id, date_of_birth,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth))::INT AS age,
       TO_CHAR(date_of_birth, 'DD Mon YYYY') AS dob_formatted,
       TRIM(TO_CHAR(date_of_birth, 'Day'))   AS born_on_day
FROM customers;

-- Date Intervals
SELECT txn_id, txn_date,
       txn_date + INTERVAL '30 days' AS due_in_30_days,
       (DATE '2025-03-31' - txn_date::DATE) AS days_to_quarter_end
FROM transactions;

-- STRING_AGG
SELECT c.customer_id, c.first_name,
       STRING_AGG(a.account_no::TEXT, ', ' ORDER BY a.account_no) AS account_numbers
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name;

-- ====================================================================
-- SECTION 10: ADVANCED ASSESSMENT LAB (ALL 10 TASKS SOLVED)
-- ====================================================================

-- Task 2: Customer total balance, including 0 for no account
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       COALESCE(SUM(a.balance), 0.00)     AS total_balance
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance DESC;

-- Task 3: Top account by balance within each account type (Window function)
SELECT account_type, account_no, balance
FROM (
    SELECT account_type,
           account_no,
           balance,
           ROW_NUMBER() OVER (PARTITION BY account_type ORDER BY balance DESC) AS rn
    FROM accounts
) ranked
WHERE rn = 1;

-- Task 4: Accounts whose average transaction amount is above ₹20,000
SELECT t.account_no,
       ROUND(AVG(t.amount), 2) AS avg_transaction_amount,
       COUNT(*)                AS transaction_count
FROM transactions t
GROUP BY t.account_no
HAVING AVG(t.amount) > 20000;

-- Task 5: Branches that have no active accounts (Anti-join)
SELECT b.branch_id, b.branch_name, b.city
FROM branches b
WHERE NOT EXISTS (
    SELECT 1 
    FROM accounts a 
    WHERE a.branch_id = b.branch_id AND a.status = 'ACTIVE'
);

-- Task 6: Branch distinct customers and total deposits
SELECT b.branch_name,
       COUNT(DISTINCT a.customer_id) AS total_customers,
       COALESCE(SUM(a.balance), 0)   AS total_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY total_balance DESC;

-- Task 7: fn_interest function demo on savings accounts
SELECT account_no,
       balance,
       fn_interest(balance, 4.00) AS interest_earned_4pct
FROM accounts
WHERE account_type = 'SAVINGS';

-- Task 8: Customers with NO transactions in 2024
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.city
FROM customers c
WHERE c.customer_id NOT IN (
    SELECT DISTINCT a.customer_id
    FROM accounts a
    JOIN transactions t ON t.account_no = a.account_no
    WHERE EXTRACT(YEAR FROM t.txn_date) = 2024
);

-- Task 9: Query the Dormant Accounts View
SELECT * FROM vw_dormant_accounts;

-- Task 10: Test sp_withdraw stored procedure
CALL sp_withdraw(1001, 2000.00, 'ATM cash withdrawal');

-- ====================================================================
-- SECTION 11: COMPLETE NORMALIZATION LAB (1NF -> 2NF -> 3NF)
-- ====================================================================

-- 1. Create and populate unnormalized flat table
CREATE TABLE bank_flat (
    row_id          INT PRIMARY KEY,
    customer_name   VARCHAR(60),
    customer_phones VARCHAR(40),
    customer_city   VARCHAR(40),
    account_no      BIGINT,
    account_type    VARCHAR(20),
    balance         DECIMAL(12,2),
    branch_name     VARCHAR(50),
    branch_city     VARCHAR(40),
    branch_manager  VARCHAR(50)
);

INSERT INTO bank_flat VALUES
(1, 'Arjun Mehta',  '9876500001, 9876500011', 'Bengaluru', 1001, 'SAVINGS', 52000.00,  'Indiranagar', 'Bengaluru', 'R. Kulkarni'),
(2, 'Arjun Mehta',  '9876500001, 9876500011', 'Bengaluru', 1002, 'CURRENT', 110000.00, 'Indiranagar', 'Bengaluru', 'R. Kulkarni'),
(3, 'Priya Nair',   '9876500002',             'Chennai',   1003, 'SAVINGS', 78000.00,  'T Nagar',     'Chennai',   'S. Iyer'),
(4, 'Priya Nair',   '9876500002',             'Chennai',   1007, 'SALARY',  46000.00,  'T Nagar',     'Chennai',   'S. Iyer'),
(5, 'Rahul Sharma', '9876500003',             'Mumbai',    1004, 'SALARY',  31000.00,  'Andheri',     'Mumbai',    'M. Desai'),
(6, 'Sneha Reddy',  '9876500004',             'Hyderabad', 1005, 'SAVINGS', 15600.00,  'Madhapur',    'Hyderabad', 'K. Rao');

-- 2. Build 3NF Schema
CREATE TABLE n_branches (
    branch_name    VARCHAR(50) PRIMARY KEY,
    branch_city    VARCHAR(40) NOT NULL,
    branch_manager VARCHAR(50) NOT NULL
);

CREATE TABLE n_customers (
    customer_id   SERIAL PRIMARY KEY,
    customer_name VARCHAR(60) NOT NULL UNIQUE,
    customer_city VARCHAR(40)
);

CREATE TABLE n_customer_phones (
    customer_id INT NOT NULL,
    phone       VARCHAR(15) NOT NULL,
    PRIMARY KEY (customer_id, phone),
    CONSTRAINT fk_phone_cust FOREIGN KEY (customer_id) 
        REFERENCES n_customers (customer_id) ON DELETE CASCADE
);

CREATE TABLE n_accounts (
    account_no   BIGINT PRIMARY KEY,
    customer_id  INT NOT NULL,
    branch_name  VARCHAR(50) NOT NULL,
    account_type VARCHAR(20),
    balance      DECIMAL(12,2),
    CONSTRAINT fk_acc_cust FOREIGN KEY (customer_id) REFERENCES n_customers (customer_id),
    CONSTRAINT fk_acc_branch FOREIGN KEY (branch_name) REFERENCES n_branches (branch_name)
);

-- 3. Migrate data into 3NF
INSERT INTO n_branches (branch_name, branch_city, branch_manager)
SELECT DISTINCT branch_name, branch_city, branch_manager FROM bank_flat;

INSERT INTO n_customers (customer_name, customer_city)
SELECT DISTINCT customer_name, customer_city FROM bank_flat;

INSERT INTO n_customer_phones (customer_id, phone)
SELECT customer_id, '9876500001' FROM n_customers WHERE customer_name = 'Arjun Mehta'
UNION ALL SELECT customer_id, '9876500011' FROM n_customers WHERE customer_name = 'Arjun Mehta'
UNION ALL SELECT customer_id, '9876500002' FROM n_customers WHERE customer_name = 'Priya Nair'
UNION ALL SELECT customer_id, '9876500003' FROM n_customers WHERE customer_name = 'Rahul Sharma'
UNION ALL SELECT customer_id, '9876500004' FROM n_customers WHERE customer_name = 'Sneha Reddy';

INSERT INTO n_accounts (account_no, customer_id, branch_name, account_type, balance)
SELECT f.account_no, c.customer_id, f.branch_name, f.account_type, f.balance
FROM bank_flat f JOIN n_customers c ON c.customer_name = f.customer_name;

-- 4. Reconstruct original view via 3NF Joins
SELECT c.customer_name,
       a.account_no,
       a.account_type,
       a.balance,
       b.branch_name,
       b.branch_city,
       b.branch_manager
FROM n_accounts a
JOIN n_customers c ON c.customer_id = a.customer_id
JOIN n_branches  b ON b.branch_name = a.branch_name
ORDER BY a.account_no;

-- ====================================================================
-- FINAL VERIFICATION
-- ====================================================================
SELECT 'ALL ADVANCED BANK LAB MODULES LOADED SUCCESSFULLY!' AS status;
