# SQL Data Modelling, Queries, Functions, Views, Stored Procedures & Joins (PostgreSQL 16+ Edition)

*Hands-on guide on the Bank database | Prepared for EY (PostgreSQL 16+ Edition)*


## 1. Overview

This guide continues the Bank database training. Participants learn how to design a clean relational model (normalization), then write queries, functions, views and stored procedures, and choose the right join. Every topic has its syntax, runnable queries and a short explanation. Run the sections in order on one MySQL session.

Learning objectives. By the end, participants can:

Explain keys, relationships and the first three normal forms, and spot update, insert and delete anomalies

Write filtered, grouped, sorted queries with subqueries, CTEs and window functions

Use built-in functions and create their own user-defined functions

Create views to simplify queries and restrict data

Write stored procedures with parameters, validation, error handling and transactions

Choose between inner, outer, cross, self, semi and anti joins, and read an EXPLAIN plan

Agenda


| Section | Topic | Suggested time |
| --- | --- | --- |
| 2 | Lab setup (schema and sample data) | 20 min |
| 3 | SQL data model and normalization | 60 min |
| 4 | Writing SQL queries | 75 min |
| 5 | Joins and join strategies | 60 min |
| 6 | Functions | 45 min |
| 7 | Views | 30 min |
| 8 | Stored procedures | 60 min |
| 9 | Lab exercises and review questions | 45 min |

Dialect used. PostgreSQL 16+ (converted from MySQL 8.0 InnoDB). Section 10 lists syntax differences across databases.

Database name. This guide uses a fresh database called bank_lab, so it does not clash with bank_db from the DDL/DML/TCL guide. Section 2 builds everything from scratch.


## 2. Lab setup

Connect with psql or pgAdmin as a user who can create databases and routines (for example postgres in a training lab).

Entity-relationship overview

branches (1) ----< (many) accounts (1) ----< (many) transactions
                          ^
                          |
customers (1) ------------+   one customer holds many accounts

Tables


| Table | Purpose | Key columns |
| --- | --- | --- |
| branches | Bank branches | branch_id (PK) |
| customers | Account holders | customer_id (PK), email (unique) |
| accounts | Accounts held by customers at branches | account_no (PK), customer_id (FK), branch_id (FK) |
| transactions | Deposits, withdrawals and transfers | txn_id (PK), account_no (FK) |

Step 1: create the database and tables

```sql
-- In PostgreSQL:
DROP DATABASE IF EXISTS bank_lab;
CREATE DATABASE bank_lab;
\c bank_lab

CREATE TABLE branches (
    branch_id    SERIAL PRIMARY KEY,
    branch_name  VARCHAR(50) NOT NULL UNIQUE,
    city         VARCHAR(50) NOT NULL
);

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
```

Step 2: load the sample data

```sql
INSERT INTO branches (branch_name, city) VALUES
('Indiranagar', 'Bengaluru'), ('T Nagar', 'Chennai'), ('Andheri', 'Mumbai'),
('Madhapur', 'Hyderabad'), ('Connaught Place', 'Delhi'), ('Ernakulam', 'Kochi');

INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city, kyc_status) VALUES
('Arjun',  'Mehta',  'arjun.mehta@example.com',  '9876500001', '1990-04-12', 'Bengaluru', 'VERIFIED'),
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai',   'VERIFIED'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai',    'VERIFIED'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad', 'VERIFIED'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi',     'PENDING'),
('Meera',  'Iyer',   'meera.iyer@example.com',   NULL,         '1993-03-09', 'Bengaluru', 'PENDING');

INSERT INTO accounts (account_no, customer_id, branch_id, account_type, balance, status, opened_on) VALUES
(1001, 1, 1, 'SAVINGS',  52000.00, 'ACTIVE',  '2022-03-15'),
(1002, 1, 1, 'CURRENT', 110000.00, 'ACTIVE',  '2023-01-10'),
(1003, 2, 2, 'SAVINGS',  78000.00, 'ACTIVE',  '2021-06-20'),
(1004, 3, 3, 'SALARY',   31000.00, 'ACTIVE',  '2024-02-01'),
(1005, 4, 4, 'SAVINGS',  15600.00, 'DORMANT', '2023-09-12'),
(1006, 5, 5, 'CURRENT', 250000.00, 'ACTIVE',  '2020-12-05'),
(1007, 2, 2, 'SALARY',   46000.00, 'ACTIVE',  '2024-05-18');

SELECT setval('accounts_account_no_seq', (SELECT MAX(account_no) FROM accounts));

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

SELECT setval('transactions_txn_id_seq', (SELECT MAX(txn_id) FROM transactions));
```

Step 3: verify

```sql
SELECT 'branches' AS tbl, COUNT(*) AS row_count FROM branches
UNION ALL SELECT 'customers',    COUNT(*) FROM customers
UNION ALL SELECT 'accounts',     COUNT(*) FROM accounts
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions;
```

Expected row counts: branches 6, customers 6, accounts 7, transactions 12.

Built-in test cases. The data is shaped to make later topics interesting: customer 6 (Meera) has no account and no phone, branch 6 (Ernakulam) has no accounts, account 1005 is dormant with no transactions, and customers 1 and 6 live in the same city.


## 3. SQL data model and normalization


### 3.1 Relational model basics


| Term | Meaning | Example in bank_lab |
| --- | --- | --- |
| Table (relation) | A set of rows with the same columns | accounts |
| Row (tuple) | One record | Account 1001 |
| Column (attribute) | One property with a data type | balance |
| Primary key | Column(s) that uniquely identify a row; never NULL | account_no |
| Foreign key | Column that references a primary key in another table | accounts.customer_id |
| Unique key | Prevents duplicate values; may allow NULL | customers.email |
| Candidate key | Any column set that could be the primary key | customer_id, email |
| Composite key | A key made of several columns | (order_id, product_id) in a line-item table |

Relationship types


| Type | Meaning | Example |
| --- | --- | --- |
| One-to-many (1:N) | One row on one side links to many on the other | One customer holds many accounts |
| One-to-one (1:1) | One row links to exactly one row | Customer and a passport record |
| Many-to-many (M:N) | Resolved with a junction table holding both foreign keys | Customers and joint accounts: account_holders(account_no, customer_id) |

Integrity rules. Entity integrity: every table has a non-null primary key. Referential integrity: a foreign key must match an existing parent row or be NULL. Domain integrity: values obey the data type and CHECK rules.


### 3.2 Why normalize

Normalization organizes data so each fact is stored once. A badly designed table causes three anomalies:


| Anomaly | What goes wrong |
| --- | --- |
| Update | Changing one fact means editing many rows; missing one leaves inconsistent data |
| Insert | A fact cannot be stored until an unrelated fact exists (a branch cannot be added until it has an account) |
| Delete | Removing one row accidentally erases another fact (deleting the last account removes the branch details) |


### 3.3 Worked example: from one flat table to third normal form

Step 1: the unnormalized table. A clerk keeps everything in one sheet. Create and load it:

```sql
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
```

See the anomalies. The block runs inside a transaction and is rolled back, so the sheet returns to its original state for the migration step.

```sql
START TRANSACTION;

-- Update anomaly: the Indiranagar manager changes, but only one row is edited
UPDATE bank_flat SET branch_manager = 'A. Pillai' WHERE row_id = 1;
SELECT DISTINCT branch_name, branch_manager FROM bank_flat WHERE branch_name = 'Indiranagar';
-- Two different managers now appear for the same branch.

-- Insert anomaly: a new branch cannot be recorded without inventing an account.
-- Delete anomaly: removing Rahul's only account also erases the Andheri branch
DELETE FROM bank_flat WHERE row_id = 5;
SELECT * FROM bank_flat WHERE branch_name = 'Andheri';   -- no rows: branch details are lost

ROLLBACK;
```

Step 2: First Normal Form (1NF). Rule: every column holds a single atomic value, and there are no repeating groups.

Problem: customer_phones holds two numbers in one cell. Fix: store one phone per row in its own table.

customer_phone (customer, phone)
Arjun Mehta | 9876500001
Arjun Mehta | 9876500011

Step 3: Second Normal Form (2NF). Rule: the table is in 1NF and no non-key column depends on only part of a composite key.

In the flat sheet the natural key is (customer, account_no). The customer’s name and city depend only on the customer, not on the account. Fix: move customer facts to a customers table.

Step 4: Third Normal Form (3NF). Rule: the table is in 2NF and no non-key column depends on another non-key column (no transitive dependency).

Here branch_city and branch_manager depend on branch_name, not on the account. Fix: move them to a branches table.

account_no -> branch_name -> branch_city, branch_manager     (transitive: split it)


| Normal form | Removes | Fix |
| --- | --- | --- |
| 1NF | Repeating groups, multi-valued cells | One value per cell; child table |
| 2NF | Partial dependency on part of a composite key | Separate table per entity |
| 3NF | Transitive dependency between non-key columns | Move dependent columns to their own table |
| BCNF | Any determinant that is not a candidate key | Stronger 3NF; rarely differs in practice |

Step 5: build the 3NF design and migrate the data. The scratch tables carry a n_ prefix so they stay separate from the lab schema.

```sql
CREATE TABLE n_branches (
    branch_name    VARCHAR(50) PRIMARY KEY,
    branch_city    VARCHAR(40),
    branch_manager VARCHAR(50)
);
CREATE TABLE n_customers (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(60) NOT NULL UNIQUE,
    customer_city VARCHAR(40)
);
CREATE TABLE n_customer_phones (
    customer_id INT NOT NULL,
    phone       VARCHAR(15) NOT NULL,
    PRIMARY KEY (customer_id, phone),
    FOREIGN KEY (customer_id) REFERENCES n_customers (customer_id)
);
CREATE TABLE n_accounts (
    account_no   BIGINT PRIMARY KEY,
    customer_id  INT NOT NULL,
    branch_name  VARCHAR(50) NOT NULL,
    account_type VARCHAR(20),
    balance      DECIMAL(12,2),
    FOREIGN KEY (customer_id) REFERENCES n_customers (customer_id),
    FOREIGN KEY (branch_name) REFERENCES n_branches (branch_name)
);

-- Migrate: each fact is now stored once
INSERT INTO n_branches (branch_name, branch_city, branch_manager)
SELECT DISTINCT branch_name, branch_city, branch_manager FROM bank_flat;

INSERT INTO n_customers (customer_name, customer_city)
SELECT DISTINCT customer_name, customer_city FROM bank_flat;

INSERT INTO n_customer_phones (customer_id, phone)
SELECT customer_id, '9876500001' FROM n_customers WHERE customer_name = 'Arjun Mehta';
INSERT INTO n_customer_phones (customer_id, phone)
SELECT customer_id, '9876500011' FROM n_customers WHERE customer_name = 'Arjun Mehta';

INSERT INTO n_accounts (account_no, customer_id, branch_name, account_type, balance)
SELECT f.account_no, c.customer_id, f.branch_name, f.account_type, f.balance
FROM bank_flat f JOIN n_customers c ON c.customer_name = f.customer_name;
```

Anomalies are gone

```sql
-- Update: one row changes the manager for every account at the branch
UPDATE n_branches SET branch_manager = 'A. Pillai' WHERE branch_name = 'Indiranagar';

-- Insert: a branch can now exist without accounts
INSERT INTO n_branches VALUES ('Ernakulam', 'Kochi', 'T. Menon');

-- Delete: dropping an account leaves the branch intact
DELETE FROM n_accounts WHERE account_no = 1004;
SELECT * FROM n_branches WHERE branch_name = 'Andheri';

-- Reassemble the original sheet with joins
SELECT c.customer_name, a.account_no, a.account_type, a.balance, b.branch_name, b.branch_city
FROM n_accounts a
JOIN n_customers c ON c.customer_id = a.customer_id
JOIN n_branches  b ON b.branch_name = a.branch_name
ORDER BY a.account_no;
```

The bank_lab schema in Section 2 is the same 3NF design, using numeric branch_id surrogate keys instead of names.

Clean up the scratch tables

```sql
DROP TABLE IF EXISTS n_accounts CASCADE;
DROP TABLE IF EXISTS n_customer_phones CASCADE;
DROP TABLE IF EXISTS n_customers CASCADE;
DROP TABLE IF EXISTS n_branches CASCADE;
DROP TABLE IF EXISTS bank_flat CASCADE;
```


### 3.4 Denormalization and good design habits


| Practice | Guidance |
| --- | --- |
| Start normalized | Aim for 3NF in transactional (OLTP) systems such as banking |
| Denormalize with a reason | Reporting and analytics tables may repeat data to avoid heavy joins; keep the normalized source of truth |
| Use surrogate keys | Integer keys (customer_id) stay stable when business data (an email) changes |
| Choose exact types | DECIMAL for money, DATE for dates, not text |
| Name consistently | Singular or plural, but pick one; snake_case; id columns named <entity>_id |
| Declare constraints | Primary, foreign, unique and CHECK rules put the business rules in the database |


## 4. Writing SQL queries


### 4.1 Anatomy of a SELECT

```sql
SELECT [DISTINCT] column_list | expressions
FROM   table_name [alias]
[JOIN  other_table ON condition]
[WHERE condition]
[GROUP BY column_list]
[HAVING group_condition]
[ORDER BY column [ASC | DESC]]
[LIMIT row_count [OFFSET skip]];
```

```sql
The database processes clauses in a different order than you write them. Understanding this explains why an alias defined in SELECT cannot be used in WHERE.
```


| Order | Clause | What it does |
| --- | --- | --- |
| 1 | FROM / JOIN | Builds the working row set |
| 2 | WHERE | Filters individual rows |
| 3 | GROUP BY | Forms groups |
| 4 | HAVING | Filters groups |
| 5 | SELECT | Computes the output columns |
| 6 | DISTINCT | Removes duplicate output rows |
| 7 | ORDER BY | Sorts the result |
| 8 | LIMIT | Trims the result |

Start every session with:

```sql
\c bank_lab
```


### 4.2 Filtering, sorting and limiting


| Operator | Use | Example |
| --- | --- | --- |
| =, <>, <, >, <=, >= | Comparison | balance >= 50000 |
| AND, OR, NOT | Logic | city = 'Delhi' OR city = 'Mumbai' |
| IN (...) | Match any value in a list | city IN ('Delhi','Mumbai') |
| BETWEEN a AND b | Inclusive range | balance BETWEEN 30000 AND 80000 |
| LIKE | Pattern: % any text, _ one character | first_name LIKE 'P%' |
| IS NULL, IS NOT NULL | Missing values | phone IS NULL |

```sql
-- Chosen columns, an alias and a computed column
SELECT customer_id,
       CONCAT(first_name, ' ', last_name) AS full_name,
       city
FROM customers
WHERE city IN ('Bengaluru', 'Chennai')
ORDER BY full_name;

-- Distinct values
SELECT DISTINCT account_type FROM accounts;

-- Pattern, range and NULL tests
SELECT * FROM customers WHERE first_name LIKE 'P%';
SELECT account_no, balance FROM accounts WHERE balance BETWEEN 30000 AND 80000 ORDER BY balance DESC;
SELECT customer_id, first_name FROM customers WHERE phone IS NULL;

-- Date range: transactions in February 2025 (half-open range is index friendly)
SELECT txn_id, account_no, txn_type, amount, txn_date
FROM transactions
WHERE txn_date >= '2025-02-01' AND txn_date < '2025-03-01'
ORDER BY txn_date;

-- Top 3 balances, and paging (skip 3, take 3)
SELECT account_no, balance FROM accounts ORDER BY balance DESC LIMIT 3;
SELECT account_no, balance FROM accounts ORDER BY balance DESC LIMIT 3 OFFSET 3;
```

NULL rules to remember. NULL = NULL is not true; use IS NULL. Arithmetic with NULL gives NULL. COUNT(column) skips NULLs, while COUNT(*) counts rows.


### 4.3 Aggregation: GROUP BY and HAVING


| Function | Returns |
| --- | --- |
| COUNT(*) | Number of rows |
| COUNT(col) | Number of non-NULL values |
| SUM(col), AVG(col) | Total and average |
| MIN(col), MAX(col) | Smallest and largest |

```sql
-- Whole-table summary
SELECT COUNT(*) AS accounts, SUM(balance) AS total_balance,
       ROUND(AVG(balance), 2) AS avg_balance, MIN(balance) AS lowest, MAX(balance) AS highest
FROM accounts;

-- COUNT(*) versus COUNT(column)
SELECT COUNT(*) AS all_customers, COUNT(phone) AS with_phone FROM customers;

-- One row per group
SELECT account_type, COUNT(*) AS accounts, SUM(balance) AS total_balance
FROM accounts
GROUP BY account_type
ORDER BY total_balance DESC;

-- Filter rows before grouping (WHERE) and groups after (HAVING)
SELECT branch_id, COUNT(*) AS active_accounts, SUM(balance) AS total_balance
FROM accounts
WHERE status = 'ACTIVE'
GROUP BY branch_id
HAVING SUM(balance) > 100000
ORDER BY total_balance DESC;

-- Monthly transaction volume
SELECT DATE_FORMAT(txn_date, '%Y-%m') AS month, txn_type, COUNT(*) AS txns, SUM(amount) AS total
FROM transactions
GROUP BY DATE_FORMAT(txn_date, '%Y-%m'), txn_type
ORDER BY month, txn_type;
```

Expected results. The whole-table summary returns 7 accounts, a total of 582,600.00, an average of 83,228.57, a lowest balance of 15,600.00 and a highest of 250,000.00. COUNT(*) returns 6 customers but COUNT(phone) returns 5 because Meera has no phone. The account-type totals are:


| account_type | accounts | total_balance |
| --- | --- | --- |
| CURRENT | 2 | 360000.00 |
| SAVINGS | 3 | 145600.00 |
| SALARY | 2 | 77000.00 |

```sql
Rule. Every column in SELECT must be either inside an aggregate function or listed in GROUP BY.
```


### 4.4 CASE expressions

CASE adds if-then logic inside a query.

CASE WHEN condition1 THEN result1
     WHEN condition2 THEN result2
     ELSE default_result
END

```sql
-- Label each account by balance band
SELECT account_no, balance,
       CASE WHEN balance >= 200000 THEN 'High'
            WHEN balance >= 50000  THEN 'Medium'
            ELSE 'Low'
       END AS balance_band
FROM accounts
ORDER BY balance DESC;

-- Conditional aggregation: pivot account types into columns
SELECT branch_id,
       SUM(CASE WHEN account_type = 'SAVINGS' THEN balance ELSE 0 END) AS savings_total,
       SUM(CASE WHEN account_type = 'CURRENT' THEN balance ELSE 0 END) AS current_total,
       SUM(CASE WHEN account_type = 'SALARY'  THEN balance ELSE 0 END) AS salary_total
FROM accounts
GROUP BY branch_id
ORDER BY branch_id;
```


### 4.5 Subqueries

```sql
A subquery is a SELECT inside another statement.
```


| Kind | Where it appears | Returns |
| --- | --- | --- |
| Scalar | In SELECT or WHERE with =, > | One value |
| List | IN (subquery) | A column of values |
| Existence | EXISTS (subquery) | True if any row comes back |
| Correlated | Refers to the outer query’s columns | Re-evaluated for each outer row |
| Derived table | In FROM (subquery) alias | A temporary table |

```sql
-- Scalar: accounts above the overall average balance
SELECT account_no, balance
FROM accounts
WHERE balance > (SELECT AVG(balance) FROM accounts);

-- List: customers who hold a CURRENT account
SELECT customer_id, first_name, last_name
FROM customers
WHERE customer_id IN (SELECT customer_id FROM accounts WHERE account_type = 'CURRENT');

-- Existence: customers with at least one transaction over 50000
SELECT c.customer_id, c.first_name
FROM customers c
WHERE EXISTS (SELECT 1
              FROM accounts a
              JOIN transactions t ON t.account_no = a.account_no
              WHERE a.customer_id = c.customer_id AND t.amount > 50000);

-- Correlated: accounts holding more than the average of their own type
SELECT a.account_no, a.account_type, a.balance
FROM accounts a
WHERE a.balance > (SELECT AVG(b.balance) FROM accounts b WHERE b.account_type = a.account_type);

-- Derived table: average of per-customer totals
SELECT ROUND(AVG(t.total), 2) AS avg_customer_total
FROM (SELECT customer_id, SUM(balance) AS total FROM accounts GROUP BY customer_id) AS t;
```

Tip. Prefer NOT EXISTS over NOT IN when the subquery column can be NULL, because NOT IN returns no rows if the list contains a NULL.


### 4.6 Common Table Expressions (CTE)

A CTE names a subquery so the main query reads top to bottom. Available from MySQL 8.0.

```sql
WITH cte_name [(col1, col2)] AS (
    SELECT ...
)
SELECT ... FROM cte_name;
```

```sql
-- Net money movement per account, then compare with the stored balance
WITH txn_totals AS (
    SELECT account_no,
           SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount ELSE -amount END) AS net_flow
    FROM transactions
    GROUP BY account_no
)
SELECT a.account_no, a.balance, COALESCE(t.net_flow, 0) AS net_flow
FROM accounts a
LEFT JOIN txn_totals t ON t.account_no = a.account_no
ORDER BY a.account_no;

-- (The sample transaction history is illustrative and does not reconcile to the stored balances.)

-- Two chained CTEs: customers whose total balance beats the average customer
WITH customer_totals AS (
    SELECT customer_id, SUM(balance) AS total FROM accounts GROUP BY customer_id
),
avg_total AS (
    SELECT AVG(total) AS avg_total FROM customer_totals
)
SELECT c.first_name, c.last_name, ct.total
FROM customer_totals ct
JOIN avg_total  av ON ct.total > av.avg_total
JOIN customers  c  ON c.customer_id = ct.customer_id
ORDER BY ct.total DESC;
```


### 4.7 Window functions

A window function calculates across a set of related rows without collapsing them into one row the way GROUP BY does.

function_name(...) OVER (
    [PARTITION BY column_list]
    [ORDER BY column_list]
    [ROWS BETWEEN ... AND ...]
)


| Function | Purpose |
| --- | --- |
| ROW_NUMBER() | Unique sequence number within the partition |
| RANK(), DENSE_RANK() | Ranking with ties (RANK leaves gaps, DENSE_RANK does not) |
| SUM() OVER, AVG() OVER | Running or partition-wide totals |
| LAG(col), LEAD(col) | Value from the previous or next row |

```sql
-- Rank accounts by balance, overall and within each account type
SELECT account_no, account_type, balance,
       RANK() OVER (ORDER BY balance DESC) AS overall_rank,
       ROW_NUMBER() OVER (PARTITION BY account_type ORDER BY balance DESC) AS rank_in_type
FROM accounts
ORDER BY overall_rank;

-- Running balance of each account built from its transactions
SELECT account_no, txn_date, txn_type, amount,
       SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount ELSE -amount END)
           OVER (PARTITION BY account_no ORDER BY txn_date, txn_id) AS running_balance
FROM transactions
ORDER BY account_no, txn_date, txn_id;

-- Compare each transaction with the previous one on the same account
SELECT account_no, txn_date, amount,
       LAG(amount) OVER (PARTITION BY account_no ORDER BY txn_date, txn_id) AS previous_amount
FROM transactions
ORDER BY account_no, txn_date, txn_id;

-- Share of the bank's total held by each account
SELECT account_no, balance,
       ROUND(100 * balance / SUM(balance) OVER (), 1) AS pct_of_total
FROM accounts
ORDER BY balance DESC;
```


### 4.8 Set operations


| Operator | Result |
| --- | --- |
| UNION | Combined rows, duplicates removed |
| UNION ALL | Combined rows, duplicates kept (faster) |
| INTERSECT | Rows present in both queries (MySQL 8.0.31+) |
| EXCEPT | Rows in the first query but not the second (MySQL 8.0.31+) |

Both queries must return the same number of columns with compatible types.

```sql
-- Every city the bank knows about, from customers and branches
SELECT city FROM customers
UNION
SELECT city FROM branches
ORDER BY city;

-- Cities that have both a customer and a branch
SELECT city FROM customers
INTERSECT
SELECT city FROM branches;

-- Branch cities with no customer living there
SELECT city FROM branches
EXCEPT
SELECT city FROM customers;
```


## 5. Joins and join strategies

A join combines rows from two or more tables using a related column. Choose the join type by asking: which rows must survive when there is no match?


### 5.1 The join types


| Join | Rows returned | Typical use |
| --- | --- | --- |
| INNER JOIN | Only rows that match in both tables | Customers with their accounts |
| LEFT JOIN | All left rows; matching right rows, else NULL | Customers even if they have no account |
| RIGHT JOIN | All right rows; matching left rows, else NULL | Same as left join with the tables swapped |
| FULL OUTER JOIN | All rows from both sides | Reconciliation; MySQL needs UNION of left and right |
| CROSS JOIN | Every left row paired with every right row | Generating combinations |
| Self join | A table joined to itself with aliases | Pairs of customers in the same city |
| Semi join | Left rows that have a match (no duplicates) | EXISTS or IN |
| Anti join | Left rows that have no match | LEFT JOIN ... IS NULL or NOT EXISTS |

```sql
SELECT columns
FROM table_a a
[INNER | LEFT | RIGHT | CROSS] JOIN table_b b
     ON a.key = b.key          -- or USING (key) when the column name is the same
[WHERE ...];
```


### 5.2 Inner join

```sql
-- Each account with its owner
SELECT c.customer_id, c.first_name, c.last_name, a.account_no, a.account_type, a.balance
FROM customers c
INNER JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_no;

-- Four tables: transaction -> account -> customer and branch
SELECT t.txn_id, t.txn_date, t.txn_type, t.amount,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       b.branch_name
FROM transactions t
JOIN accounts  a ON a.account_no  = t.account_no
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id
ORDER BY t.txn_date, t.txn_id;
```

Customer 6 (Meera) does not appear in the first result because she has no account.


### 5.3 Outer joins

```sql
-- LEFT JOIN keeps every customer, with NULLs where there is no account
SELECT c.customer_id, c.first_name, a.account_no, a.balance
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id;

-- RIGHT JOIN keeps every branch, including Ernakulam with no accounts
SELECT b.branch_name, a.account_no
FROM accounts a
RIGHT JOIN branches b ON b.branch_id = a.branch_id
ORDER BY b.branch_id;

-- FULL OUTER JOIN emulation: left join UNION right join
SELECT c.customer_id, c.first_name, a.account_no
FROM customers c LEFT JOIN accounts a ON a.customer_id = c.customer_id
UNION
SELECT c.customer_id, c.first_name, a.account_no
FROM customers c RIGHT JOIN accounts a ON a.customer_id = c.customer_id;
```

Condition placement matters in outer joins. A filter on the right table inside WHERE turns a left join into an inner join; put it in ON to keep unmatched left rows.

```sql
-- Customers with their ACTIVE accounts only, keeping customers who have none
SELECT c.first_name, a.account_no, a.status
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id AND a.status = 'ACTIVE'
ORDER BY c.customer_id;

-- Same filter in WHERE: unmatched customers disappear (behaves like an inner join)
SELECT c.first_name, a.account_no, a.status
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
WHERE a.status = 'ACTIVE'
ORDER BY c.customer_id;
```


### 5.4 Anti join and semi join

```sql
-- Anti join: customers with NO account (LEFT JOIN ... IS NULL)
SELECT c.customer_id, c.first_name
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
WHERE a.account_no IS NULL;

-- Anti join with NOT EXISTS: accounts with NO transactions
SELECT a.account_no, a.account_type
FROM accounts a
WHERE NOT EXISTS (SELECT 1 FROM transactions t WHERE t.account_no = a.account_no);

-- Anti join: branches with no accounts
SELECT b.branch_name
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
WHERE a.account_no IS NULL;

-- Semi join: customers who have at least one account (no duplicate rows)
SELECT c.customer_id, c.first_name
FROM customers c
WHERE EXISTS (SELECT 1 FROM accounts a WHERE a.customer_id = c.customer_id);
```


### 5.5 Cross join and self join

```sql
-- Cross join: every account type paired with every branch city (3 x 6 = 18 rows)
SELECT t.account_type, b.branch_name
FROM (SELECT 'SAVINGS' AS account_type UNION ALL SELECT 'CURRENT' UNION ALL SELECT 'SALARY') t
CROSS JOIN branches b
ORDER BY b.branch_name, t.account_type;

-- Self join: pairs of customers living in the same city (a.customer_id < b.customer_id avoids mirrored pairs)
SELECT a.customer_id AS customer_1, a.first_name AS name_1,
       b.customer_id AS customer_2, b.first_name AS name_2, a.city
FROM customers a
JOIN customers b ON a.city = b.city AND a.customer_id < b.customer_id;
```


### 5.6 Joins with aggregation: avoid the fan-out trap

Joining a parent to two child tables multiplies rows and inflates sums. Aggregate each child first, then join the totals.

```sql
-- Wrong: each account row repeats once per transaction, so balances are over-counted
SELECT c.customer_id, SUM(a.balance) AS wrong_total
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_no = a.account_no
GROUP BY c.customer_id
ORDER BY c.customer_id;

-- Right: aggregate transactions per account in a derived table first
SELECT c.customer_id, c.first_name,
       SUM(a.balance) AS total_balance,
       COALESCE(SUM(x.txn_count), 0) AS txn_count
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
LEFT JOIN (SELECT account_no, COUNT(*) AS txn_count FROM transactions GROUP BY account_no) x
       ON x.account_no = a.account_no
GROUP BY c.customer_id, c.first_name
ORDER BY c.customer_id;
```

Expected result. The wrong query reports 376,000.00 for customer 1 although the true total is 162,000.00, because each account row is repeated once per transaction. The corrected query returns 162,000.00, 124,000.00, 31,000.00, 15,600.00 and 250,000.00 for customers 1 to 5.


### 5.7 Join strategies and performance

The optimizer picks how to execute a join. You help it with good keys and by reading its plan.


| Strategy | How it works | When it is chosen |
| --- | --- | --- |
| Nested loop with index lookup | For each row of the outer table, find matches in the inner table through an index | Joining on indexed keys; the default and fastest for selective joins |
| Hash join | Builds an in-memory hash table of the smaller input and probes it | Large inputs with no usable index (MySQL 8.0.18+) |
| Block nested loop | Buffers a block of outer rows and scans the inner table once per block | Older versions when no index exists |

Practical rules

Index the join columns. Primary keys are indexed automatically; MySQL creates an index on each foreign key column.

Join columns should have the same data type and character set; a mismatch can disable the index.

Do not wrap an indexed column in a function in ON or WHERE (YEAR(txn_date) = 2025 cannot use an index on txn_date; use a date range instead).

```sql
Filter early with WHERE, and select only the columns you need instead of SELECT *.
```

Choose EXISTS for presence tests; it can stop at the first match.

Check the plan with EXPLAIN. Avoid type = ALL (a full table scan) on large tables.

```sql
-- Read an execution plan
EXPLAIN
SELECT c.first_name, a.account_no, t.amount
FROM customers c
JOIN accounts a     ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_no  = a.account_no
WHERE c.city = 'Bengaluru';
```


| EXPLAIN column | Read it as |
| --- | --- |
| type | Access method, best to worst: const, eq_ref, ref, range, index, ALL |
| key | The index actually used |
| rows | Estimated rows examined |
| Extra | Hints such as Using index, Using temporary, Using filesort |

```sql
-- Range predicate that can use an index, versus a function that cannot
CREATE INDEX idx_txn_date ON transactions (txn_date);

EXPLAIN SELECT * FROM transactions WHERE txn_date >= '2025-02-01' AND txn_date < '2025-03-01';
EXPLAIN SELECT * FROM transactions WHERE MONTH(txn_date) = 2;
```

Reading the result. With only 12 rows, the optimizer scans the whole table for both statements. Look at possible_keys: the date-range query lists idx_txn_date as a candidate, while the MONTH(txn_date) query lists none because the function hides the column. On a table with millions of rows, the first plan uses the index and the second still scans every row.

On MySQL 8.0.18 and later, EXPLAIN ANALYZE runs the query and reports actual timings and which join algorithm was used:

```sql
EXPLAIN ANALYZE SELECT ... ;
```


## 6. Functions


### 6.1 Built-in functions


| Group | Functions | Example |
| --- | --- | --- |
| String | CONCAT, UPPER, LOWER, LENGTH, SUBSTRING, LEFT, RIGHT, TRIM, REPLACE, LPAD, LOCATE | UPPER(last_name) |
| Numeric | ROUND, CEIL, FLOOR, ABS, MOD, POWER | ROUND(balance * 0.035, 2) |
| Date and time | CURDATE, NOW, DATE_FORMAT, DATEDIFF, TIMESTAMPDIFF, DATE_ADD, YEAR, MONTH, DAYNAME | TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) |
| NULL and control | IF, IFNULL, COALESCE, NULLIF, CASE | COALESCE(phone, 'Not provided') |
| Aggregate | COUNT, SUM, AVG, MIN, MAX, GROUP_CONCAT | GROUP_CONCAT(account_no) |

```sql
-- String functions
SELECT customer_id,
       UPPER(last_name)                                  AS surname_upper,
       CONCAT(LEFT(first_name, 1), '. ', last_name)      AS short_name,
       LENGTH(email)                                     AS email_length,
       SUBSTRING(email, LOCATE('@', email) + 1)          AS email_domain
FROM customers;

-- Numeric functions: 3.5% yearly interest, rounded
SELECT account_no, balance,
       ROUND(balance * 0.035, 2)  AS yearly_interest,
       FLOOR(balance / 10000)     AS ten_thousand_blocks
FROM accounts;

-- Date functions
SELECT customer_id, date_of_birth,
       TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age,
       DATE_FORMAT(date_of_birth, '%d %b %Y')        AS dob_text,
       DAYNAME(date_of_birth)                        AS born_on
FROM customers;

SELECT txn_id, txn_date,
       DATE_ADD(txn_date, INTERVAL 30 DAY) AS due_in_30_days,
       DATEDIFF('2025-03-31', DATE(txn_date)) AS days_to_month_end
FROM transactions
LIMIT 5;

-- NULL handling and conditional functions
SELECT customer_id, first_name,
       COALESCE(phone, 'Not provided')            AS phone_display,
       IF(kyc_status = 'VERIFIED', 'Yes', 'No')   AS kyc_done,
       NULLIF(city, 'Delhi')                      AS city_or_null
FROM customers;

-- Ages depend on today's date, so your output will differ from a printed copy.

-- Collapse many rows into one text value
SELECT customer_id, GROUP_CONCAT(account_no ORDER BY account_no SEPARATOR ', ') AS accounts
FROM accounts
GROUP BY customer_id;
```


### 6.2 User-defined functions

A stored function takes parameters, runs logic and returns exactly one value, so you can use it inside any query like a built-in function.

DELIMITER //
CREATE FUNCTION function_name (param1 datatype, param2 datatype)
RETURNS return_datatype
[DETERMINISTIC | NOT DETERMINISTIC]
[NO SQL | READS SQL DATA]
BEGIN
    DECLARE variable datatype;
    ...
    RETURN value;
END //
DELIMITER ;

Notes

The client’s default delimiter ; would end the statement inside the body, so DELIMITER // temporarily changes it. This is a client command, not SQL.

DETERMINISTIC means the same inputs always give the same result. If binary logging is on (the default in MySQL 8.0), you must declare DETERMINISTIC, NO SQL or READS SQL DATA, or MySQL raises error 1418.

Functions cannot start or end transactions. Use procedures for that.

Function 1: customer tier from a balance

DELIMITER //
CREATE FUNCTION fn_customer_tier (p_balance DECIMAL(14,2))
RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    RETURN CASE
        WHEN p_balance >= 200000 THEN 'PLATINUM'
        WHEN p_balance >= 100000 THEN 'GOLD'
        WHEN p_balance >= 50000  THEN 'SILVER'
        ELSE 'STANDARD'
    END;
END //
DELIMITER ;

Function 2: age from a date of birth

```sql
CREATE OR REPLACE FUNCTION fn_age (p_dob DATE)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_dob))::INT;
END;
$$;
```

Function 3: mask an email for display

DELIMITER //
CREATE FUNCTION fn_mask_email (p_email VARCHAR(100))
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    IF p_email IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN CONCAT(LEFT(p_email, 2), '*****', SUBSTRING(p_email, LOCATE('@', p_email)));
END //
DELIMITER ;

Function 4: total balance of a customer (reads a table)

```sql
DELIMITER //
CREATE FUNCTION fn_total_balance (p_customer_id INT)
RETURNS DECIMAL(14,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(14,2);
    SELECT COALESCE(SUM(balance), 0) INTO v_total
    FROM accounts
    WHERE customer_id = p_customer_id;
    RETURN v_total;
END //
DELIMITER ;
```

Use the functions in queries

```sql
SELECT account_no, balance, fn_customer_tier(balance) AS tier
FROM accounts
ORDER BY balance DESC;

SELECT first_name, fn_age(date_of_birth) AS age, fn_mask_email(email) AS masked_email
FROM customers;

SELECT customer_id, first_name,
       fn_total_balance(customer_id)                    AS total_balance,
       fn_customer_tier(fn_total_balance(customer_id))  AS tier
FROM customers
ORDER BY total_balance DESC;
```

Expected result. Tiers: account 1006 = PLATINUM, 1002 = GOLD, 1003 and 1001 = SILVER, 1007, 1004 and 1005 = STANDARD. Customer totals: Vikram 250,000.00 (PLATINUM), Arjun 162,000.00 (GOLD), Priya 124,000.00 (GOLD), Rahul 31,000.00, Sneha 15,600.00 and Meera 0.00 (all STANDARD). Masked emails look like ar*****@example.com.

Manage functions

SHOW FUNCTION STATUS WHERE Db = 'bank_lab';
SHOW CREATE FUNCTION fn_customer_tier;

DROP FUNCTION IF EXISTS function_name;

```sql
Performance note. A function called in WHERE or JOIN runs once per row and blocks index use on the wrapped column. Use it freely in the SELECT list; be careful in filters.
```


## 7. Views

```sql
A view is a saved SELECT that behaves like a virtual table. It stores no data of its own; each time you query it, the database runs the underlying query.
```

Why use views


| Benefit | Example |
| --- | --- |
| Simplify | Hide a four-table join behind one name |
| Secure | Show only some columns or rows to a user group |
| Consistent logic | One definition of “active balance” for every report |
| Stable interface | Change the base tables later without breaking reports |

```sql
CREATE [OR REPLACE] VIEW view_name [(column_aliases)] AS
SELECT ...
[WITH [CASCADED | LOCAL] CHECK OPTION];

ALTER VIEW view_name AS SELECT ...;
DROP VIEW [IF EXISTS] view_name;
```

View 1: customers with their accounts

```sql
CREATE OR REPLACE VIEW vw_customer_accounts AS
SELECT c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       c.city AS customer_city,
       a.account_no, a.account_type, a.balance, a.status,
       b.branch_name
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN branches b ON b.branch_id   = a.branch_id;

SELECT * FROM vw_customer_accounts WHERE customer_city = 'Chennai';
SELECT customer_name, SUM(balance) AS total FROM vw_customer_accounts GROUP BY customer_name;
```

View 2: a branch summary for management

```sql
CREATE OR REPLACE VIEW vw_branch_summary AS
SELECT b.branch_id, b.branch_name, b.city,
       COUNT(a.account_no)         AS accounts,
       COALESCE(SUM(a.balance), 0) AS total_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.city;

SELECT * FROM vw_branch_summary ORDER BY total_balance DESC;
```

View 3: a secure view for a support team (no balances, masked email and phone)

```sql
CREATE OR REPLACE VIEW vw_customer_support AS
SELECT customer_id, first_name, last_name, city,
       fn_mask_email(email)                     AS email_masked,
       CONCAT('XXXXXX', RIGHT(phone, 4))        AS phone_masked,
       kyc_status
FROM customers;

SELECT * FROM vw_customer_support;
```

Grant the support team access to the view only, not the base table:

```sql
GRANT SELECT ON vw_customer_support TO support_user;
```

View 4: an updatable view with CHECK OPTION

A simple view (one table, no aggregates, joins or DISTINCT) can accept INSERT, UPDATE and DELETE, which pass through to the base table. WITH CHECK OPTION rejects changes that would make a row disappear from the view.

```sql
CREATE OR REPLACE VIEW vw_active_accounts AS
SELECT account_no, customer_id, branch_id, account_type, balance, status, opened_on
FROM accounts
WHERE status = 'ACTIVE'
WITH CHECK OPTION;

-- Allowed: the row still satisfies status = 'ACTIVE'
START TRANSACTION;
UPDATE vw_active_accounts SET balance = balance + 500 WHERE account_no = 1001;
SELECT account_no, balance FROM accounts WHERE account_no = 1001;
ROLLBACK;

-- Rejected: the row would leave the view
UPDATE vw_active_accounts SET status = 'CLOSED' WHERE account_no = 1001;
-- ERROR 1369: CHECK OPTION failed 'bank_lab.vw_active_accounts'
```

Manage views

```sql
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW CREATE VIEW vw_branch_summary;

-- Change a definition in place
ALTER VIEW vw_branch_summary AS
SELECT b.branch_id, b.branch_name, b.city,
       COUNT(a.account_no)         AS accounts,
       COALESCE(SUM(a.balance), 0) AS total_balance,
       COALESCE(AVG(a.balance), 0) AS avg_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.city;
```

Limits to explain. Views with joins, GROUP BY, aggregates or DISTINCT are read-only. A view does not speed up a query; to store results physically, use a summary table refreshed on a schedule (MySQL has no native materialized views).


## 8. Stored procedures

A stored procedure is a named block of SQL and control logic stored in the database and run with CALL. Unlike a function it can take OUT parameters, return result sets, run DML, and control transactions.


|  | Function | Procedure |
| --- | --- | --- |
| Called with | Inside a query | CALL name(...) |
| Returns | One value | Result sets and OUT parameters |
| Transactions | Not allowed | Allowed |
| Used for | Calculations | Business operations such as a transfer |

```sql
DELIMITER //
CREATE PROCEDURE procedure_name ([IN | OUT | INOUT] param datatype, ...)
BEGIN
    DECLARE variable datatype [DEFAULT value];
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    -- statements, IF / CASE / WHILE / LOOP, transactions
END //
DELIMITER ;

CALL procedure_name(arguments);
DROP PROCEDURE IF EXISTS procedure_name;
```


| Parameter mode | Meaning |
| --- | --- |
| IN | Value passed in (default) |
| OUT | Value passed back to the caller |
| INOUT | Passed in, changed, and passed back |


### 8.1 A simple procedure with an IN parameter

```sql
DELIMITER //
CREATE PROCEDURE sp_customer_accounts (IN p_customer_id INT)
BEGIN
    SELECT a.account_no, a.account_type, a.balance, a.status, b.branch_name
    FROM accounts a
    JOIN branches b ON b.branch_id = a.branch_id
    WHERE a.customer_id = p_customer_id
    ORDER BY a.account_no;
END //
DELIMITER ;

CALL sp_customer_accounts(1);
```


### 8.2 OUT parameters and session variables

```sql
DELIMITER //
CREATE PROCEDURE sp_branch_stats (IN p_branch_id INT, OUT p_accounts INT, OUT p_total DECIMAL(14,2))
BEGIN
    SELECT COUNT(*), COALESCE(SUM(balance), 0)
    INTO p_accounts, p_total
    FROM accounts
    WHERE branch_id = p_branch_id;
END //
DELIMITER ;

CALL sp_branch_stats(2, @acc_count, @acc_total);
SELECT @acc_count AS accounts, @acc_total AS total_balance;   -- 2 accounts, 124000.00
```


### 8.3 Control flow: IF, CASE and WHILE

```sql
DELIMITER //
CREATE PROCEDURE sp_control_flow_demo (IN p_n INT)
BEGIN
    DECLARE v_i INT DEFAULT 1;
    DECLARE v_list VARCHAR(200) DEFAULT '';

    IF p_n < 1 THEN
        SELECT 'Please pass a number of 1 or more' AS message;
    ELSE
        WHILE v_i <= p_n DO
            SET v_list = CONCAT(v_list, v_i, CASE WHEN MOD(v_i, 2) = 0 THEN ' (even)' ELSE ' (odd)' END, '; ');
            SET v_i = v_i + 1;
        END WHILE;
        SELECT v_list AS numbers;
    END IF;
END //
DELIMITER ;

CALL sp_control_flow_demo(5);
CALL sp_control_flow_demo(0);
```


### 8.4 Validation and custom errors with SIGNAL

SIGNAL raises an error that stops the procedure. SQLSTATE '45000' means “user-defined error”.

```sql
DELIMITER //
CREATE PROCEDURE sp_deposit (IN p_account_no BIGINT, IN p_amount DECIMAL(12,2))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit amount must be positive';
    END IF;

    START TRANSACTION;

    UPDATE accounts SET balance = balance + p_amount
    WHERE account_no = p_account_no AND status = 'ACTIVE';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found or not active';
    END IF;

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_account_no, 'DEPOSIT', p_amount, NOW(), 'Deposit via sp_deposit');

    COMMIT;
END //
DELIMITER ;

CALL sp_deposit(1001, 2500.00);
SELECT account_no, balance FROM accounts WHERE account_no = 1001;   -- 54500.00

CALL sp_deposit(1001, -10);       -- ERROR 1644: Deposit amount must be positive
CALL sp_deposit(9999, 100);       -- ERROR 1644: Account not found or not active
CALL sp_deposit(1005, 100);       -- ERROR 1644: account 1005 is DORMANT
```


### 8.5 A transaction-safe fund transfer

This is the capstone procedure. It validates the request, locks the source row, moves the money, writes both ledger entries, and rolls everything back on any error.

```sql
DELIMITER //
CREATE PROCEDURE sp_transfer_funds (
    IN p_from_account BIGINT,
    IN p_to_account   BIGINT,
    IN p_amount       DECIMAL(12,2)
)
BEGIN
    DECLARE v_balance DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive';
    END IF;
    IF p_from_account = p_to_account THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Source and destination must differ';
    END IF;

    START TRANSACTION;

    -- Lock the source row so a parallel transfer cannot spend the same money
    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_no = p_from_account AND status = 'ACTIVE'
    FOR UPDATE;

    IF v_balance IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Source account not found or not active';
    END IF;
    IF v_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds';
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_no = p_from_account;

    UPDATE accounts SET balance = balance + p_amount
    WHERE account_no = p_to_account AND status = 'ACTIVE';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Destination account not found or not active';
    END IF;

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description) VALUES
    (p_from_account, 'TRANSFER_OUT', p_amount, NOW(), CONCAT('Transfer to ',   p_to_account)),
    (p_to_account,   'TRANSFER_IN',  p_amount, NOW(), CONCAT('Transfer from ', p_from_account));

    COMMIT;
END //
DELIMITER ;
```

Test it

```sql
-- Success: move 10000 from 1002 to 1001
SELECT account_no, balance FROM accounts WHERE account_no IN (1001, 1002);
CALL sp_transfer_funds(1002, 1001, 10000.00);
SELECT account_no, balance FROM accounts WHERE account_no IN (1001, 1002);
-- 1001 = 64500.00 (54500 + 10000), 1002 = 100000.00

-- Failures: each leaves all balances unchanged
CALL sp_transfer_funds(1004, 1001, 999999.00);   -- ERROR 1644: Insufficient funds
CALL sp_transfer_funds(1001, 1001, 100.00);      -- ERROR 1644: Source and destination must differ
CALL sp_transfer_funds(1001, 9999, 100.00);      -- ERROR 1644: Destination account not found or not active

-- Proof that failed transfers rolled back: balance of 1001 is still 64500.00
SELECT account_no, balance FROM accounts WHERE account_no = 1001;

-- Ledger entries written by the successful transfer
SELECT txn_id, account_no, txn_type, amount, description
FROM transactions
ORDER BY txn_id DESC
LIMIT 4;
```


### 8.6 Open an account and return the new number

```sql
DELIMITER //
CREATE PROCEDURE sp_open_account (
    IN  p_customer_id INT,
    IN  p_type        VARCHAR(20),
    IN  p_branch_id   INT,
    IN  p_opening     DECIMAL(12,2),
    OUT p_account_no  BIGINT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO accounts (customer_id, branch_id, account_type, balance, opened_on)
    VALUES (p_customer_id, p_branch_id, p_type, p_opening, CURDATE());

    SET p_account_no = LAST_INSERT_ID();

    IF p_opening > 0 THEN
        INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
        VALUES (p_account_no, 'DEPOSIT', p_opening, NOW(), 'Opening deposit');
    END IF;

    COMMIT;
END //
DELIMITER ;

-- Meera (customer 6) opens a savings account at the Ernakulam branch (6)
CALL sp_open_account(6, 'SAVINGS', 6, 5000.00, @new_account);
SELECT @new_account AS new_account_no;
SELECT * FROM accounts WHERE account_no = @new_account;
```


### 8.7 Manage procedures

```sql
SHOW PROCEDURE STATUS WHERE Db = 'bank_lab';
SHOW CREATE PROCEDURE sp_transfer_funds;
```

DROP PROCEDURE IF EXISTS procedure_name;

Good practice

Validate inputs first and fail with a clear SIGNAL message.

Wrap multi-statement changes in START TRANSACTION with an exit handler that rolls back.

Keep one business operation per procedure and name them with a prefix (sp_).

Grant EXECUTE on a procedure instead of table-level write access:

GRANT EXECUTE ON PROCEDURE bank_lab.sp_transfer_funds TO 'teller_user'@'%';


## 9. Hands-on lab and assessment

Complete these on the bank_lab database after Sections 2 to 8. The solutions follow. Because Section 8 changed some balances and added transactions and a new account, results here reflect that updated data.

Tasks


| # | Topic | Task |
| --- | --- | --- |
| 1 | Normalization | Explain which normal form bank_flat violates because of customer_phones, and which two because of branch_city and customer_city |
| 2 | Query | List each customer’s full name and total balance, highest first, including customers with no account (show 0) |
| 3 | Query | Show the top account by balance within each account type using a window function |
| 4 | Query | Find accounts whose average transaction amount is above 20000 |
| 5 | Join | List branches that have no active accounts |
| 6 | Join | For each branch, show its name, the number of customers who bank there, and its total balance |
| 7 | Function | Create fn_interest(balance, rate) returning yearly interest rounded to 2 decimals, and use it for all savings accounts at 4% |
| 8 | View | Create vw_dormant_accounts listing dormant accounts with owner name and branch |
| 9 | Procedure | Create sp_withdraw(account_no, amount) that rejects overdrafts, updates the balance and logs a WITHDRAWAL transaction inside a transaction |
| 10 | Clean up | Drop the lab database |

Task 1 answer (written). customer_phones holds several values in one cell, which breaks 1NF. customer_city depends only on the customer, not on the whole row key, which breaks 2NF. branch_city depends on branch_name, a non-key column, which breaks 3NF (transitive dependency).

Solutions

```sql
-- 2
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer,
       COALESCE(SUM(a.balance), 0) AS total_balance
FROM customers c
LEFT JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance DESC;

-- 3
SELECT account_type, account_no, balance
FROM (SELECT account_type, account_no, balance,
             ROW_NUMBER() OVER (PARTITION BY account_type ORDER BY balance DESC) AS rn
      FROM accounts) ranked
WHERE rn = 1;

-- 4
SELECT t.account_no, ROUND(AVG(t.amount), 2) AS avg_amount
FROM transactions t
GROUP BY t.account_no
HAVING AVG(t.amount) > 20000;

-- 5
SELECT b.branch_name
FROM branches b
WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.branch_id = b.branch_id AND a.status = 'ACTIVE');

-- 6
SELECT b.branch_name,
       COUNT(DISTINCT a.customer_id) AS customers,
       COALESCE(SUM(a.balance), 0)   AS total_balance
FROM branches b
LEFT JOIN accounts a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name
ORDER BY total_balance DESC;
```

```sql
-- 7
DELIMITER //
CREATE FUNCTION fn_interest (p_balance DECIMAL(14,2), p_rate DECIMAL(5,2))
RETURNS DECIMAL(14,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_balance * p_rate / 100, 2);
END //
DELIMITER ;

SELECT account_no, balance, fn_interest(balance, 4.00) AS yearly_interest
FROM accounts
WHERE account_type = 'SAVINGS';

-- 8
CREATE OR REPLACE VIEW vw_dormant_accounts AS
SELECT a.account_no, CONCAT(c.first_name, ' ', c.last_name) AS customer, b.branch_name, a.balance
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id
WHERE a.status = 'DORMANT';

SELECT * FROM vw_dormant_accounts;

-- 9
DELIMITER //
CREATE PROCEDURE sp_withdraw (IN p_account_no BIGINT, IN p_amount DECIMAL(12,2))
BEGIN
    DECLARE v_balance DECIMAL(12,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive';
    END IF;

    START TRANSACTION;

    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_no = p_account_no AND status = 'ACTIVE'
    FOR UPDATE;

    IF v_balance IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account not found or not active';
    END IF;
    IF v_balance < p_amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds';
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_no = p_account_no;
    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_account_no, 'WITHDRAWAL', p_amount, NOW(), 'Withdrawal via sp_withdraw');

    COMMIT;
END //
DELIMITER ;

CALL sp_withdraw(1006, 50000.00);
SELECT account_no, balance FROM accounts WHERE account_no = 1006;   -- 200000.00
CALL sp_withdraw(1004, 500000.00);                                   -- ERROR 1644: Insufficient funds
```

-- Reset / cleanup
DROP DATABASE IF EXISTS bank_lab;

Review questions

What is the difference between a primary key, a unique key and a foreign key?

A table stores order_id, product_id, product_name, quantity with key (order_id, product_id). Which normal form does it break, and how do you fix it?

```sql
Why can WHERE not use an alias defined in the SELECT list, while ORDER BY can?
```

What is the difference between WHERE and HAVING?

When would you pick a LEFT JOIN ... IS NULL over NOT EXISTS, and what is the risk of NOT IN?

Why does WHERE YEAR(txn_date) = 2025 perform worse than a date range?

Name two things a stored procedure can do that a function cannot.

A view joins three tables. Can you UPDATE through it? Why or why not?

```sql
Answers. (1) A primary key uniquely identifies a row and cannot be NULL (one per table); a unique key prevents duplicates but allows NULL (several per table); a foreign key points to a key in another table to enforce referential integrity. (2) 2NF: product_name depends only on product_id; move it to a products table. (3) WHERE is evaluated before SELECT, so the alias does not exist yet; ORDER BY runs after it. (4) WHERE filters rows before grouping; HAVING filters groups after aggregation. (5) They give the same result; NOT EXISTS states intent clearly and is safe with NULLs, while NOT IN returns nothing if the list contains a NULL. (6) The function is applied to every row, so an index on txn_date cannot be used. (7) Control transactions (START TRANSACTION, COMMIT, ROLLBACK), return result sets or OUT parameters, and run INSERT, UPDATE and DELETE freely. (8) Generally no; views based on joins, aggregates or DISTINCT are not updatable.
```


## 10. Quick reference and other databases

Query clause cheat sheet


| Need | Syntax |
| --- | --- |
| Filter rows | WHERE col = value |
| Filter groups | GROUP BY col HAVING SUM(x) > n |
| Conditional value | CASE WHEN ... THEN ... ELSE ... END |
| Rank rows | RANK() OVER (PARTITION BY a ORDER BY b DESC) |
| Named subquery | WITH name AS (SELECT ...) SELECT ... FROM name |
| Rows with no match | LEFT JOIN ... WHERE right.key IS NULL or NOT EXISTS |
| Create function | CREATE FUNCTION f(p INT) RETURNS INT DETERMINISTIC RETURN p * 2; |
| Create view | CREATE OR REPLACE VIEW v AS SELECT ...; |
| Create procedure | CREATE PROCEDURE sp(IN p INT) BEGIN ... END |
| Raise an error | SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'; |
| Execution plan | EXPLAIN SELECT ...; |

If the client’s lab uses Oracle or SQL Server. The concepts are identical; these are the syntax changes.


| Item | MySQL | Oracle (PL/SQL) | SQL Server (T-SQL) |
| --- | --- | --- | --- |
| First N rows | LIMIT 3 | FETCH FIRST 3 ROWS ONLY | SELECT TOP 3 ... |
| String concat | CONCAT(a, b) | a || b | a + b or CONCAT(a, b) |
| NULL default | COALESCE, IFNULL | COALESCE, NVL | COALESCE, ISNULL |
| Full outer join | Emulated with UNION | FULL OUTER JOIN | FULL OUTER JOIN |
| Set difference | EXCEPT (8.0.31+) | MINUS | EXCEPT |
| Function body | RETURNS type ... BEGIN ... RETURN x; END | RETURN type IS BEGIN ... RETURN x; END; | RETURNS type AS BEGIN ... RETURN x; END |
| Create procedure | CREATE PROCEDURE p (IN x INT) | CREATE PROCEDURE p (x IN NUMBER) AS BEGIN ... END; | CREATE PROCEDURE p @x INT AS BEGIN ... END |
| Raise an error | SIGNAL SQLSTATE '45000' | RAISE_APPLICATION_ERROR(-20001, 'msg') | THROW 50001, 'msg', 1; |
| Variables | DECLARE v INT; | v NUMBER; in the declare section | DECLARE @v INT; |
| Plan | EXPLAIN | EXPLAIN PLAN FOR | SET SHOWPLAN_ALL ON or the graphical plan |
| Materialized view | Not available | CREATE MATERIALIZED VIEW | Indexed view |

Trainer tips

Run the sections in order; Section 8 changes balances, so the expected numbers in Sections 4 to 7 refer to the data as loaded in Section 2.

To reset the lab, rerun the Section 2 scripts; the first statement drops and recreates bank_lab.

Ask participants to predict the row count before running each join, then compare.

Show EXPLAIN before and after adding an index to make join strategies concrete.

All scripts in this guide were run end to end on a MySQL-compatible server (MariaDB 10.11) with the expected errors noted above. Error text, EXPLAIN output and SHOW ... STATUS columns can look slightly different on MySQL 8.0, and EXPLAIN ANALYZE and INTERSECT/EXCEPT need a recent 8.0 release.
