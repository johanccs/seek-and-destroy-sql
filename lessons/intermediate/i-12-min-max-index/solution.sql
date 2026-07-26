-- An index on OrderDate lets SQL read the smallest and largest values from
-- the two ends of the index instead of scanning every row.
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON Orders(OrderDate);

SELECT MIN(OrderDate) AS Earliest, MAX(OrderDate) AS Latest FROM Orders;
