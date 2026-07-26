CREATE TABLE Customers
(
    CustomerId INT         CONSTRAINT PK_Customers PRIMARY KEY,
    Name       VARCHAR(50) NOT NULL
);
GO
INSERT INTO Customers (CustomerId, Name)
SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Customer ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT           NOT NULL,
    Total      DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (20000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId, Total)
SELECT (rn % 500) + 1, CAST((rn % 1000) + 1 AS DECIMAL(10,2))
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
