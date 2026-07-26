-- Refresh the histogram so the optimizer knows CustomerId = 7 now has ~300k rows.
UPDATE STATISTICS Orders WITH FULLSCAN;
-- Re-run: with a correct estimate the optimizer stops doing a per-row Key Lookup
-- (Nested Loops) and switches to a scan-based plan appropriate for many rows.
SELECT CustomerId, Total FROM Orders WHERE CustomerId = 999;
