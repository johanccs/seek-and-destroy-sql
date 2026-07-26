CREATE TABLE Customers (CustomerId INT CONSTRAINT PK_Customers PRIMARY KEY, Name VARCHAR(50) NOT NULL);
INSERT INTO Customers SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Cust'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT NOT NULL
);
;WITH n AS (SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId) SELECT (rn % 3000) + 1 FROM n;
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId);
GO
-- OrderLines has NO index on OrderId: the deepest join has nothing to seek.
CREATE TABLE OrderLines
(
    LineId  INT IDENTITY(1,1) CONSTRAINT PK_OrderLines PRIMARY KEY CLUSTERED,
    OrderId INT           NOT NULL,
    Amount  DECIMAL(10,2) NOT NULL
);
;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO OrderLines (OrderId, Amount) SELECT (rn % 100000) + 1, CAST((rn % 500) + 1 AS DECIMAL(10,2)) FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS OrderLines WITH FULLSCAN;
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
