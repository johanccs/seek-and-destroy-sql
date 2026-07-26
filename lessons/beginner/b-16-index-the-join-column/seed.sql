CREATE TABLE Customers
(
    CustomerId INT CONSTRAINT PK_Customers PRIMARY KEY,
    Name       VARCHAR(50) NOT NULL
);
GO
INSERT INTO Customers (CustomerId, Name)
SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Customer'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
-- Orders has a CustomerId column but NO index on it: the join has nothing to seek.
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId, Total)
SELECT (rn % 3000) + 1, CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
