CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT           NOT NULL,
    OrderDate  DATE          NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(12)   NOT NULL
);
GO
-- Heavily SKEWED distribution: 'Open' is rare (~200 rows) while 'Closed' and
-- 'Shipped' dominate (~150k each). This skew is what makes a single average
-- estimate wrong for the rare value.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 3000) + 1, DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2)),
       CASE WHEN rn <= 200 THEN 'Open' WHEN rn % 2 = 0 THEN 'Closed' ELSE 'Shipped' END
FROM n;
GO
-- A NON-covering index on Status: a seek here still needs a key lookup for the
-- other selected columns, so the optimizer only picks it when it believes few
-- rows match. That decision depends entirely on the row estimate.
CREATE NONCLUSTERED INDEX IX_Orders_Status ON Orders(Status);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
