IF DB_ID('Lesson_b_16_index_the_join_column') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_16_index_the_join_column SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_16_index_the_join_column;
END
GO
CREATE DATABASE Lesson_b_16_index_the_join_column;
GO
USE Lesson_b_16_index_the_join_column;
GO
CREATE TABLE dbo.Customers
(
    CustomerId INT CONSTRAINT PK_Customers PRIMARY KEY,
    Name       VARCHAR(50) NOT NULL
);
GO
INSERT INTO dbo.Customers (CustomerId, Name)
SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Customer'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
-- Orders has a CustomerId column but NO index on it: the join has nothing to seek.
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, Total)
SELECT (rn % 3000) + 1, CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO
