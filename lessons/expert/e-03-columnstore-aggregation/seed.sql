IF DB_ID('Lesson_e_03_columnstore_aggregation') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_03_columnstore_aggregation SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_03_columnstore_aggregation;
END
GO
CREATE DATABASE Lesson_e_03_columnstore_aggregation;
GO
USE Lesson_e_03_columnstore_aggregation;
GO
CREATE TABLE dbo.FactSales
(
    SaleId    INT IDENTITY(1,1) CONSTRAINT PK_FactSales PRIMARY KEY,
    ProductId INT           NOT NULL,
    StoreId   INT           NOT NULL,
    SaleDate  DATE          NOT NULL,
    Amount    DECIMAL(10,2) NOT NULL
);
GO
-- 1,000,000-row fact table stored as a rowstore heap/clustered index. An
-- analytic aggregation over the whole table must scan every page in row form.
;WITH n AS (SELECT TOP (1000000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c)
INSERT INTO dbo.FactSales (ProductId, StoreId, SaleDate, Amount)
SELECT (rn % 200) + 1, (rn % 50) + 1,
       DATEADD(DAY, -(rn % 730), CAST('2025-01-01' AS DATE)),
       CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.FactSales WITH FULLSCAN;
GO
