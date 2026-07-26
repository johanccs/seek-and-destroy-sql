IF DB_ID('Lesson_e_09_hash_aggregate_spill') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_09_hash_aggregate_spill SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_09_hash_aggregate_spill;
END
GO
CREATE DATABASE Lesson_e_09_hash_aggregate_spill;
GO
-- Compat 140 keeps a table variable estimated at 1 row (the trap this teaches).
ALTER DATABASE Lesson_e_09_hash_aggregate_spill SET COMPATIBILITY_LEVEL = 140;
GO
USE Lesson_e_09_hash_aggregate_spill;
GO
CREATE TABLE dbo.Src (G INT NOT NULL, Pad CHAR(40) NOT NULL);
GO
-- 200,000 rows across ~50,000 groups: a hash aggregate over this needs real memory.
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Src (G, Pad)
SELECT (rn % 50000) + 1, 'x'
FROM n;
GO
UPDATE STATISTICS dbo.Src WITH FULLSCAN;
GO
