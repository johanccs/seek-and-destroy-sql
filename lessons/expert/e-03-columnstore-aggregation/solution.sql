-- Add a nonclustered columnstore index over the columns the aggregation touches.
-- Column-oriented storage compresses each column into segments and lets SQL Server
-- run the SUM/COUNT in BATCH mode over compressed data, reading a fraction of the
-- pages a rowstore scan would. The Clustered Index Scan is replaced by a
-- columnstore scan of NCCI_FactSales.
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FactSales
    ON dbo.FactSales (ProductId, Amount);
SELECT ProductId, SUM(Amount) AS Revenue, COUNT(*) AS Cnt
FROM FactSales
GROUP BY ProductId;
