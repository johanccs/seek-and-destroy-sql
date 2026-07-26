-- A composite index on BOTH equality columns (plus INCLUDE to cover the SELECT)
-- lets SQL Server seek straight to the ~13 matching rows.
CREATE NONCLUSTERED INDEX IX_Orders_Status_Cust
    ON Orders(Status, CustomerId) INCLUDE (OrderDate, Total);

SELECT OrderId, CustomerId, OrderDate, Total, Status
FROM Orders
WHERE Status = 'Open' AND CustomerId = 42;
