IF DB_ID('Lesson_b_21_recent_date_range') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_21_recent_date_range SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_21_recent_date_range;
END
GO
CREATE DATABASE Lesson_b_21_recent_date_range;
GO
USE Lesson_b_21_recent_date_range;
GO
CREATE TABLE dbo.Logins
(
    LoginId INT IDENTITY(1,1) CONSTRAINT PK_Logins PRIMARY KEY CLUSTERED,
    UserId  INT       NOT NULL,
    LoginAt DATETIME2 NOT NULL
);
GO
-- 300,000 logins spread across a year; there's no index on LoginAt.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Logins (UserId, LoginAt)
SELECT (rn % 20000) + 1,
       DATEADD(MINUTE, -(rn % 525600), CAST('2025-12-31T23:59:00' AS DATETIME2))
FROM n;
GO
UPDATE STATISTICS dbo.Logins WITH FULLSCAN;
GO
