Bank Database – DDL, DML & TCL Training Guide

Prepared for EY


## 1. Overview

This guide walks participants through building a Bank database with two related tables, customers and accounts, and practising the three core groups of SQL commands on it: DDL, DML and TCL. Every command is shown with its syntax, a worked query and the expected result.

Learning objectives. By the end, participants can:

Create a database and two related tables with primary keys, a foreign key and constraints

Change table structure with ALTER, and remove objects with TRUNCATE and DROP

Insert, read, update and delete rows

Group statements into transactions and control them with COMMIT, ROLLBACK and SAVEPOINT

SQL command categories covered


| Category | Full form | Purpose | Commands |
| --- | --- | --- | --- |
| DDL | Data Definition Language | Defines or changes structure | CREATE, ALTER, DROP, TRUNCATE, RENAME |
| DML | Data Manipulation Language | Works with the rows inside tables | INSERT, UPDATE, DELETE, SELECT |
| TCL | Transaction Control Language | Saves or undoes DML changes | START TRANSACTION, COMMIT, ROLLBACK, SAVEPOINT |

Dialect used. All examples run on MySQL 8.0 (InnoDB engine). Section 8 lists the small syntax differences for Oracle and SQL Server.

Scenario. A small retail bank keeps its customers in one table and the accounts they hold in another. One customer can hold many accounts; each account belongs to exactly one customer.


## 2. Lab setup

Participants need a running MySQL 8.0 server and any SQL client. Nothing else is required.

Prerequisites

MySQL Server 8.0 or later (local install, Docker, or a cloud instance)

A client: MySQL Workbench, DBeaver, or the mysql command-line tool

A user with permission to create databases (for example root in a training lab)

Option A: start MySQL in Docker (fastest for a classroom)

docker run --name bank-mysql -e MYSQL_ROOT_PASSWORD=Train@123 -p 3306:3306 -d mysql:8.0
docker exec -it bank-mysql mysql -uroot -pTrain@123

Option B: connect to an existing server

mysql -h <host> -P 3306 -u <user> -p

Check the connection

```sql
SELECT VERSION();
SHOW DATABASES;
```

Both statements should return results without an error. Every command in this guide ends with a semicolon ; and keywords are not case sensitive, though the convention is to write them in capitals.


## 3. Database design

The bank_db database holds two tables linked by customer_id: one customer has zero or more accounts.

customers (1) ----------------< (many) accounts
  customer_id (PK)                      account_no (PK)
                                        customer_id (FK -> customers.customer_id)

Table 1: customers


| Column | Data type | Constraint | Meaning |
| --- | --- | --- | --- |
| customer_id | INT | PRIMARY KEY, AUTO_INCREMENT | Unique customer number |
| first_name | VARCHAR(50) | NOT NULL | Given name |
| last_name | VARCHAR(50) | NOT NULL | Family name |
| email | VARCHAR(100) | UNIQUE | Contact email |
| phone | VARCHAR(15) |  | Mobile number |
| date_of_birth | DATE |  | Date of birth |
| city | VARCHAR(50) | DEFAULT ‘Bengaluru’ | City of residence |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Row creation time |

Table 2: accounts


| Column | Data type | Constraint | Meaning |
| --- | --- | --- | --- |
| account_no | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique account number |
| customer_id | INT | NOT NULL, FOREIGN KEY | Owner, references customers |
| account_type | VARCHAR(20) | NOT NULL, CHECK in (SAVINGS, CURRENT, SALARY) | Type of account |
| balance | DECIMAL(12,2) | NOT NULL, DEFAULT 0.00, CHECK (balance >= 0) | Current balance in INR |
| branch | VARCHAR(50) |  | Home branch |
| status | VARCHAR(10) | DEFAULT ‘ACTIVE’ | ACTIVE, DORMANT or CLOSED |
| opened_on | DATE | NOT NULL | Account opening date |

Why these choices. DECIMAL is used for money because FLOAT introduces rounding errors. The foreign key stops anyone creating an account for a customer who does not exist. The CHECK on balance blocks negative balances, which becomes useful in the transaction exercise.


## 4. DDL: Data Definition Language

DDL statements define and change the structure of the database. In MySQL each DDL statement commits automatically, so it cannot be rolled back.


### 4.1 CREATE DATABASE and USE

Syntax

CREATE DATABASE [IF NOT EXISTS] database_name;
USE database_name;

Query

CREATE DATABASE IF NOT EXISTS bank_db;
USE bank_db;
SHOW DATABASES;


### 4.2 CREATE TABLE

Syntax

```sql
CREATE TABLE table_name (
    column1  datatype  [constraints],
    column2  datatype  [constraints],
    ...
    [table_level_constraints]
);
```

Query 1: parent table customers (create the parent before the child)

```sql
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
```

Query 2: child table accounts (linked to customers by a foreign key)

```sql
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
```

Note. ON DELETE RESTRICT blocks deleting a customer who still has accounts. CHECK constraints are enforced from MySQL 8.0.16 onwards; on older versions they are accepted but ignored.

Verify the structure

```sql
SHOW TABLES;
DESCRIBE customers;
DESCRIBE accounts;
SHOW CREATE TABLE accounts;
```


### 4.3 ALTER TABLE

Changes the structure of an existing table.

Syntax

```sql
ALTER TABLE table_name ADD COLUMN column_name datatype [constraints];
ALTER TABLE table_name MODIFY COLUMN column_name new_datatype;
ALTER TABLE table_name CHANGE COLUMN old_name new_name datatype;
ALTER TABLE table_name DROP COLUMN column_name;
ALTER TABLE table_name ADD CONSTRAINT constraint_name constraint_definition;
ALTER TABLE table_name DROP CONSTRAINT constraint_name;
```

Queries

```sql
-- Add a column (kept permanently; used in later DML examples)
ALTER TABLE customers ADD COLUMN kyc_status VARCHAR(10) DEFAULT 'PENDING';

-- Widen a column
ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);

-- Add, rename and drop a temporary column
ALTER TABLE accounts ADD COLUMN nominee_name VARCHAR(50);
ALTER TABLE accounts CHANGE COLUMN nominee_name nominee VARCHAR(50);
ALTER TABLE accounts DROP COLUMN nominee;

-- Add a constraint after the table exists
ALTER TABLE accounts
    ADD CONSTRAINT chk_status CHECK (status IN ('ACTIVE','DORMANT','CLOSED'));
```


### 4.4 CREATE INDEX

Syntax and query

CREATE INDEX index_name ON table_name (column_name);

CREATE INDEX idx_customers_city ON customers (city);
SHOW INDEX FROM customers;


### 4.5 RENAME, TRUNCATE and DROP

To avoid destroying the bank tables, practise these three on a scratch table.

Syntax

RENAME TABLE old_name TO new_name;
TRUNCATE TABLE table_name;           -- removes all rows, keeps the structure
DROP TABLE [IF EXISTS] table_name;   -- removes rows and structure
DROP DATABASE [IF EXISTS] database_name;

Queries

```sql
CREATE TABLE demo_log (id INT PRIMARY KEY, note VARCHAR(50));
INSERT INTO demo_log VALUES (1, 'first'), (2, 'second');

RENAME TABLE demo_log TO audit_log;
TRUNCATE TABLE audit_log;         -- table is now empty, structure remains
SELECT COUNT(*) FROM audit_log;   -- returns 0
DROP TABLE audit_log;             -- table no longer exists
```

Key differences to explain


| Command | Removes | Can use WHERE | Rolls back in MySQL | Resets AUTO_INCREMENT |
| --- | --- | --- | --- | --- |
| DELETE (DML) | Selected rows | Yes | Yes | No |
| TRUNCATE (DDL) | All rows | No | No | Yes |
| DROP (DDL) | Rows and the table itself | No | No | Not applicable |

Restriction. MySQL will not truncate or drop a parent table while a foreign key references it. Drop accounts before customers, or disable checks temporarily with SET FOREIGN_KEY_CHECKS = 0; (re-enable with 1).


## 5. DML: Data Manipulation Language

DML statements add, read, change and remove the rows inside tables. Unlike DDL, DML changes can be rolled back when they run inside a transaction (Section 6).


### 5.1 INSERT

Syntax

```sql
INSERT INTO table_name (col1, col2, ...) VALUES (val1, val2, ...);
INSERT INTO table_name (col1, col2, ...) VALUES (...), (...), (...);   -- several rows
```

Query 1: one customer. customer_id is omitted because AUTO_INCREMENT fills it in.

```sql
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city)
VALUES ('Arjun', 'Mehta', 'arjun.mehta@example.com', '9876500001', '1990-04-12', 'Bengaluru');
```

Query 2: several customers in one statement

```sql
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city) VALUES
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi');
```

On a freshly created table these five rows receive customer_id 1 to 5 in order.

Query 3: accounts. Here account_no is supplied explicitly. status takes its default, ACTIVE.

```sql
INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on) VALUES
(1001, 1, 'SAVINGS',  50000.00, 'Indiranagar',     '2022-03-15'),
(1002, 1, 'CURRENT', 120000.00, 'Indiranagar',     '2023-01-10'),
(1003, 2, 'SAVINGS',  75000.00, 'T Nagar',         '2021-06-20'),
(1004, 3, 'SALARY',   32000.00, 'Andheri',         '2024-02-01'),
(1005, 4, 'SAVINGS',  15000.00, 'Madhapur',        '2023-09-12'),
(1006, 5, 'CURRENT', 250000.00, 'Connaught Place', '2020-12-05'),
(1007, 2, 'SALARY',   45000.00, 'T Nagar',         '2024-05-18');
```

Inserts that must fail. Run each one so participants see the constraints working.

```sql
-- 1. Customer 99 does not exist (foreign key)
INSERT INTO accounts (account_no, customer_id, account_type, balance, opened_on)
VALUES (1008, 99, 'SAVINGS', 1000, '2025-01-01');
-- ERROR 1452: Cannot add or update a child row: a foreign key constraint fails

-- 2. Duplicate email (UNIQUE)
INSERT INTO customers (first_name, last_name, email)
VALUES ('Dup', 'User', 'arjun.mehta@example.com');
-- ERROR 1062: Duplicate entry 'arjun.mehta@example.com' for key 'customers.email'

-- 3. Negative balance (CHECK)
INSERT INTO accounts (account_no, customer_id, account_type, balance, opened_on)
VALUES (1009, 1, 'SAVINGS', -500, '2025-01-01');
-- ERROR 3819: Check constraint 'chk_balance' is violated
```


### 5.2 SELECT

Syntax

```sql
SELECT column_list | *
FROM table_name
[WHERE condition]
[GROUP BY column_list]
[HAVING group_condition]
[ORDER BY column [ASC | DESC]]
[LIMIT n];
```

Queries

```sql
-- All rows and all columns
SELECT * FROM customers;

-- Chosen columns with an alias
SELECT first_name, last_name AS surname, city FROM customers;

-- Filter rows
SELECT * FROM accounts WHERE account_type = 'SAVINGS' AND balance > 20000;

-- Pattern, list and range filters
SELECT * FROM customers WHERE first_name LIKE 'P%';
SELECT * FROM customers WHERE city IN ('Mumbai', 'Delhi');
SELECT * FROM accounts  WHERE balance BETWEEN 30000 AND 100000;

-- Sort and limit: top 3 balances
SELECT account_no, balance FROM accounts ORDER BY balance DESC LIMIT 3;

-- Aggregate with GROUP BY
SELECT account_type, COUNT(*) AS total_accounts, SUM(balance) AS total_balance
FROM accounts
GROUP BY account_type;

-- Filter groups with HAVING
SELECT customer_id, COUNT(*) AS accounts_held
FROM accounts
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Join the two tables
SELECT c.customer_id, c.first_name, c.last_name, a.account_no, a.account_type, a.balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_no;
```

Expected result of the GROUP BY query (before the interest update below)


| account_type | total_accounts | total_balance |
| --- | --- | --- |
| SAVINGS | 3 | 140000.00 |
| CURRENT | 2 | 370000.00 |
| SALARY | 2 | 77000.00 |

The HAVING query returns customers 1 and 2, each holding two accounts.


### 5.3 UPDATE

Syntax

UPDATE table_name
SET column1 = value1, column2 = value2, ...
[WHERE condition];

Always include a WHERE clause. Without it, every row in the table changes. MySQL Workbench’s safe-update mode blocks such statements by default.

Queries

```sql
-- Change one column of one row
UPDATE customers SET city = 'Pune' WHERE customer_id = 3;

-- Change several columns
UPDATE customers
SET phone = '9988776655', email = 'priya.n@example.com'
WHERE customer_id = 2;

-- Update many rows: verify customers 1 to 4
UPDATE customers SET kyc_status = 'VERIFIED' WHERE customer_id IN (1, 2, 3, 4);

-- Calculated update: credit 4% interest to every savings account
UPDATE accounts SET balance = balance * 1.04 WHERE account_type = 'SAVINGS';

-- Check the result
SELECT account_no, account_type, balance FROM accounts WHERE account_type = 'SAVINGS';
```

After the interest update the savings balances are: account 1001 = 52000.00, 1003 = 78000.00, 1005 = 15600.00.


### 5.4 DELETE

Syntax

DELETE FROM table_name [WHERE condition];

Queries

```sql
-- Blocked by the foreign key: customer 5 still has account 1006
DELETE FROM customers WHERE customer_id = 5;
-- ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails

-- Create and remove a customer with no accounts
INSERT INTO customers (first_name, last_name, email)
VALUES ('Test', 'User', 'test.user@example.com');
DELETE FROM customers WHERE email = 'test.user@example.com';

-- Create and remove a closed, empty account
INSERT INTO accounts (account_no, customer_id, account_type, balance, opened_on, status)
VALUES (1008, 5, 'SAVINGS', 0.00, '2025-01-01', 'CLOSED');
DELETE FROM accounts WHERE status = 'CLOSED' AND balance = 0;

-- Confirm
SELECT COUNT(*) AS customers FROM customers;   -- 5
SELECT COUNT(*) AS accounts  FROM accounts;    -- 7
```

```sql
Rule of thumb. Run the matching SELECT ... WHERE first to preview which rows an UPDATE or DELETE will touch, then run the change.
```


## 6. TCL: Transaction Control Language

A transaction is a group of statements that succeeds or fails as one unit. Banking is the classic case: a transfer must debit one account and credit another, or do neither. TCL commands control when DML changes become permanent.

Syntax

```sql
BEGIN;          -- or BEGIN;  starts a transaction
COMMIT;                     -- makes all changes permanent
ROLLBACK;                   -- undoes all changes since START TRANSACTION
SAVEPOINT savepoint_name;   -- marks a point inside the transaction
ROLLBACK TO SAVEPOINT savepoint_name;   -- undoes changes back to that point
RELEASE SAVEPOINT savepoint_name;       -- removes a savepoint
```

Before you start

Tables must use the InnoDB engine (the default, and what Section 4 created). MyISAM does not support transactions.

```sql
MySQL runs in autocommit mode by default, so each statement commits on its own. START TRANSACTION temporarily switches this off until COMMIT or ROLLBACK. Check the setting with SELECT @@autocommit;.
```

DDL statements (CREATE, ALTER, DROP, TRUNCATE) cause an implicit commit, so do not mix them into a transaction you may want to roll back.

The four ACID properties a transaction guarantees


| Property | Meaning |
| --- | --- |
| Atomicity | All statements take effect, or none do |
| Consistency | Constraints (keys, CHECK) hold before and after |
| Isolation | Other sessions do not see uncommitted changes |
| Durability | Committed changes survive a crash |


### 6.1 COMMIT: a successful fund transfer

Transfer ₹10,000 from account 1002 to account 1001.

```sql
SELECT account_no, balance FROM accounts WHERE account_no IN (1001, 1002);
-- 1001 = 52000.00, 1002 = 120000.00

BEGIN;

UPDATE accounts SET balance = balance - 10000 WHERE account_no = 1002;   -- debit
UPDATE accounts SET balance = balance + 10000 WHERE account_no = 1001;   -- credit

COMMIT;

SELECT account_no, balance FROM accounts WHERE account_no IN (1001, 1002);
-- 1001 = 62000.00, 1002 = 110000.00
```


### 6.2 ROLLBACK: undoing a mistake

A delete is run by mistake, checked, and undone.

```sql
SELECT COUNT(*) FROM accounts;                 -- 7

BEGIN;
DELETE FROM accounts WHERE account_type = 'SALARY';
SELECT COUNT(*) FROM accounts;                 -- 5  (visible only in this session)
ROLLBACK;

SELECT COUNT(*) FROM accounts;                 -- 7  (restored)
```


### 6.3 ROLLBACK after an error: a failed transfer

Account 1004 holds ₹32,000. A transfer of ₹50,000 breaks the chk_balance rule, so the debit fails.

```sql
BEGIN;

UPDATE accounts SET balance = balance - 50000 WHERE account_no = 1004;
-- ERROR 3819: Check constraint 'chk_balance' is violated

ROLLBACK;     -- the credit statement is never run, and nothing is left half-done
```

Note. In MySQL a failed statement undoes only itself. The transaction stays open until you issue COMMIT or ROLLBACK, so the application must check for the error and roll back.


### 6.4 SAVEPOINT: partial rollback

A clerk debits account 1004, credits the wrong account, then corrects only that step.

```sql
BEGIN;

UPDATE accounts SET balance = balance - 1000 WHERE account_no = 1004;   -- debit
SAVEPOINT after_debit;

UPDATE accounts SET balance = balance + 1000 WHERE account_no = 1005;   -- wrong account
ROLLBACK TO SAVEPOINT after_debit;          -- undo only the wrong credit

UPDATE accounts SET balance = balance + 1000 WHERE account_no = 1007;   -- correct account
COMMIT;

SELECT account_no, balance FROM accounts WHERE account_no IN (1004, 1005, 1007);
```

Expected result


| account_no | balance |
| --- | --- |
| 1004 | 31000.00 |
| 1005 | 15600.00 |
| 1007 | 46000.00 |

The debit survived the partial rollback, account 1005 is unchanged, and the credit landed on 1007.


### 6.5 Seeing isolation with two sessions (optional demo)

Open two client windows connected to bank_db.


| Step | Session A | Session B |
| --- | --- | --- |
| 1 | START TRANSACTION; |  |
| 2 | UPDATE accounts SET balance = 0 WHERE account_no = 1006; |  |
| 3 |  | SELECT balance FROM accounts WHERE account_no = 1006; shows the old value, 250000.00 |
| 4 | ROLLBACK; |  |
| 5 |  | The same SELECT still shows 250000.00 |

If Session A had run COMMIT at step 4, Session B would see 0.00 from then on.


## 7. Hands-on lab and assessment

Participants complete these tasks after Sections 4 to 6, then compare with the solutions.

Tasks


| # | Type | Task |
| --- | --- | --- |
| 1 | DDL | Add a column ifsc_code VARCHAR(11) to accounts, then drop it |
| 2 | DML | Add a customer, Meera Iyer from Kochi, and give her a CURRENT account (no. 1008) with ₹5,000 opened today |
| 3 | DML | List customers living in Hyderabad or Mumbai |
| 4 | DML | Show each customer’s full name and the total balance across all their accounts, highest first |
| 5 | DML | Mark account 1005 as DORMANT |
| 6 | TCL | Transfer ₹5,000 from account 1006 to 1003 and make it permanent |
| 7 | TCL | Attempt to transfer ₹300,000 from account 1006 to 1003 and undo it when the debit fails |
| 8 | DDL | Clean up: drop both tables and the database in the correct order |

Solutions

```sql
-- 1
ALTER TABLE accounts ADD COLUMN ifsc_code VARCHAR(11);
ALTER TABLE accounts DROP COLUMN ifsc_code;

-- 2  (LAST_INSERT_ID() returns the customer_id just generated)
INSERT INTO customers (first_name, last_name, email, city)
VALUES ('Meera', 'Iyer', 'meera.iyer@example.com', 'Kochi');

INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on)
VALUES (1008, LAST_INSERT_ID(), 'CURRENT', 5000.00, 'Ernakulam', CURRENT_DATE);

-- 3
SELECT * FROM customers WHERE city IN ('Hyderabad', 'Mumbai');

-- 4
SELECT c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       SUM(a.balance) AS total_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance DESC;

-- 5
UPDATE accounts SET status = 'DORMANT' WHERE account_no = 1005;

-- 6
BEGIN;
UPDATE accounts SET balance = balance - 5000 WHERE account_no = 1006;
UPDATE accounts SET balance = balance + 5000 WHERE account_no = 1003;
COMMIT;

-- 7
BEGIN;
UPDATE accounts SET balance = balance - 300000 WHERE account_no = 1006;
-- ERROR 3819: Check constraint 'chk_balance' is violated
ROLLBACK;

-- 8  (child table first, because of the foreign key)
DROP TABLE accounts;
DROP TABLE customers;
DROP DATABASE bank_db;
```

Review questions

Which command group does TRUNCATE belong to, and why can it not be rolled back in MySQL?

What is the difference between DELETE FROM accounts; and TRUNCATE TABLE accounts;?

Why must customers be created before accounts?

What happens if you run UPDATE accounts SET balance = 0; without a WHERE clause?

After START TRANSACTION and two UPDATE statements, you close the client without COMMIT. Are the changes saved?

What does ROLLBACK TO SAVEPOINT x undo, and does the transaction stay open afterwards?

```sql
Answers. (1) DDL; MySQL commits implicitly after every DDL statement. (2) DELETE is DML, removes rows one by one, accepts WHERE and can be rolled back; TRUNCATE is DDL, empties the whole table at once and resets AUTO_INCREMENT. (3) The foreign key in accounts must reference an existing table. (4) Every account balance becomes 0, which is why a WHERE clause and a preview SELECT matter. (5) No, an uncommitted transaction is rolled back when the session ends. (6) It undoes only the changes made after that savepoint, and the transaction remains open until COMMIT or ROLLBACK.
```


## 8. Quick reference and other databases

Command cheat sheet (MySQL)


| Task | Command |
| --- | --- |
| Create database | CREATE DATABASE bank_db; |
| Create table | CREATE TABLE t (id INT PRIMARY KEY, ...); |
| Add / change / drop column | ALTER TABLE t ADD COLUMN c INT; / MODIFY COLUMN / DROP COLUMN |
| Empty / remove table | TRUNCATE TABLE t; / DROP TABLE t; |
| Insert rows | INSERT INTO t (c1, c2) VALUES (v1, v2); |
| Read rows | SELECT c1, c2 FROM t WHERE ... ORDER BY ... LIMIT n; |
| Change rows | UPDATE t SET c1 = v WHERE ...; |
| Delete rows | DELETE FROM t WHERE ...; |
| Begin / save / undo | START TRANSACTION; / COMMIT; / ROLLBACK; |
| Partial undo | SAVEPOINT s; then ROLLBACK TO SAVEPOINT s; |

If the client’s lab uses Oracle or SQL Server. The concepts are identical; these are the syntax changes.


| Item | MySQL | Oracle | SQL Server |
| --- | --- | --- | --- |
| Auto-numbering | AUTO_INCREMENT | GENERATED ALWAYS AS IDENTITY (12c+) | IDENTITY(1,1) |
| Text / number types | VARCHAR, DECIMAL(12,2) | VARCHAR2, NUMBER(12,2) | VARCHAR, DECIMAL(12,2) |
| Current date | CURDATE() | SYSDATE | GETDATE() |
| First N rows | LIMIT 3 | FETCH FIRST 3 ROWS ONLY | SELECT TOP 3 ... |
| Rename table | RENAME TABLE a TO b; | RENAME a TO b; | EXEC sp_rename 'a', 'b'; |
| Start transaction | START TRANSACTION; | Starts automatically with the first DML | BEGIN TRANSACTION; |
| Savepoint | SAVEPOINT s; | SAVEPOINT s; | SAVE TRANSACTION s; |
| Partial rollback | ROLLBACK TO SAVEPOINT s; | ROLLBACK TO SAVEPOINT s; | ROLLBACK TRANSACTION s; |
| DDL inside a transaction | Commits implicitly | Commits implicitly | Can be rolled back |

Trainer tips

Run every statement live in the order shown; the later examples depend on the earlier data.

To reset the lab at any point, run Task 8, then repeat Sections 4 and 5.1.

Ask participants to predict each result before pressing run.
