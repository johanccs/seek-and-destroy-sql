CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    Status     VARCHAR(12)   NOT NULL,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
-- 400k rows. Status is heavily skewed: ~99% 'Completed', ~1% 'Pending'.
-- Queries for the RARE 'Pending' rows are exactly where a filtered index shines.
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (Status, CustomerId, Total)
SELECT CASE WHEN rn % 100 = 0 THEN 'Pending' ELSE 'Completed' END,
       (rn % 50000) + 1,
       CAST((rn % 1000) AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
