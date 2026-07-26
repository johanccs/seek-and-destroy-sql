-- Provide the sort order with an index so SQL Server reads rows already sorted.
-- No Sort operator => no memory grant => nothing spills to tempdb.
CREATE NONCLUSTERED INDEX IX_Events_Amount ON Events(Amount);
SELECT TOP (2000) EventId, UserId, Amount
FROM Events
ORDER BY Amount, EventId;
