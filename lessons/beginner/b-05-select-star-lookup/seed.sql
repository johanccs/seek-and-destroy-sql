CREATE TABLE Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId INT          NOT NULL,
    OrderDate  DATE         NOT NULL,
    Status     VARCHAR(12)  NOT NULL,
    Notes      VARCHAR(200) NOT NULL   -- wide column NOT in the index
);
GO
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Orders (CustomerId, OrderDate, Status, Notes)
SELECT (rn % 10000) + 1,
       DATEADD(DAY, -(rn % 365), '2024-12-31'),
       CASE WHEN rn % 3 = 0 THEN 'Shipped' ELSE 'Completed' END,
       REPLICATE('n', 200)
FROM n;
GO
-- Index covers CustomerId + the common display columns, but NOT Notes.
CREATE NONCLUSTERED INDEX IX_Orders_Customer
    ON Orders(CustomerId) INCLUDE (OrderDate, Status);
GO
UPDATE STATISTICS Orders WITH FULLSCAN;
GO
