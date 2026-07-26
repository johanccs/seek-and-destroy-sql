CREATE TABLE Src (G INT NOT NULL, Pad CHAR(40) NOT NULL);
GO
-- 200,000 rows across ~50,000 groups: a hash aggregate over this needs real memory.
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Src (G, Pad)
SELECT (rn % 50000) + 1, 'x'
FROM n;
GO
UPDATE STATISTICS Src WITH FULLSCAN;
GO
