-- Lesson i-14: an index can only seek on a prefix of its keys
IF DB_ID('Lesson_i_14_leading_column_mismatch') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_14_leading_column_mismatch SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_14_leading_column_mismatch;
END
GO
CREATE DATABASE Lesson_i_14_leading_column_mismatch;
GO
USE Lesson_i_14_leading_column_mismatch;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    ProductId  INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
-- 200,000 rows: 5,000 customers, 1,000 products (~200 rows per product).
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, ProductId, OrderDate, Total)
SELECT (rn % 5000) + 1,
       (rn % 1000) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2026-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2))
FROM n;
GO
-- The only nonclustered index leads with CustomerId, then ProductId.
-- A query filtering ONLY on ProductId cannot seek it (ProductId is not the
-- leading key), so SQL Server must scan.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Prod ON dbo.Orders(CustomerId, ProductId) INCLUDE (Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
