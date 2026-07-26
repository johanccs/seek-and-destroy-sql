IF DB_ID('Lesson_a_04_stale_statistics') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_04_stale_statistics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_04_stale_statistics;
END
GO
CREATE DATABASE Lesson_a_04_stale_statistics;
GO
USE Lesson_a_04_stale_statistics;
GO
-- Disable auto-update stats so the histogram stays stale after the big insert.
ALTER DATABASE Lesson_a_04_stale_statistics SET AUTO_UPDATE_STATISTICS OFF;
GO
-- Put the database on an older compatibility level (SQL Server 2012 = 110), which
-- uses the LEGACY cardinality estimator. This is itself a common real-world
-- performance trap (databases upgraded in-place but never bumped past an old compat
-- level) and it makes the ascending-key misestimate reproducible: a value above the
-- histogram's top boundary is estimated at exactly 1 row.
ALTER DATABASE Lesson_a_04_stale_statistics SET COMPATIBILITY_LEVEL = 110;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);
GO
-- Seed a SMALL amount with CustomerId values 1..50, so the histogram's MAXIMUM
-- key value is 50. Statistics believe the table is tiny and stops at 50.
INSERT INTO dbo.Orders (CustomerId, Total)
SELECT TOP (1000) (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 50) + 1, 10.0
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;   -- histogram now tops out at CustomerId = 50
GO
-- Ascending-key problem: flood a NEW CustomerId = 999 with 300k rows. 999 is
-- BEYOND the histogram's max (50), so without a stats refresh the optimizer
-- estimates ~1 matching row for CustomerId = 999 while 300k actually match.
INSERT INTO dbo.Orders (CustomerId, Total)
SELECT TOP (300000) 999, 10.0
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
