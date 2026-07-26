IF DB_ID('Lesson_b_17_number_stored_as_string') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_17_number_stored_as_string SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_17_number_stored_as_string;
END
GO
CREATE DATABASE Lesson_b_17_number_stored_as_string;
GO
USE Lesson_b_17_number_stored_as_string;
GO
CREATE TABLE dbo.Accounts
(
    AccountId     INT IDENTITY(1,1) CONSTRAINT PK_Accounts PRIMARY KEY CLUSTERED,
    AccountNumber VARCHAR(20)   NOT NULL,
    Owner         VARCHAR(60)   NOT NULL,
    Balance       DECIMAL(12,2) NOT NULL
);
GO
-- AccountNumber is a VARCHAR of digits (as account numbers usually are).
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Accounts (AccountNumber, Owner, Balance)
SELECT CAST(4000000 + rn AS VARCHAR(20)),
       'Owner ' + CAST(rn AS VARCHAR(10)),
       CAST((rn % 10000) + 0.5 AS DECIMAL(12,2))
FROM n;
GO
CREATE UNIQUE NONCLUSTERED INDEX IX_Accounts_AccountNumber ON dbo.Accounts(AccountNumber);
GO
UPDATE STATISTICS dbo.Accounts WITH FULLSCAN;
GO
