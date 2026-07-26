IF DB_ID('Lesson_e_15_function_on_join_column') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_15_function_on_join_column SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_15_function_on_join_column;
END
GO
CREATE DATABASE Lesson_e_15_function_on_join_column;
GO
USE Lesson_e_15_function_on_join_column;
GO
CREATE TABLE dbo.Customers
(
    CustomerId INT CONSTRAINT PK_Customers PRIMARY KEY,
    Ref        VARCHAR(20) NOT NULL
);
GO
INSERT INTO dbo.Customers (CustomerId, Ref)
SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
       'CUST' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(6)), 6)
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE TABLE dbo.Orders
(
    OrderId     INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerRef VARCHAR(20)   NOT NULL,
    Total       DECIMAL(10,2) NOT NULL
);
GO
-- CustomerRef is already uppercase and matches Customers.Ref exactly.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerRef, Total)
SELECT 'CUST' + RIGHT('000000' + CAST(((rn % 3000) + 1) AS VARCHAR(6)), 6),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerRef ON dbo.Orders(CustomerRef) INCLUDE (Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO
