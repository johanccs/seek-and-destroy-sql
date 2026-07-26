-- Lesson i-12: MIN/MAX reads just the ends of an index
IF DB_ID('Lesson_i_12_min_max_index') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_12_min_max_index SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_12_min_max_index;
END
GO
CREATE DATABASE Lesson_i_12_min_max_index;
GO
USE Lesson_i_12_min_max_index;
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
-- 200,000 rows. NOTHING indexes OrderDate, so MIN/MAX must scan the whole table.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(MINUTE, rn, CAST('2024-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
