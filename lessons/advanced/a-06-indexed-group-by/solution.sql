-- Give GROUP BY a stream that is already ordered by CustomerId (and covers Total).
-- The optimizer can now feed the ordered index straight into a Stream Aggregate,
-- collapsing adjacent equal keys in one pass -- no hash table, no memory grant.
CREATE NONCLUSTERED INDEX IX_Orders_Cust
    ON dbo.Orders(CustomerId) INCLUDE (Total);
SELECT CustomerId, COUNT(*) AS Cnt, SUM(Total) AS TotalSum
FROM Orders GROUP BY CustomerId;
