-- Rewrite the DATEDIFF filter as a half-open range on the bare column so the index seeks.
-- DATEDIFF(DAY, OrderDate, '2026-01-01') BETWEEN 0 AND 6  <=>  OrderDate in [2025-12-26, 2026-01-02).
SELECT OrderId, CustomerId, OrderDate, Total
FROM Orders
WHERE OrderDate >= '2025-12-26' AND OrderDate < '2026-01-02';
