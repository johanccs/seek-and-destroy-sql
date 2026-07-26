-- Lesson e-07: A nonclustered columnstore index (NCCI) for analytics over an OLTP rowstore table
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL
);
GO
-- 500,000 rows -- a rowstore OLTP table also asked to serve an analytical GROUP BY.
;WITH n AS
(
    SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, -(rn % 730), CAST('2026-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 4 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' WHEN 2 THEN 'Closed' ELSE 'Cancelled' END
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
