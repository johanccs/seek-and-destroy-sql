IF DB_ID('Lesson_e_18_filter_and_sort_one_index') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_18_filter_and_sort_one_index SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_18_filter_and_sort_one_index;
END
GO
CREATE DATABASE Lesson_e_18_filter_and_sort_one_index;
GO
USE Lesson_e_18_filter_and_sort_one_index;
GO
CREATE TABLE dbo.Tasks
(
    TaskId    INT IDENTITY(1,1) CONSTRAINT PK_Tasks PRIMARY KEY CLUSTERED,
    Status    VARCHAR(12)   NOT NULL,
    CreatedAt DATETIME2     NOT NULL,
    Title     VARCHAR(120)  NOT NULL
);
GO
-- ~5% of tasks are 'Open'; the screen shows the newest Open ones.
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Tasks (Status, CreatedAt, Title)
SELECT CASE WHEN rn % 20 = 0 THEN 'Open' ELSE 'Done' END,
       DATEADD(MINUTE, -rn, CAST('2025-12-31T00:00:00' AS DATETIME2)),
       'Task ' + CAST(rn AS VARCHAR(10))
FROM n;
GO
UPDATE STATISTICS dbo.Tasks WITH FULLSCAN;
GO
