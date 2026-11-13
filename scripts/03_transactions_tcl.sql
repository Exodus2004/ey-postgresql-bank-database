-- ====================================================================
-- PostgreSQL Conversion: Bank Database Training (TCL)
-- Module 3: Transaction Control Language (ACID Guarantees)
-- Converted from MySQL 8.0 for EY Training Lab
-- ====================================================================

-- --------------------------------------------------------------------
-- Key PostgreSQL vs MySQL Transaction Insight:
-- 1. In PostgreSQL, 'BEGIN;' is the standard idiom (though 'START TRANSACTION;' is supported).
-- 2. PostgreSQL supports TRANSACTIONAL DDL! Unlike MySQL (where CREATE/DROP/ALTER 
--    implicitly commits), in PostgreSQL you can wrap DDL in a transaction and roll it back!
-- --------------------------------------------------------------------

-- --------------------------------------------------------------------
-- 1. COMMIT: Successful Fund Transfer
-- --------------------------------------------------------------------
-- Scenario: Transfer ₹10,000 from account 1002 to account 1001.

-- Check initial balances
SELECT account_no, balance 
FROM accounts 
WHERE account_no IN (1001, 1002);

BEGIN;

-- Step 1: Debit account 1002
UPDATE accounts 
SET balance = balance - 10000 
WHERE account_no = 1002;

-- Step 2: Credit account 1001
UPDATE accounts 
SET balance = balance + 10000 
WHERE account_no = 1001;

-- Finalize transaction
COMMIT;

-- Verify final balances (1001 increased by 10,000; 1002 decreased by 10,000)
SELECT account_no, balance 
FROM accounts 
WHERE account_no IN (1001, 1002);


-- --------------------------------------------------------------------
-- 2. ROLLBACK: Undoing an Accidental Operation
-- --------------------------------------------------------------------
-- Scenario: An accidental bulk delete is executed and reverted.

SELECT COUNT(*) AS count_before FROM accounts; -- 7

BEGIN;

-- Accidental delete
DELETE FROM accounts WHERE account_type = 'SALARY';

-- Notice: In this session, count is temporarily 5
SELECT COUNT(*) AS count_inside_txn FROM accounts;

-- Undo everything back to BEGIN
ROLLBACK;

-- Confirmed: All 7 rows are fully restored
SELECT COUNT(*) AS count_after_rollback FROM accounts; -- 7


-- --------------------------------------------------------------------
-- 3. ROLLBACK After Constraint Failure
-- --------------------------------------------------------------------
-- Scenario: Account 1004 has ~₹32,000. Transferring ₹50,000 will violate
-- the CHECK constraint (balance >= 0).

BEGIN;

-- This update fails: violates check constraint "chk_balance"
-- UPDATE accounts SET balance = balance - 50000 WHERE account_no = 1004;

-- When an error occurs in PostgreSQL, the transaction enters an aborted state.
-- You must issue ROLLBACK to cleanly reset the session:
ROLLBACK;


-- --------------------------------------------------------------------
-- 4. SAVEPOINT: Partial Rollback within a Transaction
-- --------------------------------------------------------------------
-- Scenario: Debit ₹1,000 from account 1004. Clerk accidentally credits
-- account 1005, rolls back ONLY that mistake, and credits account 1007 instead.

BEGIN;

-- Step 1: Debit ₹1,000 from account 1004
UPDATE accounts 
SET balance = balance - 1000 
WHERE account_no = 1004;

-- Step 2: Create a savepoint
SAVEPOINT after_debit;

-- Step 3: Mistaken credit to account 1005
UPDATE accounts 
SET balance = balance + 1000 
WHERE account_no = 1005;

-- Step 4: Undo only the mistaken credit
ROLLBACK TO SAVEPOINT after_debit;

-- Step 5: Credit the correct account 1007
UPDATE accounts 
SET balance = balance + 1000 
WHERE account_no = 1007;

-- Step 6: Commit the debit and correct credit
COMMIT;

-- Verify results:
-- Account 1004: debited by ₹1,000
-- Account 1005: untouched
-- Account 1007: credited by ₹1,000
SELECT account_no, balance 
FROM accounts 
WHERE account_no IN (1004, 1005, 1007);
