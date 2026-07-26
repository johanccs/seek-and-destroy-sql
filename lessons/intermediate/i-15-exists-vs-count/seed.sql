-- Lesson i-15: EXISTS vs COUNT(*) for existence checks
IF DB_ID('Lesson_i_15_exists_vs_count') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_15_exists_vs_count SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_15_exists_vs_count;
END
GO
CREATE DATABASE Lesson_i_15_exists_vs_count;
GO
USE Lesson_i_15_exists_vs_count;
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
-- 200,000 orders, roughly one-third in each status.
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
-- An index on Status supports both the COUNT range scan and the EXISTS single-row seek.
CREATE NONCLUSTERED INDEX IX_Orders_Status ON dbo.Orders(Status);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
