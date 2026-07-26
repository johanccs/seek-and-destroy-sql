CREATE TABLE FactSales
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
INSERT INTO FactSales (ProductId, StoreId, SaleDate, Amount)
SELECT (rn % 200) + 1, (rn % 50) + 1,
       DATEADD(DAY, -(rn % 730), CAST('2025-01-01' AS DATE)),
       CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS FactSales WITH FULLSCAN;
GO
