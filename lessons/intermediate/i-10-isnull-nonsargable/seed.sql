-- Lesson i-10: Finding NULLs — ISNULL blocks the seek
IF DB_ID('Lesson_i_10_isnull_nonsargable') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_10_isnull_nonsargable SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_10_isnull_nonsargable;
END
GO
CREATE DATABASE Lesson_i_10_isnull_nonsargable;
GO
USE Lesson_i_10_isnull_nonsargable;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    AssignedTo INT           NULL
);
GO
-- 200,000 rows. Exactly 200 rows are "unassigned" (AssignedTo IS NULL).
-- No row has AssignedTo = 0, so ISNULL(AssignedTo, 0) = 0 matches exactly the NULLs.
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Orders (CustomerId, OrderDate, Total, AssignedTo)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, -(rn % 365), CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE WHEN rn <= 200 THEN NULL ELSE (rn % 500) + 1 END
FROM n;
GO
-- A covering index on AssignedTo. NULLs sort at the start of the index, so IS NULL
-- can seek straight to them -- but wrapping the column in ISNULL() defeats the seek.
CREATE NONCLUSTERED INDEX IX_Orders_AssignedTo
    ON dbo.Orders(AssignedTo) INCLUDE (CustomerId, OrderDate, Total);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
