-- ====================================================================
-- PostgreSQL Conversion: Advanced Queries & Join Strategies
-- Module 6: Subqueries, CTEs, Window Functions & Comprehensive Joins
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. Understanding Query Processing Order
-- Order: FROM/JOIN -> WHERE -> GROUP BY -> HAVING -> SELECT -> DISTINCT -> ORDER BY -> LIMIT
-- (This explains why an alias created in SELECT cannot be filtered in WHERE)
-- --------------------------------------------------------------------

-- Filter, Computed Column and String Concatenation
SELECT customer_id,
       c.first_name || ' ' || c.last_name AS full_name,
       city
FROM customers c
WHERE city IN ('Bengaluru', 'Chennai')
ORDER BY full_name;

-- Distinct Account Types
SELECT DISTINCT account_type FROM accounts;

-- Pattern, Range, and NULL filtering
SELECT * FROM customers WHERE first_name ILIKE 'P%';
SELECT * FROM accounts WHERE balance BETWEEN 30000 AND 80000;
SELECT * FROM customers WHERE phone IS NULL; -- Catches Meera Iyer

-- Pagination with LIMIT and OFFSET
-- Returns 3 rows, skipping the first 2
SELECT account_no, balance 
FROM accounts 
ORDER BY balance DESC 
LIMIT 3 OFFSET 2;


-- --------------------------------------------------------------------
-- 2. Subqueries (Scalar, Multi-Row & Correlated)
-- --------------------------------------------------------------------

-- A. Scalar Subquery: Accounts with balance above the overall bank average
SELECT account_no, customer_id, balance
FROM accounts
WHERE balance > (SELECT AVG(balance) FROM accounts);

-- B. Multi-row Subquery: Customers who hold at least one high-value account (> ₹100,000)
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE customer_id IN (
    SELECT customer_id 
    FROM accounts 
    WHERE balance > 100000
);

-- C. Correlated Subquery: Accounts that exceed the average for their specific account_type
SELECT a.account_no, a.account_type, a.balance
FROM accounts a
WHERE a.balance > (
    SELECT AVG(a2.balance)
    FROM accounts a2
    WHERE a2.account_type = a.account_type
);


-- --------------------------------------------------------------------
-- 3. Common Table Expressions (CTEs - WITH Clause)
-- --------------------------------------------------------------------

-- A. Single CTE: Branch totals and ranking
WITH branch_metrics AS (
    SELECT b.branch_id,
           b.branch_name,
           COUNT(a.account_no) AS total_accounts,
           COALESCE(SUM(a.balance), 0) AS total_balance
    FROM branches b
    LEFT JOIN accounts a ON a.branch_id = b.branch_id
    GROUP BY b.branch_id, b.branch_name
)
SELECT branch_name, total_accounts, total_balance
FROM branch_metrics
WHERE total_balance > 50000
ORDER BY total_balance DESC;

-- B. Chained Multiple CTEs: Customer balances and classification
WITH customer_balances AS (
    SELECT customer_id, SUM(balance) AS total_balance
    FROM accounts
    GROUP BY customer_id
),
wealthy_customers AS (
    SELECT customer_id, total_balance
    FROM customer_balances
    WHERE total_balance >= 100000
)
SELECT c.customer_id, c.first_name, c.last_name, w.total_balance
FROM customers c
JOIN wealthy_customers w ON w.customer_id = c.customer_id
ORDER BY w.total_balance DESC;


-- --------------------------------------------------------------------
-- 4. Window Functions (Partitioning & Ranking)
-- --------------------------------------------------------------------

-- A. ROW_NUMBER, RANK, and DENSE_RANK comparison
SELECT account_no,
       account_type,
       balance,
       ROW_NUMBER() OVER (PARTITION BY account_type ORDER BY balance DESC) AS row_num,
       RANK()       OVER (ORDER BY balance DESC) AS global_rank,
       DENSE_RANK() OVER (ORDER BY balance DESC) AS dense_rank
FROM accounts;

-- B. Running Transaction Total using Cumulative Window Frame
SELECT txn_id,
       account_no,
       txn_date,
       txn_type,
       amount,
       SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount ELSE -amount END)
           OVER (
               PARTITION BY account_no 
               ORDER BY txn_date 
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS running_net_flow
FROM transactions
ORDER BY account_no, txn_date;


-- --------------------------------------------------------------------
-- 5. Complete Joins & Join Strategies
-- --------------------------------------------------------------------

-- A. INNER JOIN: Accounts with customer owners
SELECT c.customer_id, c.first_name, c.last_name, a.account_no, a.account_type, a.balance
FROM customers c
INNER JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_no;

-- B. 4-Table Full Entity Chain JOIN:
-- Transactions -> Accounts -> Customers and Branches
SELECT t.txn_id, 
       t.txn_date, 
       t.txn_type, 
       t.amount,
       c.first_name || ' ' || c.last_name AS customer_name,
       b.branch_name
FROM transactions t
JOIN accounts a  ON a.account_no  = t.account_no
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches b  ON b.branch_id   = a.branch_id
ORDER BY t.txn_date DESC;

-- C. LEFT JOIN: All customers including those with no accounts (Meera Iyer)
SELECT c.customer_id, c.first_name, c.last_name, a.account_no, a.balance
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id;

-- D. RIGHT JOIN: All branches including those with no accounts (Ernakulam)
SELECT b.branch_id, b.branch_name, b.city, a.account_no
FROM accounts a
RIGHT JOIN branches b ON b.branch_id = a.branch_id
ORDER BY b.branch_id;

-- E. FULL OUTER JOIN: Native PostgreSQL Power!
-- (MySQL does NOT support FULL OUTER JOIN and requires ugly UNIONs; PostgreSQL supports it natively!)
SELECT c.customer_id, c.first_name, a.account_no, a.balance
FROM customers c
FULL OUTER JOIN accounts a ON a.customer_id = c.customer_id;

-- F. CROSS JOIN: Cartesian product of all branches and account types
SELECT b.branch_name, t.account_type
FROM branches b
CROSS JOIN (SELECT DISTINCT account_type FROM accounts) t
ORDER BY b.branch_name, t.account_type;

-- G. SELF JOIN: Find pairs of customers living in the same city
SELECT c1.first_name || ' ' || c1.last_name AS customer_1,
       c2.first_name || ' ' || c2.last_name AS customer_2,
       c1.city
FROM customers c1
JOIN customers c2 ON c1.city = c2.city AND c1.customer_id < c2.customer_id;

-- H. SEMI-JOIN: Customers who have accounts (EXISTS - avoids duplicate rows)
SELECT c.customer_id, c.first_name, c.last_name
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM accounts a WHERE a.customer_id = c.customer_id
);

-- I. ANTI-JOIN: Customers who have ZERO accounts (NOT EXISTS)
SELECT c.customer_id, c.first_name, c.last_name, c.city
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.customer_id = c.customer_id
);

-- J. Reading Execution Plans with EXPLAIN & EXPLAIN ANALYZE in PostgreSQL
EXPLAIN ANALYZE
SELECT c.customer_id, a.account_no, a.balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
WHERE a.balance > 50000;
