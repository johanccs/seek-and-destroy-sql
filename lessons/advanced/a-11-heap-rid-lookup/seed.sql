-- Lesson a-11: Heaps and RID Lookups
-- Orders is a HEAP: no clustered index / no clustered primary key.
-- A nonclustered index seek must RID-lookup into the heap for uncovered columns.
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) NOT NULL,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL
);
GO
-- 200,000 rows across 5,000 customers => ~40 rows per customer.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
-- A nonclustered index on CustomerId only. It does NOT cover OrderDate/Total/Status,
-- so a query needing those columns must RID-lookup into the heap (a Nested Loops).
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
