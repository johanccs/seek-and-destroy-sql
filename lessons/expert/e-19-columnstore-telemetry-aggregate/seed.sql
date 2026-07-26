CREATE TABLE Measurements
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
INSERT INTO Measurements (SensorId, Reading, TakenAt)
SELECT (rn % 50) + 1,
       CAST((rn % 1000) + 0.5 AS DECIMAL(10,2)),
       DATEADD(SECOND, -rn, CAST('2025-12-31T00:00:00' AS DATETIME2))
FROM n;
GO
UPDATE STATISTICS Measurements WITH FULLSCAN;
GO
