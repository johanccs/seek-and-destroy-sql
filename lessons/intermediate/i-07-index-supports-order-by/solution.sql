-- Promote OrderDate from an INCLUDE to a KEY column, right after CustomerId.
-- Now the seek on CustomerId = 100 returns rows already ordered by OrderDate, so
-- ORDER BY OrderDate DESC is just a backward read of that range -- the Sort is gone.
-- (An INCLUDE column can cover a query but can never provide ordering; only a key
-- column can.)
DROP INDEX IX_Orders_CustomerId ON dbo.Orders;
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Date
    ON dbo.Orders(CustomerId, OrderDate) INCLUDE (Total);
SELECT OrderId, OrderDate, Total FROM Orders
WHERE CustomerId = 100 ORDER BY OrderDate DESC;
