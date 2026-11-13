-- ====================================================================
-- PostgreSQL Conversion: Advanced Lab Tasks & Assessment Solutions
-- Module 9: Tasks 1 through 10 with Full PostgreSQL Solutions
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- --------------------------------------------------------------------
-- Task 1 (Theory - Normalization Anomalies):
-- Explain which normal form bank_flat violates because of:
-- 1. customer_phones
-- 2. branch_city and customer_city
-- --------------------------------------------------------------------
/*
EXPLANATION:
1. customer_phones violates 1NF (First Normal Form):
   - 1NF requires every column to hold atomic (indivisible) values. Storing
     multiple comma-separated phone numbers in a single cell violates atomicity.
2. customer_city violates 2NF (Second Normal Form):
   - In a table with a composite key, non-key columns must depend on the WHOLE key.
     customer_city depends only on customer_id, not the composite key (Partial Dependency).
3. branch_city violates 3NF (Third Normal Form):
   - 3NF prohibits transitive dependencies (non-key attribute depending on another
     non-key attribute). branch_city depends on branch_name, which violates 3NF.
*/


-- --------------------------------------------------------------------
-- Task 2 (Query - Left Join & Null Handling):
-- List each customer's full name and total balance, highest first,
-- including customers with no account (showing 0).
-- --------------------------------------------------------------------
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       COALESCE(SUM(a.balance), 0.00)     AS total_balance
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance DESC;


-- --------------------------------------------------------------------
-- Task 3 (Query - Window Functions):
-- Show the top account by balance within each account type using a window function.
-- --------------------------------------------------------------------
SELECT account_type, account_no, balance
FROM (
    SELECT account_type,
           account_no,
           balance,
           ROW_NUMBER() OVER (PARTITION BY account_type ORDER BY balance DESC) AS rn
    FROM accounts
) ranked
WHERE rn = 1;


-- --------------------------------------------------------------------
-- Task 4 (Query - Aggregations & HAVING):
-- Find accounts whose average transaction amount is above ₹20,000.
-- --------------------------------------------------------------------
SELECT t.account_no,
       ROUND(AVG(t.amount), 2) AS avg_transaction_amount,
       COUNT(*)                AS transaction_count
FROM transactions t
GROUP BY t.account_no
HAVING AVG(t.amount) > 20000;


-- --------------------------------------------------------------------
-- Task 5 (Join - Anti-Join):
-- List branches that have no active accounts.
-- --------------------------------------------------------------------
SELECT b.branch_id, b.branch_name, b.city
FROM branches b
WHERE NOT EXISTS (
    SELECT 1 
    FROM accounts a 
    WHERE a.branch_id = b.branch_id AND a.status = 'ACTIVE'
);


-- --------------------------------------------------------------------
-- Task 6 (Join - Grouping & Distinct Counts):
-- For each branch, show its name, the number of distinct customers who
-- bank there, and its total balance.
-- --------------------------------------------------------------------
SELECT b.branch_name,
       COUNT(DISTINCT a.customer_id) AS total_customers,
       COALESCE(SUM(a.balance), 0)   AS total_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY total_balance DESC;


-- --------------------------------------------------------------------
-- Task 7 (Function - PL/pgSQL UDF):
-- Create fn_interest(balance, rate) returning yearly interest rounded
-- to 2 decimals, and use it for all savings accounts at 4%.
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_interest(
    p_balance DECIMAL(14,2),
    p_rate    DECIMAL(5,2)
)
RETURNS DECIMAL(14,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN ROUND(p_balance * p_rate / 100.0, 2);
END;
$$;

-- Test function on all SAVINGS accounts with 4% interest
SELECT account_no,
       balance,
       fn_interest(balance, 4.00) AS yearly_interest_4_pct
FROM accounts
WHERE account_type = 'SAVINGS';


-- --------------------------------------------------------------------
-- Task 8 (View - Filtered Virtual Table):
-- Create vw_dormant_accounts listing dormant accounts with owner name and branch.
-- --------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_dormant_accounts AS
SELECT a.account_no,
       c.first_name || ' ' || c.last_name AS customer_name,
       b.branch_name,
       a.balance,
       a.opened_on
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id
WHERE a.status = 'DORMANT';

-- Test View
SELECT * FROM vw_dormant_accounts;


-- --------------------------------------------------------------------
-- Task 9 (Procedure - ATM Withdrawal with Transaction & Balance Validation):
-- Create sp_withdraw(account_no, amount) that rejects overdrafts,
-- updates the balance, and logs a WITHDRAWAL transaction inside a transaction.
-- --------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_withdraw(
    p_account_no BIGINT,
    p_amount     DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_status  VARCHAR(10);
BEGIN
    -- 1. Validate Amount
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Withdrawal amount must be greater than zero.';
    END IF;

    -- 2. Fetch balance with row lock
    SELECT balance, status INTO v_balance, v_status
    FROM accounts
    WHERE account_no = p_account_no
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Account % does not exist.', p_account_no;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Account % is % (cannot withdraw from non-active account).', p_account_no, v_status;
    END IF;

    -- 3. Overdraft Check
    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds: Available balance ₹% is less than requested ₹%', v_balance, p_amount;
    END IF;

    -- 4. Deduct Balance
    UPDATE accounts 
    SET balance = balance - p_amount 
    WHERE account_no = p_account_no;

    -- 5. Record Transaction Log
    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_account_no, 'WITHDRAWAL', p_amount, CURRENT_TIMESTAMP, 'ATM withdrawal via sp_withdraw');

    COMMIT;
    RAISE NOTICE 'Successfully withdrew ₹% from account #%. New balance: ₹%', p_amount, p_account_no, (v_balance - p_amount);
END;
$$;

-- Test Case: Withdraw ₹50,000 from account 1006
CALL sp_withdraw(1006, 50000.00);

-- Verify balance updated to 200,000.00
SELECT account_no, balance FROM accounts WHERE account_no = 1006;


-- --------------------------------------------------------------------
-- Task 10 (DDL Cleanup):
-- --------------------------------------------------------------------
-- DROP TABLE IF EXISTS transactions CASCADE;
-- DROP TABLE IF EXISTS accounts CASCADE;
-- DROP TABLE IF EXISTS customers CASCADE;
-- DROP TABLE IF EXISTS branches CASCADE;
-- DROP DATABASE IF EXISTS bank_lab;
