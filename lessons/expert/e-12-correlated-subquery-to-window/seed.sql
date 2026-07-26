CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId, Total)
SELECT (rn % 2000) + 1, CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
