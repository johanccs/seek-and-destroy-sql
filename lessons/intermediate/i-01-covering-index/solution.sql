-- Cover the query: seek on CustomerId, and carry Total so no key lookup is needed.
DROP INDEX IX_Orders_CustomerId ON dbo.Orders;
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId_Incl
    ON dbo.Orders(CustomerId) INCLUDE (Total);
SELECT CustomerId, Total FROM Orders WHERE CustomerId = 100;
