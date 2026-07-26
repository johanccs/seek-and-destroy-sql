CREATE TABLE Customers
(
    CustomerId INT CONSTRAINT PK_Customers PRIMARY KEY,
    Ref        VARCHAR(20) NOT NULL
);
GO
INSERT INTO Customers (CustomerId, Ref)
SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
       'CUST' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(6)), 6)
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE TABLE Orders
(
    OrderId     INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerRef VARCHAR(20)   NOT NULL,
    Total       DECIMAL(10,2) NOT NULL
);
GO
-- CustomerRef is already uppercase and matches Customers.Ref exactly.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerRef, Total)
SELECT 'CUST' + RIGHT('000000' + CAST(((rn % 3000) + 1) AS VARCHAR(6)), 6),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerRef ON Orders(CustomerRef) INCLUDE (Total);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
