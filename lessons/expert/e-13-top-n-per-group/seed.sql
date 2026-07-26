IF DB_ID('Lesson_e_13_top_n_per_group') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_13_top_n_per_group SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_13_top_n_per_group;
END
GO
CREATE DATABASE Lesson_e_13_top_n_per_group;
GO
USE Lesson_e_13_top_n_per_group;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2     NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total)
SELECT (rn % 3000) + 1,
       DATEADD(MINUTE, -rn, CAST('2025-12-31T00:00:00' AS DATETIME2)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
