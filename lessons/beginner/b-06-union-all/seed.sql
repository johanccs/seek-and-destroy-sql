IF DB_ID('Lesson_b_06_union_all') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_06_union_all SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_06_union_all;
END
GO
CREATE DATABASE Lesson_b_06_union_all;
GO
USE Lesson_b_06_union_all;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT           NOT NULL,
    OrderDate  DATE          NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total)
SELECT (rn % 3000) + 1, DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
-- OrderId is unique and the two customer ids never overlap, so the two halves of
-- the query are guaranteed disjoint -- there are no duplicates to remove.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId) INCLUDE (Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
