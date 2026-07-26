-- Fix: take an UPDATE (U) lock at read time so the two SELECTs can't both succeed.
-- U locks are incompatible with each other, so the second session blocks at the
-- read and waits its turn instead of both racing to convert S -> X and deadlocking.
-- (Isolation stays REPEATABLE READ; only the lock hint changes.)

-- Session A:
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRAN;
SELECT Balance FROM dbo.Accounts WITH (UPDLOCK) WHERE AccountId = 1;
UPDATE dbo.Accounts SET Balance = Balance - 100 WHERE AccountId = 1;
COMMIT;

-- Session B:
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRAN;
SELECT Balance FROM dbo.Accounts WITH (UPDLOCK) WHERE AccountId = 1;
UPDATE dbo.Accounts SET Balance = Balance - 50 WHERE AccountId = 1;
COMMIT;
