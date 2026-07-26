-- Lesson e-05: Forwarded Records in Heaps
-- Orders is a HEAP (no clustered index). Rows start small (Notes NULL) and are packed
-- densely onto pages.
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) NOT NULL,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Notes      VARCHAR(4000) NULL
);
GO
-- 100,000 small rows.
;WITH n AS
(
    SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Orders (CustomerId, OrderDate, Total, Notes)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       NULL
FROM n;
GO
-- Now grow half the rows in place: they no longer fit their original page, so the heap
-- leaves a FORWARDING POINTER and migrates the row -> ~50,000 forwarded records.
UPDATE Orders SET Notes = REPLICATE('x', 2000) WHERE OrderId % 2 = 0;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
