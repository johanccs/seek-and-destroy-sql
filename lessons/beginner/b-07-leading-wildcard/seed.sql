IF DB_ID('Lesson_b_07_leading_wildcard') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_07_leading_wildcard SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_07_leading_wildcard;
END
GO
CREATE DATABASE Lesson_b_07_leading_wildcard;
GO
USE Lesson_b_07_leading_wildcard;
GO
CREATE TABLE dbo.Users
(
    UserId   INT IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    Username VARCHAR(50)  NOT NULL,
    Email    VARCHAR(100) NOT NULL
);
GO
-- 200 usernames begin with 'admin', the other ~200k begin with 'user'. The string
-- 'admin' only ever appears at the START of a username, never in the middle.
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Users (Username, Email)
SELECT CASE WHEN rn <= 200 THEN 'admin' + RIGHT('000000' + CAST(rn AS VARCHAR(6)), 6)
            ELSE 'user' + RIGHT('000000' + CAST(rn AS VARCHAR(6)), 6) END,
       'u' + CAST(rn AS VARCHAR(10)) + '@example.com'
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Users_Username ON dbo.Users(Username);
GO
UPDATE STATISTICS dbo.Users WITH FULLSCAN;
GO
