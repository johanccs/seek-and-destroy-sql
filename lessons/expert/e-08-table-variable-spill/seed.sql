CREATE TABLE Src (G INT NOT NULL, Pad CHAR(60) NOT NULL);
GO
-- 100,000 rows: small enough to sort in memory when the grant is right-sized,
-- but far more than the 1-row estimate a table variable reports.
;WITH n AS (SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Src (G, Pad)
SELECT ABS(CHECKSUM(NEWID())) % 100000, 'x'
FROM n;
GO
UPDATE STATISTICS Src WITH FULLSCAN;
GO
