-- Fix: compare the indexed column bare -- no function. The data is already uppercase,
-- so removing UPPER() changes nothing except restoring the index seek.
SELECT o.OrderId, o.Total
FROM Orders o
JOIN Customers c ON o.CustomerRef = c.Ref
WHERE c.CustomerId = 42;
