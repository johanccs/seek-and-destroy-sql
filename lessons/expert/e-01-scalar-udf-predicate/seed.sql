CREATE TABLE Orders
(
    OrderId INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    Total   DECIMAL(10,2) NOT NULL
);
GO
-- 400k rows. Most totals are small; a small deterministic set (~300) exceeds 1000,
-- so both the slow and the fast form return the SAME ~300 rows.
;WITH n AS (SELECT TOP (400000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (Total)
SELECT CASE WHEN rn <= 300 THEN 1500.00 ELSE CAST((rn % 900) AS DECIMAL(10,2)) END
FROM n;
GO
CREATE NONCLUSTERED INDEX IX_Orders_Total ON Orders(Total);
GO
-- A trivial scalar function: net = gross * 0.9. Harmless-looking, ruinous in a WHERE.
-- WITH INLINE = OFF forces the classic (pre-2019) row-by-row, non-inlined behavior
-- regardless of database compatibility level -- this is the world most scalar-UDF
-- predicates live in: a hidden, row-by-row function call that blocks the seek and
-- parallelism, the same trap SQL Server's own automatic inlining (150+) fixes.
CREATE FUNCTION fn_NetAmount(@gross DECIMAL(10,2))
RETURNS DECIMAL(10,2)
WITH INLINE = OFF
AS
BEGIN
    RETURN @gross * 0.90;
END
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
