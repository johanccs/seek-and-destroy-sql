-- Fix: index the join column on the big table (INCLUDE the returned column so the
-- index covers the query). The join becomes a Nested Loops + Index Seek that reads
-- only the one customer's orders.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId) INCLUDE (Total);

SELECT o.OrderId, o.Total
FROM dbo.Orders o
JOIN dbo.Customers c ON o.CustomerId = c.CustomerId
WHERE c.CustomerId = 42;
