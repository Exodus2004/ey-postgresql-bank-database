-- ====================================================================
-- PostgreSQL Conversion: Bank Database Training (Assessment)
-- Module 4: Hands-on Lab Tasks & Assessment Solutions
-- Converted from MySQL 8.0 for EY Training Lab
-- ====================================================================

-- --------------------------------------------------------------------
-- Task 1 (DDL): Add a column ifsc_code VARCHAR(11) to accounts, then drop it
-- --------------------------------------------------------------------
ALTER TABLE accounts ADD COLUMN ifsc_code VARCHAR(11);

-- Verify addition
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'accounts' AND column_name = 'ifsc_code';

-- Drop the column
ALTER TABLE accounts DROP COLUMN ifsc_code;


-- --------------------------------------------------------------------
-- Task 2 (DML): Add a customer, Meera Iyer from Kochi, and give her a
-- CURRENT account (no. 1008) with ₹5,000 opened today
--
-- MySQL used:    LAST_INSERT_ID() and CURDATE()
-- PostgreSQL:    CURRENT_DATE and RETURNING (or currval)
-- --------------------------------------------------------------------

-- Method A (Idiomatic PostgreSQL with RETURNING & CTE):
WITH new_cust AS (
    INSERT INTO customers (first_name, last_name, email, city)
    VALUES ('Meera', 'Iyer', 'meera.iyer@example.com', 'Kochi')
    RETURNING customer_id
)
INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on)
SELECT 1008, customer_id, 'CURRENT', 5000.00, 'Ernakulam', CURRENT_DATE
FROM new_cust;

-- Method B (Using currval & sequence):
-- INSERT INTO customers (first_name, last_name, email, city)
-- VALUES ('Meera', 'Iyer', 'meera.iyer2@example.com', 'Kochi');
-- INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on)
-- VALUES (1009, currval(pg_get_serial_sequence('customers', 'customer_id')), 'CURRENT', 5000.00, 'Ernakulam', CURRENT_DATE);


-- --------------------------------------------------------------------
-- Task 3 (DML): List customers living in Hyderabad or Mumbai
-- --------------------------------------------------------------------
SELECT customer_id, first_name, last_name, city, email 
FROM customers 
WHERE city IN ('Hyderabad', 'Mumbai');


-- --------------------------------------------------------------------
-- Task 4 (DML): Show each customer’s full name and the total balance 
-- across all their accounts, highest first
-- --------------------------------------------------------------------
SELECT c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       -- Or standard ANSI SQL concatenation: (c.first_name || ' ' || c.last_name)
       SUM(a.balance) AS total_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance DESC;


-- --------------------------------------------------------------------
-- Task 5 (DML): Mark account 1005 as DORMANT
-- --------------------------------------------------------------------
UPDATE accounts 
SET status = 'DORMANT' 
WHERE account_no = 1005;

-- Verify change
SELECT account_no, customer_id, status 
FROM accounts 
WHERE account_no = 1005;


-- --------------------------------------------------------------------
-- Task 6 (TCL): Transfer ₹5,000 from account 1006 to 1003 and make it permanent
-- --------------------------------------------------------------------
BEGIN;

UPDATE accounts 
SET balance = balance - 5000 
WHERE account_no = 1006;

UPDATE accounts 
SET balance = balance + 5000 
WHERE account_no = 1003;

COMMIT;

-- Verify updated balances
SELECT account_no, balance 
FROM accounts 
WHERE account_no IN (1003, 1006);


-- --------------------------------------------------------------------
-- Task 7 (TCL): Attempt to transfer ₹300,000 from account 1006 to 1003 
-- and undo it when the debit fails
-- --------------------------------------------------------------------
BEGIN;

-- Fails because account 1006 does not hold ₹300,000 (breaks chk_balance):
-- UPDATE accounts SET balance = balance - 300000 WHERE account_no = 1006;

-- Rollback to clear aborted transaction
ROLLBACK;


-- --------------------------------------------------------------------
-- Task 8 (DDL): Clean up - Drop tables in correct relational order
-- --------------------------------------------------------------------
-- Note: Must drop the child table (accounts) before parent table (customers),
-- or use 'CASCADE' in PostgreSQL:
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;
-- DROP DATABASE IF EXISTS bank_db;
