CREATE TABLE Customers
(
    CustomerId INT         CONSTRAINT PK_Customers PRIMARY KEY,
    Name       VARCHAR(50) NOT NULL
);
GO
INSERT INTO Customers (CustomerId, Name)
SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)), 'Customer'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
-- Design flaw the lesson turns on: the order table stores the customer key as
-- TEXT (VARCHAR) while Customers.CustomerId is an INT. The join therefore
-- compares VARCHAR to INT.
CREATE TABLE Orders
(
    OrderId      INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerCode VARCHAR(10)   NOT NULL,
    OrderDate    DATE          NOT NULL,
    Total        DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerCode, OrderDate, Total)
SELECT CAST(((rn % 3000) + 1) AS VARCHAR(10)),
       DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerCode ON Orders(CustomerCode) INCLUDE (Total);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
