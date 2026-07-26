CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT           NOT NULL,
    OrderDate  DATE          NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId, OrderDate, Total)
SELECT (rn % 3000) + 1, DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
-- This index COVERS the query (OrderDate + Total are carried), but OrderDate is an
-- INCLUDE column, not a key -- so the seeked rows are NOT ordered by OrderDate.
-- The ORDER BY therefore still needs a separate Sort.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId) INCLUDE (OrderDate, Total);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
