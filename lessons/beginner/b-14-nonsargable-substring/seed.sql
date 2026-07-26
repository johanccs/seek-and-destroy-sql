-- Lesson b-14: SUBSTRING/LEFT on a column blocks the seek; LIKE 'prefix%' seeks
CREATE TABLE Products
(
    ProductId INT IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY CLUSTERED,
    Sku       VARCHAR(20)   NOT NULL,
    Name      VARCHAR(100)  NOT NULL,
    Price     DECIMAL(10,2) NOT NULL
);
GO
-- 200,000 products. Sku = 4-char category + 6-digit sequence (unique).
-- ~20 categories, so the 'ELEC' prefix is ~5% (~10,000 rows).
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Products (Sku, Name, Price)
SELECT
    CASE WHEN rn % 20 = 0 THEN 'ELEC'
         ELSE 'C' + RIGHT('000' + CAST(rn % 20 AS VARCHAR(3)), 3)
    END + RIGHT('000000' + CAST(rn AS VARCHAR(6)), 6),
    'Product ' + CAST(rn AS VARCHAR(10)),
    CAST((rn % 1000) * 1.5 AS DECIMAL(10,2))
FROM n;
GO
-- A covering index on Sku exists. LIKE 'ELEC%' can seek the range;
-- SUBSTRING(Sku,1,4)='ELEC' hides the prefix and forces a full index scan.
CREATE NONCLUSTERED INDEX IX_Products_Sku ON Products(Sku) INCLUDE (Name, Price);
GO
UPDATE STATISTICS Products WITH FULLSCAN;
GO
