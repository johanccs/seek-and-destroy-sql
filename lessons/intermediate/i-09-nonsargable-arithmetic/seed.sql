-- Lesson i-09: Arithmetic on an indexed column blocks the seek
IF DB_ID('Lesson_i_09_nonsargable_arithmetic') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_09_nonsargable_arithmetic SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_09_nonsargable_arithmetic;
END
GO
CREATE DATABASE Lesson_i_09_nonsargable_arithmetic;
GO
USE Lesson_i_09_nonsargable_arithmetic;
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
-- 200,000 rows. Total ranges 0.00 .. 1498.50.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
-- Covering index on Total can seek a range on Total -- IF the column is left bare.
CREATE NONCLUSTERED INDEX IX_Orders_Total ON dbo.Orders(Total) INCLUDE (CustomerId, OrderDate);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
