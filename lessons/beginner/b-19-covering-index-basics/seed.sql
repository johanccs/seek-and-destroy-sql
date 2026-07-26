IF DB_ID('Lesson_b_19_covering_index_basics') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_19_covering_index_basics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_19_covering_index_basics;
END
GO
CREATE DATABASE Lesson_b_19_covering_index_basics;
GO
USE Lesson_b_19_covering_index_basics;
GO
CREATE TABLE dbo.Products
(
    ProductId INT IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY CLUSTERED,
    Sku       VARCHAR(20)   NOT NULL,
    Name      VARCHAR(100)  NOT NULL,
    Price     DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Products (Sku, Name, Price)
SELECT 'SKU' + RIGHT('000000' + CAST(rn AS VARCHAR(6)), 6),
       'Product ' + CAST(rn AS VARCHAR(10)),
       CAST((rn % 1000) + 0.99 AS DECIMAL(10,2))
FROM n;
GO
-- Index on Sku only: it can seek to the row, but Name/Price aren't in the index.
CREATE UNIQUE NONCLUSTERED INDEX IX_Products_Sku ON dbo.Products(Sku);
GO
UPDATE STATISTICS dbo.Products WITH FULLSCAN;
GO
