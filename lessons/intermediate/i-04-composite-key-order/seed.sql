IF DB_ID('Lesson_i_04_composite_key_order') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_04_composite_key_order SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_04_composite_key_order;
END
GO
CREATE DATABASE Lesson_i_04_composite_key_order;
GO
USE Lesson_i_04_composite_key_order;
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
-- WRONG KEY ORDER: the range column (OrderDate) leads, so the equality
-- predicate (CustomerId) can only be applied as a residual, not a seek.
-- Note the index already covers Total via INCLUDE, so covering is NOT the
-- issue in this lesson -- only the key column order is.
CREATE NONCLUSTERED INDEX IX_Orders_Date_Cust
    ON dbo.Orders(OrderDate, CustomerId) INCLUDE (Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
