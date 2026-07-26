-- Match the index key to the window spec exactly: (PARTITION BY CustomerId,
-- then ORDER BY OrderDate) => index key (CustomerId, OrderDate). Now the ordered
-- index feeds Segment + Sequence Project directly and the blocking Sort disappears.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Date
    ON Orders(CustomerId, OrderDate) INCLUDE (OrderId);
SELECT OrderId, CustomerId, OrderDate,
       ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY OrderDate) AS rn
FROM Orders;
