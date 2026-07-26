-- Lesson b-14: SUBSTRING/LEFT on a column blocks the seek; LIKE 'prefix%' seeks
IF DB_ID('Lesson_b_14_nonsargable_substring') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_14_nonsargable_substring SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_14_nonsargable_substring;
END
GO
CREATE DATABASE Lesson_b_14_nonsargable_substring;
GO
USE Lesson_b_14_nonsargable_substring;
GO
CREATE TABLE dbo.Products
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
INSERT INTO dbo.Products (Sku, Name, Price)
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
CREATE NONCLUSTERED INDEX IX_Products_Sku ON dbo.Products(Sku) INCLUDE (Name, Price);
GO
UPDATE STATISTICS dbo.Products WITH FULLSCAN;
GO
