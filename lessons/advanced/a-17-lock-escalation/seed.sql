IF DB_ID('Lesson_a_17_lock_escalation') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_17_lock_escalation SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_17_lock_escalation;
END
GO
CREATE DATABASE Lesson_a_17_lock_escalation;
GO
USE Lesson_a_17_lock_escalation;
GO
CREATE TABLE dbo.Ledger
(
    LedgerId  INT IDENTITY(1,1) CONSTRAINT PK_Ledger PRIMARY KEY CLUSTERED,
    AccountId INT           NOT NULL,
    Amount    DECIMAL(12,2) NOT NULL,
    Status    VARCHAR(20)   NOT NULL
);
GO
-- 50,000 ledger rows. A statement that locks the first 40,000 will blow past the
-- ~5,000-lock escalation threshold and take a single table lock.
;WITH n AS (SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Ledger (AccountId, Amount, Status)
SELECT (rn % 500) + 1, CAST(rn AS DECIMAL(12,2)), 'Posted'
FROM n;
GO
UPDATE STATISTICS dbo.Ledger WITH FULLSCAN;
GO
