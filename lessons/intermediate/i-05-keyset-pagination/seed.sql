IF DB_ID('Lesson_i_05_keyset_pagination') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_05_keyset_pagination SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_05_keyset_pagination;
END
GO
CREATE DATABASE Lesson_i_05_keyset_pagination;
GO
USE Lesson_i_05_keyset_pagination;
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
-- 300,000 rows. OrderId is the clustered key, contiguous 1..300000, so it is a
-- perfect pagination cursor. The "deep page" query still pays to walk past every
-- earlier row because OFFSET has no way to jump ahead.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 3000) + 1, DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
