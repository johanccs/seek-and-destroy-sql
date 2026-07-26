-- Fix: name the window frame explicitly with ROWS. ROWS UNBOUNDED PRECEDING counts
-- physical rows up to the current one, which SQL Server computes with a fast
-- in-memory spool -- the on-disk worktable (and its ~600k reads) disappears.
SELECT Id, SUM(Amount) OVER (ORDER BY Id ROWS UNBOUNDED PRECEDING) AS RunningTotal
FROM Ledger
ORDER BY Id;
