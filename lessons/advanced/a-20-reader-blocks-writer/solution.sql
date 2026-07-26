-- Fix: don't hold the read lock. Remove the HOLDLOCK hint so A's shared lock is
-- released the moment the row is read (default READ COMMITTED), letting B's UPDATE
-- take its exclusive lock immediately.

-- Session A:
BEGIN TRAN;
SELECT AccountId, Owner, Balance FROM dbo.Accounts WHERE AccountId = 1;
WAITFOR DELAY '00:00:02';
COMMIT;

-- Session B (unchanged):
UPDATE dbo.Accounts SET Balance = Balance - 50 WHERE AccountId = 1;

-- Alternative (if A needs a stable, repeatable view): a lock-free versioned read.
--   SET TRANSACTION ISOLATION LEVEL SNAPSHOT; BEGIN TRAN;
--   SELECT AccountId, Owner, Balance FROM dbo.Accounts WHERE AccountId = 1;
