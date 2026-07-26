-- AccountCode is stored as VARCHAR (common for legacy "numeric-looking" codes).
CREATE TABLE Customers
(
    CustomerId  INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY,
    AccountCode VARCHAR(20)  NOT NULL,
    Name        VARCHAR(100) NOT NULL
);
GO
;WITH n AS (SELECT TOP (250000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Customers (AccountCode, Name)
SELECT CAST(1000000 + rn AS VARCHAR(20)), CONCAT('Customer ', rn)
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Customers_AccountCode ON Customers(AccountCode);
GO
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
