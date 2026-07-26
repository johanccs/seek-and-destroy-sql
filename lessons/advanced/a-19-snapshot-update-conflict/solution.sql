-- Fix: a read-modify-write on a hot row must not rely on a stale optimistic
-- snapshot. Drop Session A to READ COMMITTED so its UPDATE simply serializes
-- after B's committed change instead of aborting with error 3960.

-- Session A:
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRAN;
SELECT Balance FROM dbo.Accounts WHERE AccountId = 1;
UPDATE dbo.Accounts SET Balance = Balance - 100 WHERE AccountId = 1;
COMMIT;

-- Session B (unchanged):
UPDATE dbo.Accounts SET Balance = Balance - 50 WHERE AccountId = 1;

-- Alternative: keep SNAPSHOT but reserve the row on read so B can't slip in:
--   SET TRANSACTION ISOLATION LEVEL SNAPSHOT; BEGIN TRAN;
--   SELECT Balance FROM dbo.Accounts WITH (UPDLOCK) WHERE AccountId = 1;
