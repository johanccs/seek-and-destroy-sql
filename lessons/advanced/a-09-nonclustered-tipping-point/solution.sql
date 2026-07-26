-- Make the index COVERING with INCLUDE so the range predicate can be satisfied
-- entirely from the index — no key lookups, no clustered scan. Now the optimizer
-- happily chooses a range Index Seek even for ~32k matching rows.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Cov
    ON dbo.Orders(CustomerId) INCLUDE (OrderDate, Total, Status);

SELECT CustomerId, OrderDate, Total, Status FROM Orders WHERE CustomerId <= 800;
