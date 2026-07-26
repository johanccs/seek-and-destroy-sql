IF DB_ID('Lesson_e_01_scalar_udf_predicate') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_01_scalar_udf_predicate SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_01_scalar_udf_predicate;
END
GO
CREATE DATABASE Lesson_e_01_scalar_udf_predicate;
GO
-- Compatibility level 140 (SQL Server 2017) so scalar UDF inlining (a 2019+/150
-- feature) does NOT rescue us. This is the world most scalar-UDF predicates live in:
-- a hidden, row-by-row function call that blocks both the seek and parallelism.
ALTER DATABASE Lesson_e_01_scalar_udf_predicate SET COMPATIBILITY_LEVEL = 140;
GO
USE Lesson_e_01_scalar_udf_predicate;
GO
CREATE TABLE dbo.Orders
(
    OrderId INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    Total   DECIMAL(10,2) NOT NULL
);
GO
-- 400k rows. Most totals are small; a small deterministic set (~300) exceeds 1000,
-- so both the slow and the fast form return the SAME ~300 rows.
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (Total)
SELECT CASE WHEN rn <= 300 THEN 1500.00 ELSE CAST((rn % 900) AS DECIMAL(10,2)) END
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_Total ON dbo.Orders(Total);
GO
-- A trivial scalar function: net = gross * 0.9. Harmless-looking, ruinous in a WHERE.
CREATE FUNCTION dbo.fn_NetAmount(@gross DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN @gross * 0.90;
END
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
