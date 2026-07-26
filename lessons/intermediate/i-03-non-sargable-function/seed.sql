IF DB_ID('Lesson_i_03_non_sargable_function') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_03_non_sargable_function SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_03_non_sargable_function;
END
GO
CREATE DATABASE Lesson_i_03_non_sargable_function;
GO
USE Lesson_i_03_non_sargable_function;
GO
CREATE TABLE dbo.Users
(
    UserId INT IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    Email  VARCHAR(100) NOT NULL
);
GO
-- 300k users. Most emails are user{n}@mail.com; a small, deterministic set start
-- with 'admin' so the target query returns a stable, small result.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Users (Email)
SELECT CASE WHEN rn <= 200 THEN 'admin' + RIGHT('0000' + CAST(rn AS VARCHAR(4)), 4) + '@corp.com'
            ELSE 'user' + CAST(rn AS VARCHAR(10)) + '@mail.com' END
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Users_Email ON dbo.Users(Email);
GO
UPDATE STATISTICS dbo.Users WITH FULLSCAN;
GO
