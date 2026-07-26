CREATE TABLE Ledger
(
    Id     INT IDENTITY(1,1) CONSTRAINT PK_Ledger PRIMARY KEY CLUSTERED,
    Amount DECIMAL(12,2) NOT NULL
);
GO
-- 100,000 rows. The clustered PK already orders by Id, so the running total needs
-- no Sort -- the only difference between the two versions is the window FRAME.
;WITH n AS (SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Ledger (Amount)
SELECT (rn % 500) + 1
FROM n;
GO
UPDATE STATISTICS Ledger WITH FULLSCAN;
GO
