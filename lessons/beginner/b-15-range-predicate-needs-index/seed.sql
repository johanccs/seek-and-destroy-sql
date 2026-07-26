IF DB_ID('Lesson_b_15_range_predicate_needs_index') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_b_15_range_predicate_needs_index SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_b_15_range_predicate_needs_index;
END
GO
CREATE DATABASE Lesson_b_15_range_predicate_needs_index;
GO
USE Lesson_b_15_range_predicate_needs_index;
GO
CREATE TABLE dbo.Employees
(
    EmployeeId INT IDENTITY(1,1) CONSTRAINT PK_Employees PRIMARY KEY CLUSTERED,
    Name       VARCHAR(80)  NOT NULL,
    Department VARCHAR(40)  NOT NULL,
    Salary     INT          NOT NULL
);
GO
-- 200,000 employees; Salary spread 30000..150000 so a narrow range returns a small set.
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Employees (Name, Department, Salary)
SELECT 'Employee ' + CAST(rn AS VARCHAR(10)),
       'Dept ' + CAST((rn % 20) + 1 AS VARCHAR(3)),
       30000 + (rn % 120000)
FROM n;
GO
UPDATE STATISTICS dbo.Employees WITH FULLSCAN;
GO
