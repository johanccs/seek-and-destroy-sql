-- Fix: use a #temp table (real cardinality → correctly sized memory grant) with a
-- clustered index on the sort key. The rows are stored in order, so the query needs
-- NO Sort operator at all — nothing to spill to tempdb.

CREATE TABLE #T
(
    G   INT      NOT NULL,
    Pad CHAR(60) NOT NULL,
    INDEX CX CLUSTERED (G, Pad)
);
INSERT INTO #T SELECT G, Pad FROM dbo.Src;

SELECT G, Pad FROM #T ORDER BY G, Pad;
