-- Cover the query with an INCLUDE index so the seek needs no RID lookup into the heap.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Cov
    ON dbo.Orders(CustomerId) INCLUDE (OrderDate, Total, Status);

-- Same query is now a single covering Index Seek -- no Nested Loops / RID Lookup.
SELECT CustomerId, OrderDate, Total, Status FROM Orders WHERE CustomerId = 42;
