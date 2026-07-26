-- Fix: relate the two tables. Use explicit JOIN ... ON syntax so a missing join
-- predicate would be a syntax error rather than a silent Cartesian product. Each
-- order now matches its single customer (via IX_Orders_CustomerId) and the
-- NoJoinPredicate warning disappears.
SELECT TOP (100) o.OrderId, o.Total, c.Name
FROM dbo.Orders o
JOIN dbo.Customers c ON o.CustomerId = c.CustomerId
WHERE o.Total > 995
ORDER BY o.OrderId;
