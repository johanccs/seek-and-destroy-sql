IF DB_ID('Lesson_e_20_residual_predicate') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_20_residual_predicate SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_20_residual_predicate;
END
GO
CREATE DATABASE Lesson_e_20_residual_predicate;
GO
USE Lesson_e_20_residual_predicate;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    Status     VARCHAR(12)   NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
-- 400,000 orders, only 100 customers (4,000 each). ~5% are 'Open'.
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, Status, Total)
SELECT (rn % 100) + 1,
       CASE WHEN (rn / 100) % 20 = 0 THEN 'Open' ELSE 'Closed' END,
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
-- Index on CustomerId only. It can seek to the customer, but Status is not in the
-- index -- so Status is applied as a residual predicate (after a per-row lookup).
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
