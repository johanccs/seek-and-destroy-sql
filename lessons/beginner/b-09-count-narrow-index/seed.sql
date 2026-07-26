-- Lesson b-09: COUNT(*) uses the narrowest available index
-- Wide rows: the CHAR(200) Filler bloats the clustered index so a full scan
-- (which COUNT(*) needs) reads thousands of pages. There is NO narrow index.
CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    OrderDate  DATETIME2(0)  NOT NULL,
    Total      DECIMAL(10,2) NOT NULL,
    Status     VARCHAR(10)   NOT NULL,
    Region     TINYINT       NOT NULL,
    Filler     CHAR(200)     NOT NULL
);
GO
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Orders (CustomerId, OrderDate, Total, Status, Region, Filler)
SELECT (rn % 5000) + 1,
       DATEADD(DAY, rn % 365, CAST('2025-01-01' AS DATETIME2(0))),
       CAST((rn % 1000) * 1.5 AS DECIMAL(10,2)),
       CASE rn % 3 WHEN 0 THEN 'Open' WHEN 1 THEN 'Shipped' ELSE 'Closed' END,
       rn % 5,
       REPLICATE('x', 200)
FROM n;
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
