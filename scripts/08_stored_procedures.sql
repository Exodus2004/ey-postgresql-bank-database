-- ====================================================================
-- PostgreSQL Conversion: Stored Procedures
-- Module 8: Parameterized Procedures, Transaction Control & Exception Handling
-- Converted from MySQL 8.0 for EY Advanced Training
-- ====================================================================

-- --------------------------------------------------------------------
-- Key Differences between MySQL and PostgreSQL Procedures:
-- 1. MySQL requires 'DELIMITER //' because client semicolons break routines.
--    PostgreSQL uses native dollar-quoting ($$ ... $$) and does not need DELIMITER!
-- 2. In MySQL, errors use 'SIGNAL SQLSTATE ...'. In PostgreSQL, we use 'RAISE EXCEPTION'.
-- 3. PostgreSQL procedures (CREATE PROCEDURE) can manage transactions (COMMIT / ROLLBACK).
-- --------------------------------------------------------------------

-- --------------------------------------------------------------------
-- Procedure 1: Read-only Procedure / Table Function
-- (Retrieves accounts for a specific customer)
-- --------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_customer_accounts(p_customer_id INT)
RETURNS TABLE (
    account_no   BIGINT,
    account_type VARCHAR(20),
    balance      DECIMAL(12,2),
    status       VARCHAR(10),
    branch_name  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT a.account_no, a.account_type, a.balance, a.status, b.branch_name
    FROM accounts a
    JOIN branches b ON b.branch_id = a.branch_id
    WHERE a.customer_id = p_customer_id
    ORDER BY a.account_no;
END;
$$;

-- Call the function/procedure
SELECT * FROM sp_customer_accounts(1);


-- --------------------------------------------------------------------
-- Procedure 2: OUT Parameters (Branch Statistics)
-- --------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_branch_stats(
    p_branch_id INT,
    INOUT p_accounts INT DEFAULT NULL,
    INOUT p_total DECIMAL(14,2) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT COUNT(*), COALESCE(SUM(balance), 0)
    INTO p_accounts, p_total
    FROM accounts
    WHERE branch_id = p_branch_id;
END;
$$;

-- Call the procedure with INOUT variables
DO $$
DECLARE
    v_acc_count INT;
    v_tot_bal   DECIMAL(14,2);
BEGIN
    CALL sp_branch_stats(1, v_acc_count, v_tot_bal);
    RAISE NOTICE 'Branch #1 Stats -> Total Accounts: %, Total Balance: ₹%', v_acc_count, v_tot_bal;
END;
$$;


-- --------------------------------------------------------------------
-- Procedure 3: Full Enterprise Fund Transfer with Row Locking & Transaction
-- --------------------------------------------------------------------
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
    -- 1. Input Validation
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be positive. Provided: %', p_amount;
    END IF;

    IF p_from_acc = p_to_acc THEN
        RAISE EXCEPTION 'Source and destination accounts cannot be identical.';
    END IF;

    -- 2. Lock Source Account Row (Prevents race conditions)
    SELECT balance, status INTO v_from_bal, v_from_status
    FROM accounts
    WHERE account_no = p_from_acc
    FOR UPDATE;

    IF v_from_bal IS NULL THEN
        RAISE EXCEPTION 'Source account % does not exist.', p_from_acc;
    END IF;

    IF v_from_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Source account % is % (must be ACTIVE).', p_from_acc, v_from_status;
    END IF;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds: balance ₹% is less than transfer amount ₹%', v_from_bal, p_amount;
    END IF;

    -- 3. Lock Destination Account Row
    SELECT status INTO v_to_status
    FROM accounts
    WHERE account_no = p_to_acc
    FOR UPDATE;

    IF v_to_status IS NULL THEN
        RAISE EXCEPTION 'Destination account % does not exist.', p_to_acc;
    END IF;

    IF v_to_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Destination account % is % (must be ACTIVE).', p_to_acc, v_to_status;
    END IF;

    -- 4. Execute Debit & Credit
    UPDATE accounts SET balance = balance - p_amount WHERE account_no = p_from_acc;
    UPDATE accounts SET balance = balance + p_amount WHERE account_no = p_to_acc;

    -- 5. Audit Trail Logs
    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_from_acc, 'TRANSFER_OUT', p_amount, CURRENT_TIMESTAMP, 'Transfer to account #' || p_to_acc);

    INSERT INTO transactions (account_no, txn_type, amount, txn_date, description)
    VALUES (p_to_acc, 'TRANSFER_IN', p_amount, CURRENT_TIMESTAMP, 'Transfer from account #' || p_from_acc);

    -- 6. Commit Transaction
    COMMIT;
    RAISE NOTICE 'Transfer of ₹% from #% to #% completed successfully!', p_amount, p_from_acc, p_to_acc;
END;
$$;

-- Test Case 1: Successful Transfer (₹15,000 from 1002 to 1001)
CALL sp_transfer_funds(1002, 1001, 15000.00);

-- Verify Balances after procedure execution
SELECT account_no, balance FROM accounts WHERE account_no IN (1001, 1002);

-- Test Case 2: Insufficient Funds (Fails as expected)
-- CALL sp_transfer_funds(1004, 1001, 500000.00);
