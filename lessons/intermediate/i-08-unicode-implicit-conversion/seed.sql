-- Lesson i-08: The Unicode parameter trap (NVARCHAR literal vs VARCHAR column)
IF DB_ID('Lesson_i_08_unicode_implicit_conversion') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_08_unicode_implicit_conversion SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_08_unicode_implicit_conversion;
END
GO
CREATE DATABASE Lesson_i_08_unicode_implicit_conversion;
GO
USE Lesson_i_08_unicode_implicit_conversion;
GO
CREATE TABLE dbo.Products
(
    ProductId INT IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY CLUSTERED,
    Sku       VARCHAR(20)   NOT NULL,
    Name      VARCHAR(100)  NOT NULL,
    Price     DECIMAL(10,2) NOT NULL
);
GO
-- 200,000 products with a unique VARCHAR Sku like 'SKU000001'.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Products (Sku, Name, Price)
SELECT 'SKU' + RIGHT('000000' + CAST(rn AS VARCHAR(6)), 6),
       'Product ' + CAST(rn AS VARCHAR(10)),
       CAST((rn % 1000) + 0.99 AS DECIMAL(10,2))
FROM n;
GO
-- A unique nonclustered index supports point lookups on Sku -- IF the predicate is sargable.
CREATE UNIQUE NONCLUSTERED INDEX IX_Products_Sku ON dbo.Products(Sku);
GO
UPDATE STATISTICS dbo.Products WITH FULLSCAN;
GO
