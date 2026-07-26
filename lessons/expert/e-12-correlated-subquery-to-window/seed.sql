IF DB_ID('Lesson_e_12_correlated_subquery_to_window') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_12_correlated_subquery_to_window SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_12_correlated_subquery_to_window;
END
GO
CREATE DATABASE Lesson_e_12_correlated_subquery_to_window;
GO
USE Lesson_e_12_correlated_subquery_to_window;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, Total)
SELECT (rn % 2000) + 1, CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
