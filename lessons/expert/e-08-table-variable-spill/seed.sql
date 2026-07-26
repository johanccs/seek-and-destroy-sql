IF DB_ID('Lesson_e_08_table_variable_spill') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_08_table_variable_spill SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_08_table_variable_spill;
END
GO
CREATE DATABASE Lesson_e_08_table_variable_spill;
GO
-- Compat 140 keeps the classic behavior: a table variable is estimated at 1 row
-- (no table-variable deferred compilation), which is exactly the trap this teaches.
ALTER DATABASE Lesson_e_08_table_variable_spill SET COMPATIBILITY_LEVEL = 140;
GO
USE Lesson_e_08_table_variable_spill;
GO
CREATE TABLE dbo.Src (G INT NOT NULL, Pad CHAR(60) NOT NULL);
GO
-- 100,000 rows: small enough to sort in memory when the grant is right-sized,
-- but far more than the 1-row estimate a table variable reports.
;WITH n AS (SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Src (G, Pad)
SELECT ABS(CHECKSUM(NEWID())) % 100000, 'x'
FROM n;
GO
UPDATE STATISTICS dbo.Src WITH FULLSCAN;
GO
