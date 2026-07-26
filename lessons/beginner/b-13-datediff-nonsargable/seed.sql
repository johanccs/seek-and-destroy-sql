-- Lesson b-13: DATEDIFF on a column blocks the seek
IF DB_ID('Lesson_b_13_datediff_nonsargable') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_13_datediff_nonsargable SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_13_datediff_nonsargable;
END
GO
CREATE DATABASE Lesson_b_13_datediff_nonsargable;
GO
USE Lesson_b_13_datediff_nonsargable;
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
-- 200,000 rows spread across ~2 years ending 2026-01-01, with a time-of-day component
-- so CAST-free date ranges still work but function-wrapping does not.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(SECOND, (rn * 37) % 86400,
               DATEADD(DAY, -(rn % 730), CAST('2026-01-01' AS DATETIME2(0)))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
-- A covering index on OrderDate CAN seek a date range -- but only if the predicate
-- leaves OrderDate bare. DATEDIFF(DAY, OrderDate, ...) hides the range and forces a scan.
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate
    ON dbo.Orders(OrderDate) INCLUDE (CustomerId, Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
