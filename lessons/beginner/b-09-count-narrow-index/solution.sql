-- A skinny nonclustered index gives COUNT(*) a much smaller structure to scan.
-- Every row still appears exactly once in the index, so the count is identical
-- but the logical reads drop by an order of magnitude.
CREATE NONCLUSTERED INDEX IX_Orders_Region ON Orders(Region);

SELECT COUNT(*) FROM Orders;
