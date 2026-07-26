-- An index on the ORDER BY column lets SQL Server read just the END of the index
-- (one row) instead of scanning the whole table and Top-N sorting it.
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);

SELECT TOP 1 OrderId, CustomerId, OrderDate, Total
FROM Orders
ORDER BY OrderDate DESC;
