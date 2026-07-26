CREATE TABLE Shipments
(
    ShipmentId INT IDENTITY(1,1) CONSTRAINT PK_Shipments PRIMARY KEY CLUSTERED,
    Status     VARCHAR(12)   NOT NULL,
    Carrier    VARCHAR(40)   NOT NULL,
    ShippedAt  DATETIME2     NOT NULL
);
GO
-- 500,000 shipments; ~99.9% are 'Delivered'. Only ~400 are 'Exception' -- the rows
-- an operations screen actually queries all day.
;WITH n AS (SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Shipments (Status, Carrier, ShippedAt)
SELECT CASE WHEN rn % 1250 = 0 THEN 'Exception' ELSE 'Delivered' END,
       'Carrier ' + CAST((rn % 8) + 1 AS VARCHAR(3)),
       DATEADD(MINUTE, -(rn % 500000), SYSDATETIME())
FROM n;
GO
UPDATE STATISTICS Shipments WITH FULLSCAN;
GO
