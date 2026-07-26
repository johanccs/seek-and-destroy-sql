-- ALLOW_SNAPSHOT_ISOLATION is enabled once, globally, for the shared app database
-- (see ProgressStore.EnsureReadyAsync), not per-lesson.
CREATE TABLE Accounts
(
    AccountId INT CONSTRAINT PK_Accounts PRIMARY KEY,
    Owner     VARCHAR(50)   NOT NULL,
    Balance   DECIMAL(12,2) NOT NULL
);
GO
INSERT INTO Accounts (AccountId, Owner, Balance) VALUES
 (1,'Alice',1000),(2,'Bob',2000),(3,'Carol',3000);
GO
