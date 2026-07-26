IF DB_ID('Lesson_e_16_conversion_cardinality_warning') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_e_16_conversion_cardinality_warning SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_e_16_conversion_cardinality_warning;
END
GO
CREATE DATABASE Lesson_e_16_conversion_cardinality_warning;
GO
USE Lesson_e_16_conversion_cardinality_warning;
GO
CREATE TABLE dbo.Devices
(
    DeviceId INT IDENTITY(1,1) CONSTRAINT PK_Devices PRIMARY KEY CLUSTERED,
    Serial   VARCHAR(20)   NOT NULL,
    Model    VARCHAR(40)   NOT NULL
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Devices (Serial, Model)
SELECT CAST(500000 + rn AS VARCHAR(20)), 'Model ' + CAST((rn % 40) + 1 AS VARCHAR(3))
FROM n;
GO
CREATE UNIQUE NONCLUSTERED INDEX IX_Devices_Serial ON dbo.Devices(Serial);
GO
UPDATE STATISTICS dbo.Devices WITH FULLSCAN;
GO
