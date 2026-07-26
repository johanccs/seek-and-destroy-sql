-- Fix: compare the indexed column bare -- no function. The data is already uppercase,
-- so removing UPPER() changes nothing except restoring the index seek.
SELECT o.OrderId, o.Total
FROM dbo.Orders o
JOIN dbo.Customers c ON o.CustomerRef = c.Ref
WHERE c.CustomerId = 42;
