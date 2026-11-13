# 🏦 PostgreSQL Bank Database — Complete Training & Enterprise Lab Guide

> **Prepared for**: EY Technology Onboarding & Training  
> **Source Repository**: [Msocial123/EY-AI-Training](https://github.com/Msocial123/EY-AI-Training.git)  
> **Target RDBMS**: **PostgreSQL 16+** (100% Complete conversion from MySQL 8.0)  
> **Core Concepts**: Relational Database Design (1NF/2NF/3NF), Constraints, CRUD (DML), Transactional DDL, ACID Transactions (TCL), Multi-table Joins, CTEs, Window Functions, PL/pgSQL Stored Procedures & UDFs, Views with CHECK OPTION.

---

## 📌 Table of Contents
1. [Architecture & Schema Design](#-architecture--schema-design)
2. [Database Normalization Journey (1NF to 3NF)](#-database-normalization-journey-1nf-to-3nf)
3. [MySQL vs. PostgreSQL Comprehensive Conversion Guide](#-mysql-vs-postgresql-comprehensive-conversion-guide)
4. [Repository Structure](#-repository-structure)
5. [Quick Start & Setup](#-quick-start--setup)
6. [Module 1: Core Schema & Fundamentals](#-module-1-core-schema--fundamentals)
7. [Module 2: Advanced 4-Table Enterprise Relational Lab](#-module-2-advanced-4-table-enterprise-relational-lab)
8. [Module 3: Advanced Joins, CTEs & Window Functions](#-module-3-advanced-joins-ctes--window-functions)
9. [Module 4: Functions & Views (PL/pgSQL)](#-module-4-functions--views-plpgsql)
10. [Module 5: Stored Procedures & Transaction Control](#-module-5-stored-procedures--transaction-control)
11. [Module 6: Advanced Lab Assessment (10 Tasks & Solutions)](#-module-6-advanced-lab-assessment-10-tasks--solutions)
12. [Interview & Trainer Q&A](#-interview--trainer-qa)

---

## 🏗️ Architecture & Schema Design

### 1. Enterprise 4-Table Relational Model (`bank_lab`)
The advanced lab models a production-grade retail bank across four normalized tables with referential integrity, check constraints, and sequence-backed primary keys:

```
┌─────────────────────────────────┐
│        branches (Parent)        │
├─────────────────────────────────┤
│ branch_id    SERIAL [PK]        │
│ branch_name  VARCHAR(50) [UQ]   │
│ city         VARCHAR(50)        │
└──────────────┬──────────────────┘
               │ (1 : Many)
               ▼
┌─────────────────────────────────┐                 ┌─────────────────────────────────┐
│        customers (Parent)       │                 │         accounts (Child)        │
├─────────────────────────────────┤                 ├─────────────────────────────────┤
│ customer_id   SERIAL [PK]       │◄───(1 : Many)───┤ account_no    BIGSERIAL [PK]    │
│ first_name    VARCHAR(50)       │                 │ customer_id   INT [FK]          │
│ last_name     VARCHAR(50)       │                 │ branch_id     INT [FK]          │
│ email         VARCHAR(100) [UQ] │                 │ account_type  VARCHAR(20) [CHK] │
│ phone         VARCHAR(15)       │                 │ balance       DECIMAL(12,2)[CHK]│
│ date_of_birth DATE              │                 │ status        VARCHAR(10) [CHK] │
│ city          VARCHAR(50)       │                 │ opened_on     DATE              │
│ kyc_status    VARCHAR(10)       │                 └──────────────┬──────────────────┘
│ created_at    TIMESTAMP         │                                │ (1 : Many)
└─────────────────────────────────┘                                ▼
                                                    ┌─────────────────────────────────┐
                                                    │       transactions (Ledger)     │
                                                    ├─────────────────────────────────┤
                                                    │ txn_id        BIGSERIAL [PK]    │
                                                    │ account_no    BIGINT [FK]       │
                                                    │ txn_type      VARCHAR(15) [CHK] │
                                                    │ amount        DECIMAL(12,2)[CHK]│
                                                    │ txn_date      TIMESTAMP         │
                                                    │ description   VARCHAR(100)      │
                                                    └─────────────────────────────────┘
```

---

## 📐 Database Normalization Journey (1NF to 3NF)

A common interview & enterprise design pattern is decomposing unnormalized flat spreadsheets (`bank_flat`) into Third Normal Form:

### 1. Flat Denormalized Model (`bank_flat`)
* **Problem Columns**: `customer_phones` ("9876500001, 9876500099"), `customer_city`, `branch_name`, `branch_city`.
* **Anomalies Experienced**:
  1. **Insertion Anomaly**: Cannot add a new branch without first creating an account and customer.
  2. **Update Anomaly**: If a branch changes city, every single customer account row referencing that branch must be modified; missing one causes data corruption.
  3. **Deletion Anomaly**: If customer #5 closes their account and the row is deleted, the branch record is completely wiped out from the system.

### 2. Normal Form Decompositions
* **1NF (First Normal Form)**: Eliminate repeating groups & non-atomic values.
  * *Fix*: Multi-valued `customer_phones` is split into individual rows or single atomic phone numbers.
* **2NF (Second Normal Form)**: Remove partial dependencies on composite primary keys.
  * *Fix*: In composite keys `(customer_id, account_no)`, customer attributes (`first_name`, `dob`, `customer_city`) depended only on `customer_id`. Separated into the `customers` table.
* **3NF (Third Normal Form)**: Remove transitive dependencies (non-key attributes depending on non-key attributes).
  * *Fix*: `branch_city` depended on `branch_name`, not the primary key `account_no`. Separated into an independent `branches` table.

---

## 🔄 MySQL vs. PostgreSQL Comprehensive Conversion Guide

| Feature / Concept | MySQL 8.0 (Original Guide) | PostgreSQL 16+ (Converted) | Enterprise Reason |
| :--- | :--- | :--- | :--- |
| **Primary Keys** | `INT AUTO_INCREMENT PRIMARY KEY` | `SERIAL PRIMARY KEY` or `BIGSERIAL` | PostgreSQL uses sequence objects natively. |
| **Engine Declaration** | `ENGINE = InnoDB;` | *Omitted entirely* | PostgreSQL is natively ACID-compliant; engines do not exist. |
| **Current Date** | `CURDATE()` | `CURRENT_DATE` | PostgreSQL strictly adheres to ANSI SQL standards. |
| **Procedural Routines**| `DELIMITER // CREATE PROCEDURE ...` | `CREATE PROCEDURE ... AS $$ ... $$;` | PostgreSQL uses dollar-quoting (`$$`); client delimiters are never needed. |
| **Error Handling** | `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = ...` | `RAISE EXCEPTION '...'` | PostgreSQL native PL/pgSQL error signaling mechanism. |
| **Full Outer Join** | *Unsupported natively* (Emulated via `LEFT JOIN UNION RIGHT JOIN`) | Native `FULL OUTER JOIN` | PostgreSQL provides true full outer hash/merge join algorithms. |
| **Date Difference** | `DATEDIFF('2025-03-31', txn_date)` | `(DATE '2025-03-31' - txn_date::DATE)` | Subtracting dates yields exact day integers directly in Postgres. |
| **Date Arithmetic** | `DATE_ADD(txn_date, INTERVAL 30 DAY)` | `txn_date + INTERVAL '30 days'` | Natural date/timestamp interval algebra. |
| **Age Calculation** | `TIMESTAMPDIFF(YEAR, dob, CURDATE())` | `EXTRACT(YEAR FROM AGE(CURRENT_DATE, dob))::INT` | Accurate leap-year and calendar-aware age calculation. |
| **String Aggregation** | `GROUP_CONCAT(acc_no SEPARATOR ', ')` | `STRING_AGG(acc_no::TEXT, ', ')` | ANSI standard string aggregation with explicit ordering. |
| **Substrings & Index** | `LOCATE('@', email)` | `POSITION('@' IN email)` or `STRPOS(email, '@')` | PostgreSQL ANSI SQL string position search. |
| **Conditional Masking**| `IF(condition, a, b)` | `CASE WHEN condition THEN a ELSE b END` | Standard SQL CASE expression (portable across RDBMS). |
| **Concurrency Locking**| Manual transaction locking | `SELECT ... FOR UPDATE` | Row-level locking to prevent race conditions during fund transfers. |
| **Transactional DDL** | DDL commits implicitly (cannot rollback) | **DDL can be rolled back!** | Schema migrations can safely be tested inside `BEGIN ... ROLLBACK`. |

---

## 📂 Repository Structure

```text
ey-postgresql-bank-database/
├── README.md                                  # Full Guide & Conversion Documentation
├── docker-compose.yml                         # 1-Click PostgreSQL 16 + pgAdmin 4 Stack
├── test_scripts.py                            # Automated Python Syntax & Compliance Tester
├── docs/                                      # Original Curriculum Documents
│   ├── Bank_Database_DDL_DML_TCL_Training_Guide.docx
│   ├── Bank_Database_DDL_DML_TCL_Training_Guide.pdf
│   ├── SQL_Data_Model_Queries_Functions_Views_Procedures_Joins_Guide.docx
│   └── SQL_Data_Model_Queries_Functions_Views_Procedures_Joins_Guide.pdf
└── scripts/                                   # 100% Verified PostgreSQL Scripts
    ├── 01_schema_ddl.sql                      # Module 1: Core DDL Schema Creation & Alter
    ├── 02_data_dml.sql                        # Module 1: Core DML Inserts, Joins & Aggregates
    ├── 03_transactions_tcl.sql                # Module 1: Core TCL Commit, Rollback, Savepoints
    ├── 04_lab_assessment.sql                  # Module 1: Core Lab Assessment (8 Tasks)
    ├── all_in_one_bank_db.sql                 # Module 1: Master All-In-One Core Script
    ├── 05_advanced_schema_lab.sql             # Module 2: 4-Table Normalized Schema & Seed Data
    ├── 06_advanced_queries_joins.sql          # Module 2: All Joins, CTEs, Window Functions
    ├── 07_functions_and_views.sql             # Module 2: Built-in & PL/pgSQL UDFs, Views
    ├── 08_stored_procedures.sql               # Module 2: Procedures, INOUT, Locks & Transfers
    ├── 09_advanced_lab_assessment.sql         # Module 2: Advanced Lab Solutions (10 Tasks)
    └── all_in_one_advanced_lab.sql            # Module 2: Master All-In-One Enterprise Script
```

---

## 🚀 Quick Start & Setup

### Option A: 1-Click Docker Setup (Recommended)
Launch PostgreSQL 16 and pgAdmin 4 together:
```bash
docker compose up -d
```
* **PostgreSQL Port**: `localhost:5432` (User: `postgres`, Password: `postgres123`, DB: `bank_db`)
* **pgAdmin 4 Web UI**: Open **[http://localhost:5050](http://localhost:5050)** (Login: `admin@bank.com` / `admin123`)

### Option B: Local Command Line (`psql`)
Connect to your local PostgreSQL instance:
```bash
psql -U postgres
```
Create the lab database and execute the master all-in-one script:
```sql
CREATE DATABASE bank_lab;
\c bank_lab
\i scripts/all_in_one_advanced_lab.sql
```

---

## 🛠️ Module 1: Core Schema & Fundamentals
* **Files**: [`01_schema_ddl.sql`](scripts/01_schema_ddl.sql), [`02_data_dml.sql`](scripts/02_data_dml.sql), [`03_transactions_tcl.sql`](scripts/03_transactions_tcl.sql), [`04_lab_assessment.sql`](scripts/04_lab_assessment.sql), [`all_in_one_bank_db.sql`](scripts/all_in_one_bank_db.sql)

Covers primary constraints, foreign keys with `ON UPDATE CASCADE ON DELETE RESTRICT`, safe transaction processing using `SAVEPOINT`, and rollback protection.

---

## 🏢 Module 2: Advanced 4-Table Enterprise Relational Lab
* **File**: [`scripts/05_advanced_schema_lab.sql`](scripts/05_advanced_schema_lab.sql)

Establishes the enterprise bank schema with 4 normalized tables:
1. `branches`: Normalized branch master.
2. `customers`: Customer master with KYC tracking.
3. `accounts`: Linked to branch and customer, with balance checks (`balance >= 0`).
4. `transactions`: Double-entry accounting ledger tracking debits, credits, and transfers.
Includes complete initial dataset (6 branches, 6 customers, 7 accounts, 12 transactions) with edge cases (branches without accounts, customers without accounts).

---

## ⚡ Module 3: Advanced Joins, CTEs & Window Functions
* **File**: [`scripts/06_advanced_queries_joins.sql`](scripts/06_advanced_queries_joins.sql)

### 1. Window Functions
```sql
-- Rank accounts by balance within each branch
SELECT a.account_no,
       b.branch_name,
       a.balance,
       ROW_NUMBER() OVER (PARTITION BY a.branch_id ORDER BY a.balance DESC) AS row_num,
       RANK()       OVER (PARTITION BY a.branch_id ORDER BY a.balance DESC) AS balance_rank,
       DENSE_RANK() OVER (PARTITION BY a.branch_id ORDER BY a.balance DESC) AS dense_rank
FROM accounts a
JOIN branches b ON b.branch_id = a.branch_id;

-- Running transaction balance over time
SELECT txn_id,
       account_no,
       txn_date,
       amount,
       txn_type,
       SUM(CASE WHEN txn_type IN ('DEPOSIT','TRANSFER_IN') THEN amount ELSE -amount END)
           OVER (PARTITION BY account_no ORDER BY txn_date) AS running_balance
FROM transactions;
```

### 2. Native PostgreSQL `FULL OUTER JOIN`
```sql
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS customer_name,
       a.account_no,
       a.balance
FROM customers c
FULL OUTER JOIN accounts a ON a.customer_id = c.customer_id;
```

### 3. Anti-Joins (`NOT EXISTS`)
```sql
-- Find branches that have no accounts
SELECT b.branch_id, b.branch_name, b.city
FROM branches b
WHERE NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.branch_id = b.branch_id
);
```

---

## 🧩 Module 4: Functions & Views (PL/pgSQL)
* **File**: [`scripts/07_functions_and_views.sql`](scripts/07_functions_and_views.sql)

### 1. User-Defined PL/pgSQL Functions
* `fn_customer_tier(p_balance)`: Assigns `PLATINUM`, `GOLD`, `SILVER`, or `STANDARD` tiers.
* `fn_age(p_dob)`: Calculates current age accurately using `AGE(CURRENT_DATE, dob)`.
* `fn_mask_email(p_email)`: Obfuscates personal emails (e.g., `ar*****@example.com`).
* `fn_total_balance(p_cust_id)`: Calculates customer portfolio balance.

### 2. Views with `WITH CHECK OPTION`
```sql
CREATE OR REPLACE VIEW vw_active_savings AS
SELECT account_no, customer_id, branch_id, balance, opened_on, status
FROM accounts
WHERE account_type = 'SAVINGS' AND status = 'ACTIVE'
WITH CHECK OPTION;
```

---

## 🔒 Module 5: Stored Procedures & Transaction Control
* **File**: [`scripts/08_stored_procedures.sql`](scripts/08_stored_procedures.sql)

### Enterprise Fund Transfer with Concurrency Control (`FOR UPDATE`)
```sql
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
    -- Input checks
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be positive. Provided: %', p_amount;
    END IF;
    IF p_from_acc = p_to_acc THEN
        RAISE EXCEPTION 'Source and destination accounts cannot be identical.';
    END IF;

    -- Row lock source account
    SELECT balance, status INTO v_from_bal, v_from_status
    FROM accounts WHERE account_no = p_from_acc FOR UPDATE;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance in account %. Available: ₹%, Requested: ₹%',
            p_from_acc, v_from_bal, p_amount;
    END IF;

    -- Row lock destination account
    SELECT status INTO v_to_status
    FROM accounts WHERE account_no = p_to_acc FOR UPDATE;

    -- Execute transfer
    UPDATE accounts SET balance = balance - p_amount WHERE account_no = p_from_acc;
    UPDATE accounts SET balance = balance + p_amount WHERE account_no = p_to_acc;

    -- Audit ledger entries
    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_from_acc, 'TRANSFER_OUT', p_amount, CURRENT_TIMESTAMP, 'Transfer to ' || p_to_acc::TEXT);

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_to_acc, 'TRANSFER_IN', p_amount, CURRENT_TIMESTAMP, 'Transfer from ' || p_from_acc::TEXT);

    COMMIT;
END;
$$;
```

---

## 📝 Module 6: Advanced Lab Assessment (10 Tasks & Solutions)
* **File**: [`scripts/09_advanced_lab_assessment.sql`](scripts/09_advanced_lab_assessment.sql)

| # | Topic | Objective | Key PostgreSQL Solution Concept |
|---|---|---|---|
| **1** | Normalization | Normal form violations in `bank_flat` | 1NF (multi-valued phones), 2NF (partial dependency on customer_city), 3NF (transitive dependency on branch_city). |
| **2** | Left Join | Full customer list with balance, including 0 for no account | `COALESCE(SUM(a.balance), 0.00)` with `LEFT JOIN` and `GROUP BY`. |
| **3** | Window Function | Top account by balance within each account type | Subquery filtering on `ROW_NUMBER() OVER (PARTITION BY account_type ORDER BY balance DESC) = 1`. |
| **4** | Aggregation | Accounts with average transaction amount > ₹20,000 | `GROUP BY t.account_no HAVING AVG(t.amount) > 20000;` |
| **5** | Anti-Join | Branches that have no active accounts | `WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.branch_id = b.branch_id AND a.status = 'ACTIVE')`. |
| **6** | Distinct Aggregate| Branch customer count and total deposits | `COUNT(DISTINCT a.customer_id)` and `SUM(a.balance)` per branch. |
| **7** | PL/pgSQL UDF | `fn_interest(balance, rate)` function | `ROUND(p_balance * (p_rate / 100.00), 2);` |
| **8** | Join / Filter | Customers with no transactions in 2024 | `WHERE c.customer_id NOT IN (SELECT DISTINCT a.customer_id FROM accounts a JOIN transactions t ON t.account_no = a.account_no WHERE EXTRACT(YEAR FROM t.txn_date) = 2024)`. |
| **9** | View | `vw_dormant_accounts` view | Joins `accounts`, `customers`, and `branches` filtering on `status = 'DORMANT'`. |
| **10**| Stored Procedure | `sp_withdraw(acc_no, amount, desc)` | Validates balance, locks account row with `FOR UPDATE`, debits balance, writes audit entry to `transactions`, and executes `COMMIT`. |

---

## 💡 Interview & Trainer Q&A

### Q1: What is the difference between `RANK()`, `DENSE_RANK()`, and `ROW_NUMBER()`?
* **`ROW_NUMBER()`**: Always produces unique consecutive integers (1, 2, 3, 4, 5) regardless of ties.
* **`RANK()`**: Assigns identical rank to ties, but leaves gaps in the subsequent numbers (e.g., 1, 2, 2, 4).
* **`DENSE_RANK()`**: Assigns identical rank to ties without leaving gaps (e.g., 1, 2, 2, 3).

### Q2: Why are PostgreSQL procedures preferred over functions for money transfers?
* In PostgreSQL, **functions cannot control transactions** (`COMMIT` or `ROLLBACK` cannot be issued inside a UDF called from a `SELECT`).
* **Stored Procedures** (`CREATE PROCEDURE ... CALL`) can manage autonomous transactions, allowing explicit `COMMIT` and `ROLLBACK` statements to ensure financial atomicity.

### Q3: What is the purpose of `WITH CHECK OPTION` on a view?
* When inserting or updating rows through an updatable view, `WITH CHECK OPTION` rejects any DML operation that would produce a row not visible in the view definition (e.g. attempting to insert a `DORMANT` account into `vw_active_savings`).

### Q4: How does `FOR UPDATE` protect against the "double-spend" race condition?
* When two concurrent transactions read an account balance at the exact same millisecond, both might believe enough balance exists. `SELECT ... FOR UPDATE` acquires an exclusive row lock on the account until the transaction commits, serializing concurrent transfer requests.

---

## 📄 License & Attribution
Converted, extended, and verified for **EY Technology Training**. Based on the original bank database and advanced SQL curriculum.
