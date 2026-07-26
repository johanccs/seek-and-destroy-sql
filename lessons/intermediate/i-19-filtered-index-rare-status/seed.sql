IF DB_ID('Lesson_i_19_filtered_index_rare_status') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_19_filtered_index_rare_status SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_19_filtered_index_rare_status;
END
GO
CREATE DATABASE Lesson_i_19_filtered_index_rare_status;
GO
USE Lesson_i_19_filtered_index_rare_status;
GO
CREATE TABLE dbo.Shipments
(
    ShipmentId INT IDENTITY(1,1) CONSTRAINT PK_Shipments PRIMARY KEY CLUSTERED,
    Status     VARCHAR(12)   NOT NULL,
    Carrier    VARCHAR(40)   NOT NULL,
    ShippedAt  DATETIME2     NOT NULL
);
GO
-- 500,000 shipments; ~99.9% are 'Delivered'. Only ~400 are 'Exception' -- the rows
-- an operations screen actually queries all day.
;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Shipments (Status, Carrier, ShippedAt)
SELECT CASE WHEN rn % 1250 = 0 THEN 'Exception' ELSE 'Delivered' END,
       'Carrier ' + CAST((rn % 8) + 1 AS VARCHAR(3)),
       DATEADD(MINUTE, -(rn % 500000), SYSDATETIME())
FROM n;
GO
UPDATE STATISTICS dbo.Shipments WITH FULLSCAN;
GO
