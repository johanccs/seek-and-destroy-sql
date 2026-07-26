-- Fix: index the unindexed join key on the many-side table. The Hash Match scan of
-- all 500,000 order lines becomes a Nested Loops + Index Seek that touches only the
-- customer's lines. INCLUDE Amount so the seek is covering.
CREATE NONCLUSTERED INDEX IX_OrderLines_OrderId ON OrderLines(OrderId) INCLUDE (Amount);

SELECT o.OrderId, l.LineId, l.Amount
FROM Customers c
JOIN Orders o ON o.CustomerId = c.CustomerId
JOIN OrderLines l ON l.OrderId = o.OrderId
WHERE c.CustomerId = 42;
