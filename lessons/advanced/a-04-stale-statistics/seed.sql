CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId);
GO
-- Seed a SMALL amount with CustomerId values 1..50, so the histogram's MAXIMUM
-- key value is 50. Statistics believe the table is tiny and stops at 50.
INSERT INTO Orders (CustomerId, Total)
SELECT TOP (1000) (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 50) + 1, 10.0
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
-- NORECOMPUTE freezes THIS statistics object (scoped, not database-wide) so the
-- histogram stays stale (topping out at CustomerId = 50) after the flood insert below.
UPDATE STATISTICS Orders WITH FULLSCAN, NORECOMPUTE;
GO
-- Ascending-key problem: flood a NEW CustomerId = 999 with 300k rows. 999 is
-- BEYOND the histogram's max (50), so without a stats refresh the optimizer
-- estimates ~1 matching row for CustomerId = 999 while 300k actually match.
INSERT INTO Orders (CustomerId, Total)
SELECT TOP (300000) 999, 10.0
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
