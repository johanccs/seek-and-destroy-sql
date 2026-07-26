IF DB_ID('Lesson_e_17_multitable_join_missing_index') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_17_multitable_join_missing_index SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_17_multitable_join_missing_index;
END
GO
CREATE DATABASE Lesson_e_17_multitable_join_missing_index;
GO
USE Lesson_e_17_multitable_join_missing_index;
GO
CREATE TABLE dbo.Customers (CustomerId INT CONSTRAINT PK_Customers PRIMARY KEY, Name VARCHAR(50) NOT NULL);
INSERT INTO dbo.Customers SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Cust'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT NOT NULL
);
;WITH n AS (SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId) SELECT (rn % 3000) + 1 FROM n;
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);
GO
-- OrderLines has NO index on OrderId: the deepest join has nothing to seek.
CREATE TABLE dbo.OrderLines
(
    LineId  INT IDENTITY(1,1) CONSTRAINT PK_OrderLines PRIMARY KEY CLUSTERED,
    OrderId INT           NOT NULL,
    Amount  DECIMAL(10,2) NOT NULL
);
;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.OrderLines (OrderId, Amount) SELECT (rn % 100000) + 1, CAST((rn % 500) + 1 AS DECIMAL(10,2)) FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.OrderLines WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO
