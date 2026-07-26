-- Lesson b-08: Sargable date ranges vs. functions on a date column
IF DB_ID('Lesson_b_08_sargable_date_range') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_08_sargable_date_range SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_08_sargable_date_range;
END
GO
CREATE DATABASE Lesson_b_08_sargable_date_range;
GO
USE Lesson_b_08_sargable_date_range;
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
-- 200,000 rows spread evenly across two years (2024-01-01 .. 2025-12-31).
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
-- A covering index on OrderDate exists. It CAN seek a date range, but a function
-- wrapped around OrderDate hides the range and forces a full index scan instead.
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate
    ON dbo.Orders(OrderDate) INCLUDE (CustomerId, Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
