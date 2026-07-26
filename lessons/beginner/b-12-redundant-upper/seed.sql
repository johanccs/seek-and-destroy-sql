-- Lesson b-12: Redundant UPPER() blocks the index seek
CREATE TABLE Customers
(
    CustomerId INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED,
    Email VARCHAR(100) NOT NULL,
    Name  VARCHAR(100) NOT NULL,
    City  VARCHAR(50)  NOT NULL
);
GO
-- 200,000 customers. Email is stored in MIXED case; the default database
-- collation (SQL_Latin1_General_CP1_CI_AS) is case-INSENSITIVE.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Customers (Email, Name, City)
SELECT 'User' + CAST(rn AS VARCHAR(7)) + '@Example.com',
       'Customer ' + CAST(rn AS VARCHAR(7)),
       CASE rn % 4 WHEN 0 THEN 'London' WHEN 1 THEN 'Paris' WHEN 2 THEN 'Berlin' ELSE 'Madrid' END
FROM n;
GO
CREATE UNIQUE NONCLUSTERED INDEX IX_Customers_Email ON Customers(Email);
GO
UPDATE STATISTICS Customers WITH FULLSCAN;
GO
