IF DB_ID('Lesson_a_16_conversion_deadlock') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_16_conversion_deadlock SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_16_conversion_deadlock;
END
GO
CREATE DATABASE Lesson_a_16_conversion_deadlock;
GO
USE Lesson_a_16_conversion_deadlock;
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
