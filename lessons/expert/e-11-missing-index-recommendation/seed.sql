IF DB_ID('Lesson_e_11_missing_index_recommendation') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_11_missing_index_recommendation SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_11_missing_index_recommendation;
END
GO
CREATE DATABASE Lesson_e_11_missing_index_recommendation;
GO
USE Lesson_e_11_missing_index_recommendation;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATE          NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
-- 500,000 orders across 3,000 customers (~167 each). No index on CustomerId, so a
-- per-customer lookup scans -- and the optimizer will emit a missing-index hint.
;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total)
SELECT (rn % 3000) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-12-31' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
