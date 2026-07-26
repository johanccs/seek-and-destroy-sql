-- Lesson i-16: The Unicode JOIN trap (NVARCHAR key joined to a VARCHAR indexed column)
-- Customers came from a CRM export, so the business key is stored as Unicode.
CREATE TABLE Customers
(
    CustomerId   INT           CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED,
    CustomerCode NVARCHAR(20)  NOT NULL,
    Name         VARCHAR(50)   NOT NULL
);
GO
INSERT INTO Customers (CustomerId, CustomerCode, Name)
SELECT TOP (3000)
       ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
       N'CUST' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(6)), 6),
       'Customer'
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE UNIQUE NONCLUSTERED INDEX IX_Customers_CustomerCode ON Customers(CustomerCode);
GO
-- Orders were designed by a different team that used a plain VARCHAR business key.
-- This VARCHAR/NVARCHAR mismatch across the join is the whole lesson.
CREATE TABLE Orders
(
    OrderId      INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerCode VARCHAR(20)   NOT NULL,
    OrderDate    DATE          NOT NULL,
    Total        DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerCode, OrderDate, Total)
SELECT 'CUST' + RIGHT('000000' + CAST(((rn % 3000) + 1) AS VARCHAR(6)), 6),
       DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATE)),
       CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
-- A covering index that *should* make the per-customer lookup a tiny seek...
-- but only if the join predicate stays VARCHAR-to-VARCHAR.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerCode ON Orders(CustomerCode) INCLUDE (Total);
GO
UPDATE STATISTICS Customers WITH FULLSCAN;
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
