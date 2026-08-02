-- Every column gets the type that matches what it actually holds.

CREATE TABLE Products (
    ProductId   int            NOT NULL IDENTITY(1,1),
    Sku         nvarchar(20)   NOT NULL,
    Name        nvarchar(100)  NOT NULL,
    PriceZar    decimal(10,2)  NOT NULL,
    LaunchedOn  date           NOT NULL,
    IsActive    bit            NOT NULL,
    StockCount  int            NOT NULL,
    CONSTRAINT PK_Products PRIMARY KEY (ProductId),
    -- Sku is the natural key. Now that it is nvarchar(20) rather than
    -- nvarchar(max) it can be a unique key at all — a LOB column cannot.
    CONSTRAINT UQ_Products_Sku UNIQUE (Sku)
);

-- Converting on the way in is where the bad data finally announces itself.
INSERT INTO Products (Sku, Name, PriceZar, LaunchedOn, IsActive, StockCount)
SELECT
    CAST(Sku AS nvarchar(20)),
    CAST(Name AS nvarchar(100)),
    CAST(PriceZar AS decimal(10,2)),
    CAST(LaunchedOn AS date),
    CASE WHEN IsActive IN ('true', 'TRUE', 'Y', '1') THEN 1 ELSE 0 END,
    CAST(StockCount AS int)
FROM ProductImport;

-- These questions were all unanswerable — or quietly wrong — before:
--   SELECT SUM(PriceZar * StockCount) FROM Products;          -- inventory value
--   SELECT * FROM Products WHERE LaunchedOn >= '2026-03-01';  -- a real date range
--   SELECT * FROM Products WHERE IsActive = 1;                -- one spelling, not five
