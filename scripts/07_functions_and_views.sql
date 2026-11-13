-- ====================================================================
-- PostgreSQL Conversion: Functions & Views
-- Module 7: Built-in Functions, User-Defined Functions (PL/pgSQL) & Views
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. Built-in Functions
-- --------------------------------------------------------------------

-- A. String Functions
-- MySQL:    CONCAT(), LEFT(), SUBSTRING(), LOCATE('@', email)
-- Postgres: CONCAT(), LEFT(), SUBSTRING(), POSITION('@' IN email) or STRPOS()
SELECT customer_id,
       UPPER(last_name) AS surname_upper,
       LEFT(first_name, 1) || '. ' || last_name AS short_name,
       LENGTH(email) AS email_length,
       SUBSTRING(email FROM POSITION('@' IN email) + 1) AS email_domain
FROM customers;

-- B. Numeric Functions
SELECT account_no, 
       balance,
       ROUND(balance * 0.035, 2) AS yearly_interest,
       FLOOR(balance / 10000)    AS ten_thousand_blocks
FROM accounts;

-- C. Date & Time Functions
-- MySQL:    TIMESTAMPDIFF(YEAR, dob, CURDATE()), DATE_FORMAT(), DAYNAME()
-- Postgres: EXTRACT(YEAR FROM AGE(CURRENT_DATE, dob)), TO_CHAR()
SELECT customer_id, 
       date_of_birth,
       EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_of_birth))::INT AS age,
       TO_CHAR(date_of_birth, 'DD Mon YYYY') AS dob_formatted,
       TRIM(TO_CHAR(date_of_birth, 'Day'))   AS born_on_day
FROM customers;

-- Date Arithmetic & Interval
-- MySQL:    DATE_ADD(txn_date, INTERVAL 30 DAY), DATEDIFF('2025-03-31', txn_date)
-- Postgres: txn_date + INTERVAL '30 days', DATE '2025-03-31' - txn_date::DATE
SELECT txn_id,
       txn_date,
       txn_date + INTERVAL '30 days' AS due_in_30_days,
       (DATE '2025-03-31' - txn_date::DATE) AS days_to_quarter_end
FROM transactions;

-- D. Aggregate String Concatenation
-- MySQL:    GROUP_CONCAT(account_no ORDER BY account_no SEPARATOR ', ')
-- Postgres: STRING_AGG(account_no::TEXT, ', ' ORDER BY account_no)
SELECT c.customer_id,
       c.first_name,
       STRING_AGG(a.account_no::TEXT, ', ' ORDER BY a.account_no) AS account_numbers
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name;


-- --------------------------------------------------------------------
-- 2. User-Defined Functions (PL/pgSQL)
-- In MySQL:    DELIMITER // CREATE FUNCTION ... BEGIN ... END // DELIMITER ;
-- In Postgres: CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql AS $$ ... $$;
-- --------------------------------------------------------------------

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

-- Function 3: Mask an email for privacy display (e.g. ar*****@example.com)
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

-- Function 4: Compute total balance for a customer (Reads table)
CREATE OR REPLACE FUNCTION fn_total_balance(p_customer_id INT)
RETURNS DECIMAL(14,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total DECIMAL(14,2);
BEGIN
    SELECT COALESCE(SUM(balance), 0) INTO v_total
    FROM accounts
    WHERE customer_id = p_customer_id;
    RETURN v_total;
END;
$$;

-- Testing the Custom Functions in Queries
SELECT account_no, balance, fn_customer_tier(balance) AS tier
FROM accounts
ORDER BY balance DESC;

SELECT first_name, fn_age(date_of_birth) AS age, fn_mask_email(email) AS masked_email
FROM customers;

SELECT customer_id, 
       first_name,
       fn_total_balance(customer_id)                   AS total_balance,
       fn_customer_tier(fn_total_balance(customer_id)) AS customer_tier
FROM customers
ORDER BY total_balance DESC;


-- --------------------------------------------------------------------
-- 3. Views
-- --------------------------------------------------------------------

-- View 1: Customer Accounts with Branch details
CREATE OR REPLACE VIEW vw_customer_accounts AS
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       c.city AS customer_city,
       a.account_no,
       a.account_type,
       a.balance,
       a.status,
       b.branch_name
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN branches b ON b.branch_id   = a.branch_id;

-- Query the view
SELECT * FROM vw_customer_accounts WHERE customer_city = 'Chennai';
SELECT customer_name, SUM(balance) AS total 
FROM vw_customer_accounts 
GROUP BY customer_name;

-- View 2: Branch Management Summary
CREATE OR REPLACE VIEW vw_branch_summary AS
SELECT b.branch_id,
       b.branch_name,
       b.city,
       COUNT(a.account_no)         AS accounts_count,
       COALESCE(SUM(a.balance), 0) AS total_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.city;

-- Query branch summary
SELECT * FROM vw_branch_summary ORDER BY total_balance DESC;

-- View 3: Updatable View with WITH CHECK OPTION
CREATE OR REPLACE VIEW vw_active_savings AS
SELECT account_no, customer_id, branch_id, balance, status
FROM accounts
WHERE account_type = 'SAVINGS' AND status = 'ACTIVE'
WITH CHECK OPTION;
