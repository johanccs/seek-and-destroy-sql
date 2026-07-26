-- Lesson e-06: Data compression cuts I/O
-- A wide, HIGHLY compressible table: Region is a padded CHAR(20) with only 4
-- distinct values, Status has 3 -- ideal for PAGE dictionary/prefix compression.
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL,
    Region     CHAR(20)      NOT NULL
);
GO
-- 500,000 rows so page counts (and the compression win) are meaningful.
;WITH n AS
(
    SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
)
INSERT INTO Orders (CustomerId, OrderDate, Total, Status, Region)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, rn % 730, CAST('2024-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END,
       CASE rn % 4 WHEN 0 THEN 'NORTH' WHEN 1 THEN 'SOUTH' WHEN 2 THEN 'EAST' ELSE 'WEST' END
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
