IF DB_ID('Lesson_e_02_window_sort_elimination') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_02_window_sort_elimination SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_02_window_sort_elimination;
END
GO
CREATE DATABASE Lesson_e_02_window_sort_elimination;
GO
USE Lesson_e_02_window_sort_elimination;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT           NOT NULL,
    OrderDate  DATE          NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(12)   NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 3000) + 1, DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
-- Nothing is ordered by (CustomerId, OrderDate), so the window's
-- PARTITION BY / ORDER BY must be satisfied by an explicit, blocking Sort.
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
