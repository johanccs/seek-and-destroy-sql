-- Lesson b-01: Table Scan vs. Index Seek
IF DB_ID('Lesson_b_01_table_scan_vs_seek') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_01_table_scan_vs_seek SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_01_table_scan_vs_seek;
END
GO
CREATE DATABASE Lesson_b_01_table_scan_vs_seek;
GO
USE Lesson_b_01_table_scan_vs_seek;
GO
-- Orders has a CLUSTERED primary key on OrderId but NO index on CustomerId.
-- Filtering by CustomerId therefore forces a full Clustered Index Scan.
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT          NOT NULL,
    OrderDate  DATETIME2(0) NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)  NOT NULL
);
GO
-- 200,000 rows across 5,000 customers => ~40 rows per customer.
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
