-- Fix: put Status into the index KEY so it becomes a seek predicate (not a residual),
-- and INCLUDE Total so the seek is covering. The engine seeks straight to
-- CustomerId = 42 AND Status = 'Open' -- ~200 rows, no key lookups.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Status ON Orders(CustomerId, Status) INCLUDE (Total);

SELECT OrderId, Total
FROM Orders
WHERE CustomerId = 42 AND Status = 'Open';
