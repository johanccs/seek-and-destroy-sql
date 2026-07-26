-- Lesson b-09: COUNT(*) uses the narrowest available index
IF DB_ID('Lesson_b_09_count_narrow_index') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_09_count_narrow_index SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_09_count_narrow_index;
END
GO
CREATE DATABASE Lesson_b_09_count_narrow_index;
GO
USE Lesson_b_09_count_narrow_index;
GO
-- Wide rows: the CHAR(200) Filler bloats the clustered index so a full scan
-- (which COUNT(*) needs) reads thousands of pages. There is NO narrow index.
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL,
    Region     TINYINT       NOT NULL,
    Filler     CHAR(200)     NOT NULL
);
GO
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status, Region, Filler)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, rn % 365, CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END,
       rn % 5,
       REPLICATE('x', 200)
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
