# 🏦 PostgreSQL Bank Database — DDL, DML & TCL Training Guide

> **Prepared for**: EY Technology Onboarding & Training  
> **Source Repository**: [Msocial123/EY-AI-Training](https://github.com/Msocial123/EY-AI-Training.git)  
> **Target RDBMS**: **PostgreSQL 16+** (Complete conversion from MySQL 8.0)  
> **Core Concepts**: Relational Database Design, Constraints, CRUD (DML), Schema Migration (DDL), ACID Transactions (TCL)

---

## 📌 Table of Contents
1. [Architecture & Schema Design](#-architecture--schema-design)
2. [MySQL vs. PostgreSQL Syntax Conversion Guide](#-mysql-vs-postgresql-syntax-conversion-guide)
3. [Repository Structure](#-repository-structure)
4. [Quick Start & Setup](#-quick-start--setup)
5. [Module 1: DDL (Data Definition Language)](#-module-1-ddl-data-definition-language)
6. [Module 2: DML (Data Manipulation Language)](#-module-2-dml-data-manipulation-language)
7. [Module 3: TCL (Transaction Control Language)](#-module-3-tcl-transaction-control-language)
8. [Module 4: Hands-on Lab Assessment & Solutions](#-module-4-hands-on-lab-assessment--solutions)
9. [Interview & Trainer Q&A](#-interview--trainer-qa)

---

## 🏗️ Architecture & Schema Design

The `bank_db` database models a retail banking core system with two related tables linked by `customer_id`:

```
┌─────────────────────────────────┐                 ┌─────────────────────────────────┐
│        customers (Parent)       │                 │         accounts (Child)        │
├─────────────────────────────────┤                 ├─────────────────────────────────┤
│ customer_id   SERIAL [PK]       │◄───(1 : Many)───┤ account_no    BIGSERIAL [PK]    │
│ first_name    VARCHAR(50)       │                 │ customer_id   INT [FK]          │
│ last_name     VARCHAR(50)       │                 │ account_type  VARCHAR(20) [CHK] │
│ email         VARCHAR(100) [UQ] │                 │ balance       DECIMAL(12,2)[CHK]│
│ phone         VARCHAR(20)       │                 │ branch        VARCHAR(50)       │
│ date_of_birth DATE              │                 │ status        VARCHAR(10) [CHK] │
│ city          VARCHAR(50)       │                 │ opened_on     DATE              │
│ created_at    TIMESTAMP         │                 └─────────────────────────────────┘
│ kyc_status    VARCHAR(10)       │
└─────────────────────────────────┘
```

### Table 1: `customers`
* **`customer_id`**: Auto-incrementing unique integer (Primary Key).
* **`email`**: Unique constraint to prevent duplicate customer profiles.
* **`city`**: Defaults to `'Bengaluru'`.
* **`kyc_status`**: Added via `ALTER TABLE`, defaults to `'PENDING'`.

### Table 2: `accounts`
* **`account_no`**: 64-bit auto-incrementing integer (Primary Key).
* **`customer_id`**: Foreign Key referencing `customers(customer_id)` with `ON UPDATE CASCADE ON DELETE RESTRICT`.
* **`account_type`**: Restricted via `CHECK` to `('SAVINGS', 'CURRENT', 'SALARY')`.
* **`balance`**: Enforces strict `CHECK (balance >= 0)` (avoids overdraft corruption).
* **`status`**: Restricted to `('ACTIVE', 'DORMANT', 'CLOSED')`.

---

## 🔄 MySQL vs. PostgreSQL Syntax Conversion Guide

| Feature / Command | MySQL 8.0 (Original Guide) | PostgreSQL 16 (Converted) | Why the Difference? |
| :--- | :--- | :--- | :--- |
| **Auto-Increment PK** | `INT AUTO_INCREMENT PRIMARY KEY` | `SERIAL PRIMARY KEY` | PostgreSQL uses sequence-backed pseudo-types (`SERIAL` / `BIGSERIAL`). |
| **Storage Engine** | `ENGINE = InnoDB;` | *Omitted entirely* | PostgreSQL is natively ACID-compliant and does not use pluggable storage engines. |
| **Current Date** | `CURDATE()` | `CURRENT_DATE` | PostgreSQL follows ANSI SQL standard naming for date functions. |
| **Last Inserted ID** | `LAST_INSERT_ID()` | `RETURNING customer_id` or `currval(...)` | PostgreSQL `RETURNING` clause is atomic and prevents race conditions across sessions. |
| **Modify Column Type** | `ALTER TABLE t MODIFY COLUMN c VARCHAR(20);` | `ALTER TABLE t ALTER COLUMN c TYPE VARCHAR(20);` | PostgreSQL uses standard `ALTER COLUMN ... TYPE` syntax. |
| **Rename Column** | `ALTER TABLE t CHANGE COLUMN old new VARCHAR(50);` | `ALTER TABLE t RENAME COLUMN old TO new;` | PostgreSQL separates renaming from altering column types. |
| **Rename Table** | `RENAME TABLE old_t TO new_t;` | `ALTER TABLE old_t RENAME TO new_t;` | PostgreSQL uses standard `ALTER TABLE ... RENAME TO`. |
| **List Tables (CLI)** | `SHOW TABLES;` | `\dt` | `psql` uses backslash meta-commands. |
| **Describe Schema (CLI)** | `DESCRIBE table_name;` | `\d table_name` | Shows column details, default sequences, constraints, and indexes. |
| **String Concatenation** | `CONCAT(a, ' ', b)` | `a \|\| ' ' \|\| b` or `CONCAT(a, ' ', b)` | PostgreSQL supports both standard ANSI `\|\|` pipe operator and `CONCAT()`. |
| **Case-Insensitive Search** | `LIKE 'p%'` (case-insensitive by default) | `ILIKE 'p%'` | PostgreSQL `LIKE` is strictly case-sensitive; `ILIKE` is case-insensitive. |
| **Transactional DDL** | DDL commits implicitly (cannot be rolled back) | **DDL can be rolled back!** | PostgreSQL supports atomic schema migrations inside `BEGIN ... ROLLBACK`. |

---

## 📂 Repository Structure

```text
ey-postgresql-bank-database/
├── README.md                          # Full guide & conversion reference
├── docker-compose.yml                 # 1-Click PostgreSQL 16 + pgAdmin 4 stack
├── test_scripts.py                    # Automated test & syntax validation script
├── docs/                              # Original training documents
│   ├── Bank_Database_DDL_DML_TCL_Training_Guide.docx
│   └── Bank_Database_DDL_DML_TCL_Training_Guide.pdf
└── scripts/                           # Converted PostgreSQL SQL scripts
    ├── 01_schema_ddl.sql              # Module 1: DDL Table Creation, Alter, Index
    ├── 02_data_dml.sql                # Module 2: DML Inserts, Queries, Joins, Updates
    ├── 03_transactions_tcl.sql        # Module 3: TCL Commit, Rollback, Savepoints
    ├── 04_lab_assessment.sql          # Module 4: Tasks 1 through 8 with Solutions
    └── all_in_one_bank_db.sql         # Master runnable script (Runs entire lab)
```

---

## 🚀 Quick Start & Setup

### Option A: 1-Click Docker Setup (Recommended)
Launch PostgreSQL and pgAdmin together with all scripts pre-loaded:
```bash
docker compose up -d
```
* **PostgreSQL Port**: `localhost:5432` (User: `postgres`, Password: `postgres123`, DB: `bank_db`)
* **pgAdmin 4 Web UI**: Open **[http://localhost:5050](http://localhost:5050)** (Login: `admin@bank.com` / `admin123`)

### Option B: Local Command Line (`psql`)
Connect to your local PostgreSQL server:
```bash
psql -U postgres
```
Create and connect to the database:
```sql
CREATE DATABASE bank_db;
\c bank_db
```
Execute the master script:
```sql
\i scripts/all_in_one_bank_db.sql
```

---

## 🛠️ Module 1: DDL (Data Definition Language)

**File**: [`scripts/01_schema_ddl.sql`](scripts/01_schema_ddl.sql)

### 1. Create Tables
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

### 2. Modifying Tables (ALTER)
```sql
-- Add KYC status
ALTER TABLE customers ADD COLUMN kyc_status VARCHAR(10) DEFAULT 'PENDING';

-- Widen phone column
ALTER TABLE customers ALTER COLUMN phone TYPE VARCHAR(20);

-- Add check constraint for account status
ALTER TABLE accounts ADD CONSTRAINT chk_status CHECK (status IN ('ACTIVE','DORMANT','CLOSED'));

-- Create index for faster city queries
CREATE INDEX idx_customers_city ON customers (city);
```

---

## 📊 Module 2: DML (Data Manipulation Language)

**File**: [`scripts/02_data_dml.sql`](scripts/02_data_dml.sql)

### 1. Insert Seed Data
```sql
INSERT INTO customers (first_name, last_name, email, phone, date_of_birth, city) VALUES
('Arjun',  'Mehta',  'arjun.mehta@example.com',  '9876500001', '1990-04-12', 'Bengaluru'),
('Priya',  'Nair',   'priya.nair@example.com',   '9876500002', '1988-09-23', 'Chennai'),
('Rahul',  'Sharma', 'rahul.sharma@example.com', '9876500003', '1995-01-30', 'Mumbai'),
('Sneha',  'Reddy',  'sneha.reddy@example.com',  '9876500004', '1992-07-18', 'Hyderabad'),
('Vikram', 'Singh',  'vikram.singh@example.com', '9876500005', '1985-11-05', 'Delhi');

INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on) VALUES
(1001, 1, 'SAVINGS',  50000.00, 'Indiranagar',     '2022-03-15'),
(1002, 1, 'CURRENT', 120000.00, 'Indiranagar',     '2023-01-10'),
(1003, 2, 'SAVINGS',  75000.00, 'T Nagar',         '2021-06-20'),
(1004, 3, 'SALARY',   32000.00, 'Andheri',         '2024-02-01'),
(1005, 4, 'SAVINGS',  15000.00, 'Madhapur',        '2023-09-12'),
(1006, 5, 'CURRENT', 250000.00, 'Connaught Place', '2020-12-05'),
(1007, 2, 'SALARY',   45000.00, 'T Nagar',         '2024-05-18');
```

### 2. Multi-Table Relational JOIN Query
```sql
SELECT c.customer_id, 
       c.first_name || ' ' || c.last_name AS customer_name, 
       a.account_no, 
       a.account_type, 
       a.balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_no;
```

### 3. Aggregations (GROUP BY & HAVING)
```sql
-- Total balance per account type
SELECT account_type, COUNT(*) AS total_accounts, SUM(balance) AS total_balance
FROM accounts
GROUP BY account_type;

-- Find customers holding more than 1 account
SELECT customer_id, COUNT(*) AS accounts_held
FROM accounts
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

---

## 🔒 Module 3: TCL (Transaction Control Language)

**File**: [`scripts/03_transactions_tcl.sql`](scripts/03_transactions_tcl.sql)

### 1. Bank Fund Transfer with `COMMIT`
```sql
BEGIN;

-- Debit ₹10,000 from account 1002
UPDATE accounts SET balance = balance - 10000 WHERE account_no = 1002;

-- Credit ₹10,000 to account 1001
UPDATE accounts SET balance = balance + 10000 WHERE account_no = 1001;

COMMIT;
```

### 2. Partial Rollback with `SAVEPOINT`
```sql
BEGIN;

-- 1. Debit ₹1,000 from account 1004
UPDATE accounts SET balance = balance - 1000 WHERE account_no = 1004;

-- 2. Mark savepoint
SAVEPOINT after_debit;

-- 3. Accidental credit to wrong account (1005)
UPDATE accounts SET balance = balance + 1000 WHERE account_no = 1005;

-- 4. Revert only the mistake
ROLLBACK TO SAVEPOINT after_debit;

-- 5. Credit correct account (1007)
UPDATE accounts SET balance = balance + 1000 WHERE account_no = 1007;

COMMIT;
```

---

## 🎯 Module 4: Hands-on Lab Assessment & Solutions

**File**: [`scripts/04_lab_assessment.sql`](scripts/04_lab_assessment.sql)

| # | Type | Task | PostgreSQL Solution |
| :--- | :--- | :--- | :--- |
| **1** | DDL | Add column `ifsc_code VARCHAR(11)` to accounts, then drop it | `ALTER TABLE accounts ADD COLUMN ifsc_code VARCHAR(11);`<br>`ALTER TABLE accounts DROP COLUMN ifsc_code;` |
| **2** | DML | Add customer Meera Iyer from Kochi, give her a CURRENT account (1008) with ₹5,000 opened today | `WITH new_cust AS (`<br>`  INSERT INTO customers (first_name, last_name, email, city)`<br>`  VALUES ('Meera', 'Iyer', 'meera.iyer@example.com', 'Kochi')`<br>`  RETURNING customer_id`<br>`)`<br>`INSERT INTO accounts (account_no, customer_id, account_type, balance, branch, opened_on)`<br>`SELECT 1008, customer_id, 'CURRENT', 5000.00, 'Ernakulam', CURRENT_DATE FROM new_cust;` |
| **3** | DML | List customers living in Hyderabad or Mumbai | `SELECT * FROM customers WHERE city IN ('Hyderabad', 'Mumbai');` |
| **4** | DML | Show each customer's full name and total balance across all their accounts, highest first | `SELECT c.customer_id, c.first_name \|\| ' ' \|\| c.last_name AS customer, SUM(a.balance) AS total_balance`<br>`FROM customers c JOIN accounts a ON a.customer_id = c.customer_id`<br>`GROUP BY c.customer_id, c.first_name, c.last_name ORDER BY total_balance DESC;` |
| **5** | DML | Mark account 1005 as DORMANT | `UPDATE accounts SET status = 'DORMANT' WHERE account_no = 1005;` |
| **6** | TCL | Transfer ₹5,000 from account 1006 to 1003 and make it permanent | `BEGIN;`<br>`UPDATE accounts SET balance = balance - 5000 WHERE account_no = 1006;`<br>`UPDATE accounts SET balance = balance + 5000 WHERE account_no = 1003;`<br>`COMMIT;` |
| **7** | TCL | Attempt to transfer ₹300,000 from account 1006 to 1003 and undo when debit fails | `BEGIN;`<br>`UPDATE accounts SET balance = balance - 300000 WHERE account_no = 1006;`<br>`-- Violates chk_balance constraint`<br>`ROLLBACK;` |
| **8** | DDL | Clean up: drop both tables in relational order | `DROP TABLE accounts;`<br>`DROP TABLE customers;` |

---

## 💡 Interview & Trainer Q&A

### Q1: What is the difference between `DELETE` and `TRUNCATE`?
* **`DELETE` (DML)**: Deletes rows one by one. Can use a `WHERE` clause. Slower for massive tables. Fires `ON DELETE` triggers.
* **`TRUNCATE` (DDL)**: Deallocates entire data pages instantaneously. Cannot use a `WHERE` clause. Resets sequences (if `RESTART IDENTITY` is used). 

### Q2: Why does PostgreSQL have an advantage over MySQL regarding DDL transactions?
* In **MySQL**, any DDL command (`ALTER`, `DROP`, `CREATE`) causes an **implicit commit**. If you make a mistake midway through a database migration script, you cannot roll it back!
* In **PostgreSQL**, DDL is fully **transactional**. You can wrap table migrations inside `BEGIN ... ROLLBACK;`, making migrations in production safe from partial execution.

### Q3: Why is `ON DELETE RESTRICT` used instead of `ON DELETE CASCADE` on banking accounts?
* In banking, a customer who still holds open accounts with active balances must **never be accidentally wiped out**. `ON DELETE RESTRICT` forces an error if someone tries to delete a customer who still has accounts.

### Q4: How does PostgreSQL handle sequence sync after manual ID insertions?
* When inserting explicit values into a `SERIAL` column, the underlying sequence does not advance automatically. In PostgreSQL, we sync it using:
  ```sql
  SELECT setval(pg_get_serial_sequence('accounts', 'account_no'), MAX(account_no)) FROM accounts;
  ```

---

## 📄 License & Attribution
Converted and prepared for **EY Technology Training**. Based on the original bank database training curriculum.
