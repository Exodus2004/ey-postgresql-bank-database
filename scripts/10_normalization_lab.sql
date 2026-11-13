-- ====================================================================
-- PostgreSQL Conversion: Database Normalization Hands-on Lab
-- Module 10: From Unnormalized Flat Sheet (bank_flat) to 3NF (Section 3)
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. Step 1: The Unnormalized Flat Table (bank_flat)
-- --------------------------------------------------------------------
DROP TABLE IF EXISTS bank_flat CASCADE;

CREATE TABLE bank_flat (
    row_id          INT PRIMARY KEY,
    customer_name   VARCHAR(60),
    customer_phones VARCHAR(40),  -- Violates 1NF (multi-valued attribute)
    customer_city   VARCHAR(40),  -- Violates 2NF (depends only on customer_name, not account_no)
    account_no      BIGINT,
    account_type    VARCHAR(20),
    balance         DECIMAL(12,2),
    branch_name     VARCHAR(50),  -- Violates 3NF (transitive dependency)
    branch_city     VARCHAR(40),  -- Violates 3NF (depends on branch_name)
    branch_manager  VARCHAR(50)   -- Violates 3NF (depends on branch_name)
);

INSERT INTO bank_flat VALUES
(1, 'Arjun Mehta',  '9876500001, 9876500011', 'Bengaluru', 1001, 'SAVINGS', 52000.00,  'Indiranagar', 'Bengaluru', 'R. Kulkarni'),
(2, 'Arjun Mehta',  '9876500001, 9876500011', 'Bengaluru', 1002, 'CURRENT', 110000.00, 'Indiranagar', 'Bengaluru', 'R. Kulkarni'),
(3, 'Priya Nair',   '9876500002',             'Chennai',   1003, 'SAVINGS', 78000.00,  'T Nagar',     'Chennai',   'S. Iyer'),
(4, 'Priya Nair',   '9876500002',             'Chennai',   1007, 'SALARY',  46000.00,  'T Nagar',     'Chennai',   'S. Iyer'),
(5, 'Rahul Sharma', '9876500003',             'Mumbai',    1004, 'SALARY',  31000.00,  'Andheri',     'Mumbai',    'M. Desai'),
(6, 'Sneha Reddy',  '9876500004',             'Hyderabad', 1005, 'SAVINGS', 15600.00,  'Madhapur',    'Hyderabad', 'K. Rao');

-- --------------------------------------------------------------------
-- 2. Demonstration of Anomalies in the Flat Table
-- --------------------------------------------------------------------
BEGIN;

-- A. Update Anomaly:
-- The Indiranagar branch manager changes to 'A. Pillai'.
-- If we only update row 1, the branch data becomes conflicting and inconsistent!
UPDATE bank_flat SET branch_manager = 'A. Pillai' WHERE row_id = 1;

-- Notice that Indiranagar now has TWO conflicting branch managers:
SELECT DISTINCT branch_name, branch_manager 
FROM bank_flat 
WHERE branch_name = 'Indiranagar';

-- B. Insert Anomaly:
-- We cannot open a new branch (e.g., 'Ernakulam' in Kochi) without inventing a
-- fake customer or dummy account, because account_no is mandatory in the business logic!

-- C. Delete Anomaly:
-- If Rahul Sharma closes his only account (row 5) and we delete the row:
DELETE FROM bank_flat WHERE row_id = 5;

-- Check: The entire record of 'Andheri' branch is completely erased from our database!
SELECT * FROM bank_flat WHERE branch_name = 'Andheri';

-- Roll back to keep the flat table intact for normalization migration
ROLLBACK;


-- --------------------------------------------------------------------
-- 3. Step-by-Step Normalization (1NF -> 2NF -> 3NF)
-- --------------------------------------------------------------------
-- 1NF Rule: Atomic values per cell (split customer_phones into separate rows)
-- 2NF Rule: No partial dependencies on composite candidate key (customer details moved)
-- 3NF Rule: No transitive dependencies between non-key columns (branch details moved)

DROP TABLE IF EXISTS n_accounts CASCADE;
DROP TABLE IF EXISTS n_customer_phones CASCADE;
DROP TABLE IF EXISTS n_customers CASCADE;
DROP TABLE IF EXISTS n_branches CASCADE;

-- 3NF Table 1: Branches (Stores branch facts exactly once)
CREATE TABLE n_branches (
    branch_name    VARCHAR(50) PRIMARY KEY,
    branch_city    VARCHAR(40) NOT NULL,
    branch_manager VARCHAR(50) NOT NULL
);

-- 3NF Table 2: Customers (Stores customer profile once)
CREATE TABLE n_customers (
    customer_id   SERIAL PRIMARY KEY,
    customer_name VARCHAR(60) NOT NULL UNIQUE,
    customer_city VARCHAR(40)
);

-- 1NF Table 3: Customer Phones (Atomic phone storage)
CREATE TABLE n_customer_phones (
    customer_id INT NOT NULL,
    phone       VARCHAR(15) NOT NULL,
    PRIMARY KEY (customer_id, phone),
    CONSTRAINT fk_phone_cust FOREIGN KEY (customer_id) 
        REFERENCES n_customers (customer_id) ON DELETE CASCADE
);

-- 3NF Table 4: Accounts (Relates customer and branch via Foreign Keys)
CREATE TABLE n_accounts (
    account_no   BIGINT PRIMARY KEY,
    customer_id  INT NOT NULL,
    branch_name  VARCHAR(50) NOT NULL,
    account_type VARCHAR(20),
    balance      DECIMAL(12,2),
    CONSTRAINT fk_acc_cust FOREIGN KEY (customer_id) 
        REFERENCES n_customers (customer_id),
    CONSTRAINT fk_acc_branch FOREIGN KEY (branch_name) 
        REFERENCES n_branches (branch_name)
);


-- --------------------------------------------------------------------
-- 4. Data Migration: Extracting facts into 3NF schema
-- --------------------------------------------------------------------

-- Populate branches (each branch stored exactly once)
INSERT INTO n_branches (branch_name, branch_city, branch_manager)
SELECT DISTINCT branch_name, branch_city, branch_manager 
FROM bank_flat;

-- Populate customers (each customer stored once)
INSERT INTO n_customers (customer_name, customer_city)
SELECT DISTINCT customer_name, customer_city 
FROM bank_flat;

-- Populate customer phones (atomic values in 1NF)
INSERT INTO n_customer_phones (customer_id, phone)
SELECT customer_id, '9876500001' FROM n_customers WHERE customer_name = 'Arjun Mehta'
UNION ALL
SELECT customer_id, '9876500011' FROM n_customers WHERE customer_name = 'Arjun Mehta'
UNION ALL
SELECT customer_id, '9876500002' FROM n_customers WHERE customer_name = 'Priya Nair'
UNION ALL
SELECT customer_id, '9876500003' FROM n_customers WHERE customer_name = 'Rahul Sharma'
UNION ALL
SELECT customer_id, '9876500004' FROM n_customers WHERE customer_name = 'Sneha Reddy';

-- Populate accounts with foreign keys referencing normalized parents
INSERT INTO n_accounts (account_no, customer_id, branch_name, account_type, balance)
SELECT f.account_no, c.customer_id, f.branch_name, f.account_type, f.balance
FROM bank_flat f
JOIN n_customers c ON c.customer_name = f.customer_name;


-- --------------------------------------------------------------------
-- 5. Verification: Anomalies are Completely Resolved
-- --------------------------------------------------------------------

-- A. Update Anomaly Solved: Changing manager in one row updates it system-wide
UPDATE n_branches SET branch_manager = 'A. Pillai' WHERE branch_name = 'Indiranagar';

-- B. Insert Anomaly Solved: New branch can be opened without any customer or account
INSERT INTO n_branches VALUES ('Ernakulam', 'Kochi', 'T. Menon');

-- C. Delete Anomaly Solved: Deleting an account leaves the branch record intact
DELETE FROM n_accounts WHERE account_no = 1004;
SELECT * FROM n_branches WHERE branch_name = 'Andheri'; -- Branch remains safe!

-- D. Reconstructing the original flat dataset seamlessly via Relational Joins
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


-- --------------------------------------------------------------------
-- 6. Cleanup Scratch Tables (Optional)
-- --------------------------------------------------------------------
-- DROP TABLE IF EXISTS n_accounts CASCADE;
-- DROP TABLE IF EXISTS n_customer_phones CASCADE;
-- DROP TABLE IF EXISTS n_customers CASCADE;
-- DROP TABLE IF EXISTS n_branches CASCADE;
-- DROP TABLE IF EXISTS bank_flat CASCADE;
