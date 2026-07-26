-- Keyset (seek) pagination: instead of counting past 200,000 rows, seek straight
-- to the key just after the last one the previous page showed (OrderId 200000)
-- and take the next 20. The clustered index turns "the page after key K" into a
-- single seek, so cost is proportional to page size, not page depth.
SELECT TOP (20) OrderId, CustomerId, OrderDate, Total
FROM Orders
WHERE OrderId > 200000
ORDER BY OrderId;
