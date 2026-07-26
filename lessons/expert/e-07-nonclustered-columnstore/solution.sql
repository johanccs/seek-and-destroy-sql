-- Add a nonclustered columnstore index over just the analytical columns.
-- The optimizer switches the GROUP BY to a columnar, batch-mode scan of the NCCI --
-- no rowstore Clustered Index Scan, orders of magnitude less work -- while the
-- clustered rowstore keeps serving OLTP point lookups.
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Orders ON Orders(Status, Total);

SELECT Status, COUNT(*) AS Cnt, SUM(Total) AS Rev
FROM Orders
GROUP BY Status;
