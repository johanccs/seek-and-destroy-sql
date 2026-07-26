-- Lesson a-14: Covering index for a join + selective filter
IF DB_ID('Lesson_a_14_covering_join_and_filter') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_14_covering_join_and_filter SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_14_covering_join_and_filter;
END
GO
CREATE DATABASE Lesson_a_14_covering_join_and_filter;
GO
USE Lesson_a_14_covering_join_and_filter;
GO
CREATE TABLE dbo.Customers
(
    CustomerId INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED,
    Region VARCHAR(20)  NOT NULL,
    Name   VARCHAR(100) NOT NULL
);
GO
-- 5,000 customers across 100 regions => ~50 customers per region (very selective).
;WITH n AS
(
    SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Customers (Region, Name)
SELECT 'R' + CAST(rn % 100 AS VARCHAR(3)),
       'Customer ' + CAST(rn AS VARCHAR(7))
FROM n;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL
);
GO
-- 200,000 orders across the 5,000 customers (~40 each). No index on CustomerId/Status,
-- so the join + filter forces a hash join that scans the whole Orders table.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, rn % 730, CAST('2024-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
