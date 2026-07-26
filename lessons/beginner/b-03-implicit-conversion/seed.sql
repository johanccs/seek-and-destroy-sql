IF DB_ID('Lesson_b_03_implicit_conversion') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_03_implicit_conversion SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_03_implicit_conversion;
END
GO
CREATE DATABASE Lesson_b_03_implicit_conversion;
GO
USE Lesson_b_03_implicit_conversion;
GO
-- AccountCode is stored as VARCHAR (common for legacy "numeric-looking" codes).
CREATE TABLE dbo.Customers
(
    CustomerId  INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY,
    AccountCode VARCHAR(20)  NOT NULL,
    Name        VARCHAR(100) NOT NULL
);
GO
;WITH n AS (SELECT TOP (250000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Customers (AccountCode, Name)
SELECT CAST(1000000 + rn AS VARCHAR(20)), CONCAT('Customer ', rn)
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Customers_AccountCode ON dbo.Customers(AccountCode);
GO
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO
