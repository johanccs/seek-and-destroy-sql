-- Lesson b-10: Getting the Latest Row — TOP 1 needs an index
IF DB_ID('Lesson_b_10_top1_latest') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_10_top1_latest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_10_top1_latest;
END
GO
CREATE DATABASE Lesson_b_10_top1_latest;
GO
USE Lesson_b_10_top1_latest;
GO
-- Orders is clustered on OrderId. There is NO index on OrderDate, so "the most recent
-- order" (ORDER BY OrderDate DESC) forces a full scan plus a Top-N sort.
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(3)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL
);
GO
-- 200,000 rows. OrderDate is UNIQUE (one second apart) so "the latest row" is deterministic.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(SECOND, rn, CAST('2024-01-01' AS DATETIME2(3))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
