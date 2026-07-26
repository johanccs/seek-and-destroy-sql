-- Fix: a nonclustered columnstore index on the aggregated columns. The roll-up now
-- scans compressed column segments in batch mode instead of the whole rowstore table.
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Measurements ON dbo.Measurements(SensorId, Reading);

SELECT SensorId, AVG(Reading) AS AvgReading, COUNT(*) AS Cnt
FROM dbo.Measurements
GROUP BY SensorId;
