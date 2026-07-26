IF DB_ID('Lesson_b_04_order_by_sort') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_04_order_by_sort SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_04_order_by_sort;
END
GO
CREATE DATABASE Lesson_b_04_order_by_sort;
GO
USE Lesson_b_04_order_by_sort;
GO
CREATE TABLE dbo.Products
(
    ProductId INT IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY,
    Name      VARCHAR(50)   NOT NULL,
    Price     DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Products (Name, Price)
SELECT 'Product ' + CAST(rn AS VARCHAR(10)),
       CAST((rn * 7 % 1000000) AS DECIMAL(10,2)) / 100.0
FROM n;
GO
UPDATE STATISTICS dbo.Products WITH FULLSCAN;
GO
