IF DB_ID('Lesson_b_05_select_star_lookup') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_05_select_star_lookup SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_05_select_star_lookup;
END
GO
CREATE DATABASE Lesson_b_05_select_star_lookup;
GO
USE Lesson_b_05_select_star_lookup;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT          NOT NULL,
    OrderDate  DATE         NOT NULL,
    Status     VARCHAR(12)  NOT NULL,
    Notes      VARCHAR(200) NOT NULL   -- wide column NOT in the index
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Status, Notes)
SELECT (rn % 10000) + 1,
       DATEADD(DAY, -(rn % 365), '2024-12-31'),
       CASE WHEN rn % 3 = 0 THEN 'Shipped' ELSE 'Completed' END,
       REPLICATE('n', 200)
FROM n;
GO
-- Index covers CustomerId + the common display columns, but NOT Notes.
CREATE NONCLUSTERED INDEX IX_Orders_Customer
    ON dbo.Orders(CustomerId) INCLUDE (OrderDate, Status);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
