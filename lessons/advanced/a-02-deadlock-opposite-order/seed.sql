IF DB_ID('Lesson_a_02_deadlock_opposite_order') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_02_deadlock_opposite_order SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_02_deadlock_opposite_order;
END
GO
CREATE DATABASE Lesson_a_02_deadlock_opposite_order;
GO
USE Lesson_a_02_deadlock_opposite_order;
GO
CREATE TABLE dbo.Accounts
(
    AccountId INT CONSTRAINT PK_Accounts PRIMARY KEY,
    Owner     VARCHAR(50)   NOT NULL,
    Balance   DECIMAL(12,2) NOT NULL
);
GO
INSERT INTO dbo.Accounts (AccountId, Owner, Balance) VALUES (1,'Alice',1000),(2,'Bob',2000);
GO
