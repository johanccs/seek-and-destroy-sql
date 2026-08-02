-- A product catalogue where every column is a string, which is what you get when
-- data arrives from a spreadsheet and nobody stops to declare types.
IF OBJECT_ID('ProductImport') IS NOT NULL DROP TABLE ProductImport;

CREATE TABLE ProductImport (
    RowId       int            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Sku         nvarchar(max)  NOT NULL,
    Name        nvarchar(max)  NOT NULL,
    PriceZar    nvarchar(max)  NOT NULL,   -- money as text
    LaunchedOn  nvarchar(max)  NOT NULL,   -- a date as text
    IsActive    nvarchar(max)  NOT NULL,   -- a boolean as text, in three spellings
    StockCount  nvarchar(max)  NOT NULL    -- an integer as text
);
GO

INSERT INTO ProductImport (Sku, Name, PriceZar, LaunchedOn, IsActive, StockCount)
VALUES
    ('SKU-1001', 'Standing desk',       '4250.00',  '2026-02-03', 'true',  '12'),
    ('SKU-1002', 'Monitor arm',         '899.00',   '2026-02-19', 'TRUE',  '40'),
    ('SKU-1003', 'Mechanical keyboard', '1450.00',  '2026-03-01', 'Y',     '7'),
    ('SKU-1004', 'Laptop stand',        '640.00',   '2026-03-04', 'false', '0'),
    ('SKU-1005', 'USB-C dock',          '2199.90',  '2026-03-11', 'N',     '23'),
    ('SKU-1006', 'Office chair',        '5600.00',  '2026-03-22', 'true',  '3');
GO
