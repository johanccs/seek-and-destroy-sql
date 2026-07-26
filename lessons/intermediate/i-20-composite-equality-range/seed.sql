IF DB_ID('Lesson_i_20_composite_equality_range') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_20_composite_equality_range SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_20_composite_equality_range;
END
GO
CREATE DATABASE Lesson_i_20_composite_equality_range;
GO
USE Lesson_i_20_composite_equality_range;
GO
CREATE TABLE dbo.Sales
(
    SaleId   INT IDENTITY(1,1) CONSTRAINT PK_Sales PRIMARY KEY CLUSTERED,
    StoreId  INT           NOT NULL,
    SaleDate DATE          NOT NULL,
    Amount   DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Sales (StoreId, SaleDate, Amount)
SELECT (rn % 200) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-12-31' AS DATE)),
       CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.Sales WITH FULLSCAN;
GO
