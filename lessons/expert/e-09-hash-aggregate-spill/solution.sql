-- Fix: a #temp table (real cardinality → right-sized grant) with a clustered index
-- on the grouping key. The rows arrive ordered by G, so the optimizer uses a Stream
-- Aggregate instead of a Hash Match — no hash table, nothing to spill to tempdb.
CREATE TABLE #T
(
    G   INT      NOT NULL,
    Pad CHAR(40) NOT NULL,
    INDEX CX CLUSTERED (G)
);
INSERT INTO #T SELECT G, Pad FROM dbo.Src;

SELECT G, COUNT(*) AS Cnt FROM #T GROUP BY G;
