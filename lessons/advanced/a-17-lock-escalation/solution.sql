-- Fix: batch the update so no single statement reaches the ~5,000-lock
-- escalation threshold. Each 2,000-row batch auto-commits, releasing its locks
-- immediately, so Session A never takes a table lock and Session B's unrelated
-- row (49999) is never blocked.

-- Session A:
SET NOCOUNT ON;
DECLARE @i INT = 1;
WHILE @i <= 40000
BEGIN
    UPDATE dbo.Ledger SET Amount = Amount + 1
    WHERE LedgerId BETWEEN @i AND @i + 1999;
    SET @i += 2000;
END

-- Session B (unchanged): a single-row update that should never wait.
UPDATE dbo.Ledger SET Amount = Amount + 5 WHERE LedgerId = 49999;

-- Blunt alternative: keep A's one big UPDATE but stop the table from escalating:
--   ALTER TABLE dbo.Ledger SET (LOCK_ESCALATION = DISABLE);
