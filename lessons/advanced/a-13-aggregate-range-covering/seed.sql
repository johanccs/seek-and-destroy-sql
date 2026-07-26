-- Lesson a-13: covering index for a filtered aggregate
IF DB_ID('Lesson_a_13_aggregate_range_covering') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_13_aggregate_range_covering SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_13_aggregate_range_covering;
END
GO
CREATE DATABASE Lesson_a_13_aggregate_range_covering;
GO
USE Lesson_a_13_aggregate_range_covering;
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
-- 200,000 rows across two years. Only the clustered PK exists, so a report that
-- filters on OrderDate must scan the whole table before aggregating.
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
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
