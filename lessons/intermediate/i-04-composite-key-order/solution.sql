-- Put the EQUALITY column (CustomerId) first, the RANGE column (OrderDate) second.
-- Now both predicates are seekable: SQL Server seeks straight to CustomerId = 100
-- and then ranges over OrderDate, instead of scanning every order in the date range.
DROP INDEX IX_Orders_Date_Cust ON Orders;
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Date
    ON Orders(CustomerId, OrderDate) INCLUDE (Total);
SELECT CustomerId, OrderDate, Total FROM Orders
WHERE CustomerId = 100 AND OrderDate >= '2024-10-01';
