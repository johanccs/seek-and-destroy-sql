IF DB_ID('Lesson_e_19_columnstore_telemetry_aggregate') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_19_columnstore_telemetry_aggregate SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_19_columnstore_telemetry_aggregate;
END
GO
CREATE DATABASE Lesson_e_19_columnstore_telemetry_aggregate;
GO
USE Lesson_e_19_columnstore_telemetry_aggregate;
GO
CREATE TABLE dbo.Measurements
(
    MeasurementId INT IDENTITY(1,1) CONSTRAINT PK_Measurements PRIMARY KEY CLUSTERED,
    SensorId      INT           NOT NULL,
    Reading       DECIMAL(10,2) NOT NULL,
    TakenAt       DATETIME2     NOT NULL
);
GO
-- 800,000 telemetry readings across 50 sensors: a classic scan-and-aggregate workload.
;WITH n AS (SELECT TOP (800000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Measurements (SensorId, Reading, TakenAt)
SELECT (rn % 50) + 1,
       CAST((rn % 1000) + 0.5 AS DECIMAL(10,2)),
       DATEADD(SECOND, -rn, CAST('2025-12-31T00:00:00' AS DATETIME2))
FROM n;
GO
UPDATE STATISTICS dbo.Measurements WITH FULLSCAN;
GO
