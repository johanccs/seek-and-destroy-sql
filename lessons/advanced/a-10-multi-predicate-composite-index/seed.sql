-- Lesson a-10: Composite index for two equality predicates
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL
);
GO
-- 200,000 rows. Status is ~1/3 each of Open/Shipped/Closed; 5,000 customers.
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
-- Only Status is indexed. A query filtering Status AND CustomerId can seek Status
-- (~66k rows) but must then evaluate CustomerId as a residual — or the optimizer
-- gives up and scans the clustered index outright.
CREATE NONCLUSTERED INDEX IX_Orders_Status ON Orders(Status);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
