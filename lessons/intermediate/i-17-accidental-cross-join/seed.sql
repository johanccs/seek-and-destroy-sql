IF DB_ID('Lesson_i_17_accidental_cross_join') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_17_accidental_cross_join SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_17_accidental_cross_join;
END
GO
CREATE DATABASE Lesson_i_17_accidental_cross_join;
GO
USE Lesson_i_17_accidental_cross_join;
GO
CREATE TABLE dbo.Customers
(
    CustomerId INT         CONSTRAINT PK_Customers PRIMARY KEY,
    Name       VARCHAR(50) NOT NULL
);
GO
INSERT INTO dbo.Customers (CustomerId, Name)
SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Customer ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (20000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, Total)
SELECT (rn % 500) + 1, CAST((rn % 1000) + 1 AS DECIMAL(10,2))
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO
