IF DB_ID('Lesson_a_05_join_missing_index') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_05_join_missing_index SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_05_join_missing_index;
END
GO
CREATE DATABASE Lesson_a_05_join_missing_index;
GO
USE Lesson_a_05_join_missing_index;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT NOT NULL
);
GO
CREATE TABLE dbo.OrderItems
(
    ItemId   INT IDENTITY(1,1) CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderId  INT NOT NULL,          -- foreign key to Orders, but DELIBERATELY unindexed
    Sku      VARCHAR(20) NOT NULL,
    Qty      INT NOT NULL
);
GO
-- 50k orders, ~600k order items (about 12 per order).
;WITH n AS (SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId) SELECT (rn % 5000) + 1 FROM n;
GO
;WITH n AS (SELECT TOP (600000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.OrderItems (OrderId, Sku, Qty)
SELECT (rn % 50000) + 1, 'SKU-' + CAST((rn % 2000) AS VARCHAR(10)), (rn % 5) + 1
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.OrderItems WITH FULLSCAN;
GO
