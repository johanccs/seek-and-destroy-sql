IF DB_ID('Lesson_b_02_sargable_predicates') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_02_sargable_predicates SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_02_sargable_predicates;
END
GO
CREATE DATABASE Lesson_b_02_sargable_predicates;
GO
USE Lesson_b_02_sargable_predicates;
GO
CREATE TABLE dbo.Accounts
(
    AccountId INT IDENTITY(1,1) CONSTRAINT PK_Accounts PRIMARY KEY,
    OwnerName VARCHAR(100)  NOT NULL,
    Balance   DECIMAL(12,2) NOT NULL
);
GO
-- 200k accounts. Almost all balances are small; a rare few (~50) are very large,
-- so a predicate on high balance is highly selective (great for a seek).
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Accounts (OwnerName, Balance)
SELECT CONCAT('Owner ', rn),
       CASE WHEN rn % 4000 = 0
            THEN CAST(500000 AS DECIMAL(12,2))                    -- ~50 large accounts, tight value
            ELSE CAST((rn % 40000) AS DECIMAL(12,2)) END          -- the rest are small
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Accounts_Balance ON dbo.Accounts(Balance);
GO
UPDATE STATISTICS dbo.Accounts WITH FULLSCAN;
GO
