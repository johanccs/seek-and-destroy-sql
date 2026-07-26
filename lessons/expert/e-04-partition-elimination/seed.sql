-- Lesson e-04: Partition Elimination (LARGE SCALE ~1.2M rows)
-- Partition functions/schemes are DATABASE-scoped (not owned by any schema), so they
-- survive the generic per-lesson schema cleanup and must be dropped here explicitly
-- before recreating (scheme before function -- a function can't drop while referenced).
IF EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = 'ps_OrderMonth') DROP PARTITION SCHEME ps_OrderMonth;
IF EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = 'pf_OrderMonth') DROP PARTITION FUNCTION pf_OrderMonth;
GO
-- Monthly partitions across 2025. RANGE RIGHT: a boundary value belongs to the partition
-- to its RIGHT, so '2025-06-01' starts the June partition.
CREATE PARTITION FUNCTION pf_OrderMonth (DATETIME2(0))
AS RANGE RIGHT FOR VALUES
(
    '2025-02-01', '2025-03-01', '2025-04-01', '2025-05-01',
    '2025-06-01', '2025-07-01', '2025-08-01', '2025-09-01',
    '2025-10-01', '2025-11-01', '2025-12-01'
);
GO
CREATE PARTITION SCHEME ps_OrderMonth
AS PARTITION pf_OrderMonth ALL TO ([PRIMARY]);
GO
-- The partition column (OrderDate) must be part of the clustered key.
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) NOT NULL,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderDate, OrderId)
) ON ps_OrderMonth (OrderDate);
GO
-- 1,200,000 rows spread across the 12 months of 2025 (~100k per month).
;WITH n AS
(
    SELECT TOP (1200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
)
INSERT INTO Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, rn % 365, CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
