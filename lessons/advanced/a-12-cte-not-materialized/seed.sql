-- Lesson a-12: CTEs are not materialized
IF DB_ID('Lesson_a_12_cte_not_materialized') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_12_cte_not_materialized SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_12_cte_not_materialized;
END
GO
CREATE DATABASE Lesson_a_12_cte_not_materialized;
GO
USE Lesson_a_12_cte_not_materialized;
GO
-- No nonclustered index: aggregating Orders requires a full scan EACH time it is evaluated.
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL
);
GO
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
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
