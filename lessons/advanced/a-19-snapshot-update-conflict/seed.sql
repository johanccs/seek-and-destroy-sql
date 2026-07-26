IF DB_ID('Lesson_a_19_snapshot_update_conflict') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_19_snapshot_update_conflict SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_19_snapshot_update_conflict;
END
GO
CREATE DATABASE Lesson_a_19_snapshot_update_conflict;
GO
-- SNAPSHOT isolation (optimistic, row-versioned) must be enabled at the DB level.
ALTER DATABASE Lesson_a_19_snapshot_update_conflict SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
USE Lesson_a_19_snapshot_update_conflict;
GO
CREATE TABLE dbo.Accounts
(
    AccountId INT CONSTRAINT PK_Accounts PRIMARY KEY,
    Owner     VARCHAR(50)   NOT NULL,
    Balance   DECIMAL(12,2) NOT NULL
);
GO
INSERT INTO dbo.Accounts (AccountId, Owner, Balance) VALUES
 (1,'Alice',1000),(2,'Bob',2000),(3,'Carol',3000);
GO
