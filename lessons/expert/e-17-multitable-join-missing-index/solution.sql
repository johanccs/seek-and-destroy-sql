-- Fix: index the unindexed join key on the many-side table. The Hash Match scan of
-- all 500,000 order lines becomes a Nested Loops + Index Seek that touches only the
-- customer's lines. INCLUDE Amount so the seek is covering.
CREATE NONCLUSTERED INDEX IX_OrderLines_OrderId ON dbo.OrderLines(OrderId) INCLUDE (Amount);

SELECT o.OrderId, l.LineId, l.Amount
FROM dbo.Customers c
JOIN dbo.Orders o ON o.CustomerId = c.CustomerId
JOIN dbo.OrderLines l ON l.OrderId = o.OrderId
WHERE c.CustomerId = 42;
