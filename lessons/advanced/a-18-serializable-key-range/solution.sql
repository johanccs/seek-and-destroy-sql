-- Fix: use the weakest isolation that is still correct. This report doesn't need
-- phantom protection, so drop Session A from SERIALIZABLE to READ COMMITTED. A then
-- takes only brief shared locks (no key-range locks) and B's INSERT into the
-- CustomerId = 5 range is never blocked.

-- Session A:
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRAN;
SELECT COUNT(*) FROM dbo.Orders WHERE CustomerId = 5;
WAITFOR DELAY '00:00:02';
COMMIT;

-- Session B (unchanged): inserts a new order for the same customer.
INSERT INTO dbo.Orders (CustomerId, Amount) VALUES (5, 99.99);

-- Alternative: SET TRANSACTION ISOLATION LEVEL SNAPSHOT; (row versioning, also no key-range locks)
