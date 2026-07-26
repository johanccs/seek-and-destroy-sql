CREATE TABLE Sales
(
    SaleId   INT IDENTITY(1,1) CONSTRAINT PK_Sales PRIMARY KEY CLUSTERED,
    StoreId  INT           NOT NULL,
    SaleDate DATE          NOT NULL,
    Amount   DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Sales (StoreId, SaleDate, Amount)
SELECT (rn % 200) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-12-31' AS DATE)),
       CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS Sales WITH FULLSCAN;
GO
