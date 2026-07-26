IF DB_ID('Lesson_a_03_tempdb_sort_spill') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_03_tempdb_sort_spill SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_03_tempdb_sort_spill;
END
GO
CREATE DATABASE Lesson_a_03_tempdb_sort_spill;
GO
USE Lesson_a_03_tempdb_sort_spill;
GO
CREATE TABLE dbo.Events
(
    EventId  INT IDENTITY(1,1) CONSTRAINT PK_Events PRIMARY KEY,
    UserId   INT          NOT NULL,
    Amount   DECIMAL(12,2) NOT NULL,
    Payload  CHAR(200)    NOT NULL   -- makes each row wide so a big sort needs lots of memory
);
GO
;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Events (UserId, Amount, Payload)
SELECT (rn % 20000) + 1, CAST((rn % 100000) AS DECIMAL(12,2)), REPLICATE('x', 200)
FROM n;
GO
UPDATE STATISTICS dbo.Events WITH FULLSCAN;
GO
