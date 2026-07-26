CREATE TABLE Accounts
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
INSERT INTO Accounts (AccountNumber, Owner, Balance)
SELECT CAST(4000000 + rn AS VARCHAR(20)),
       'Owner ' + CAST(rn AS VARCHAR(10)),
       CAST((rn % 10000) + 0.5 AS DECIMAL(12,2))
FROM n;
GO
CREATE UNIQUE NONCLUSTERED INDEX IX_Accounts_AccountNumber ON Accounts(AccountNumber);
GO
UPDATE STATISTICS Accounts WITH FULLSCAN;
GO
