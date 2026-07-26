-- Add OPTION (RECOMPILE). At execution time SQL Server embeds the actual value
-- ('Open') and re-estimates against the histogram -- seeing ~200 rows, not the
-- density average of ~100,000. With a tiny estimate it now chooses the Index
-- Seek + key lookup instead of scanning all 300,000 rows.
DECLARE @s VARCHAR(12) = 'Open';
SELECT OrderId, CustomerId, OrderDate, Total
FROM Orders
WHERE Status = @s
OPTION (RECOMPILE);
