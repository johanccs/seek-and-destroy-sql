CREATE TABLE Orders
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
INSERT INTO Orders (CustomerId, OrderDate, Total, Status)
SELECT (rn % 3000) + 1, DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END
FROM n;
GO
-- A small "suppression" list, stored as a heap with a NULLABLE key column and no
-- index. The nullable column is what makes NOT IN dangerous: the optimizer must
-- build a NULL-aware anti-join and, with no index to probe, re-scans this table.
CREATE TABLE Suppressed (CustomerId INT NULL);
INSERT INTO Suppressed (CustomerId) VALUES (1),(2),(3),(4),(5);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS Suppressed WITH FULLSCAN;
GO
