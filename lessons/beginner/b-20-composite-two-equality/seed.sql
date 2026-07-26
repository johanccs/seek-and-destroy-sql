IF DB_ID('Lesson_b_20_composite_two_equality') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_20_composite_two_equality SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_20_composite_two_equality;
END
GO
CREATE DATABASE Lesson_b_20_composite_two_equality;
GO
USE Lesson_b_20_composite_two_equality;
GO
CREATE TABLE dbo.Inventory
(
    InventoryId INT IDENTITY(1,1) CONSTRAINT PK_Inventory PRIMARY KEY CLUSTERED,
    WarehouseId INT NOT NULL,
    ProductId   INT NOT NULL,
    Qty         INT NOT NULL
);
GO
-- 300,000 rows across 50 warehouses x 6,000 products: any one (warehouse, product)
-- pair is a tiny set, but neither column alone is very selective.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Inventory (WarehouseId, ProductId, Qty)
SELECT (rn % 50) + 1, (rn % 6000) + 1, (rn % 500)
FROM n;
GO
UPDATE STATISTICS dbo.Inventory WITH FULLSCAN;
GO
