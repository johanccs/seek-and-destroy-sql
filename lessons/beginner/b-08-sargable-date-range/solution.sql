-- Replace the function-wrapped predicate with a half-open date range.
-- OrderDate is now exposed directly, so the covering index can SEEK the month.
SELECT OrderId, CustomerId, OrderDate, Total
FROM Orders
WHERE OrderDate >= '2025-06-01' AND OrderDate < '2025-07-01';
