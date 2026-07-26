IF DB_ID('Lesson_i_21_covering_range_aggregate') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_21_covering_range_aggregate SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_21_covering_range_aggregate;
END
GO
CREATE DATABASE Lesson_i_21_covering_range_aggregate;
GO
USE Lesson_i_21_covering_range_aggregate;
GO
CREATE TABLE dbo.Payments
(
    PaymentId INT IDENTITY(1,1) CONSTRAINT PK_Payments PRIMARY KEY CLUSTERED,
    Method    VARCHAR(12)   NOT NULL,
    PaidAt    DATE          NOT NULL,
    Amount    DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Payments (Method, PaidAt, Amount)
SELECT CASE rn % 4 WHEN 0 THEN 'Card' WHEN 1 THEN 'Cash' WHEN 2 THEN 'Transfer' ELSE 'Cheque' END,
       DATEADD(DAY, -(rn % 365), CAST('2025-12-31' AS DATE)),
       CAST((rn % 500) + 1 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS dbo.Payments WITH FULLSCAN;
GO
