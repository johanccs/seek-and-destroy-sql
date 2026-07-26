-- Fix: compute the per-customer count once with a window function instead of a
-- per-row correlated subquery. One pass, no spool worktable.
SELECT TOP (100) o.OrderId, o.CustomerId,
       COUNT(*) OVER (PARTITION BY o.CustomerId) AS CustomerOrders
FROM Orders o
ORDER BY o.OrderId;
