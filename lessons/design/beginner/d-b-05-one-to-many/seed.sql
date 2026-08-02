-- Starting point for the one-to-many module: a single flat table holding order
-- rows exactly as they arrived from a spreadsheet export. Deliberately tiny --
-- this module is about structure, not volume.
IF OBJECT_ID('LegacyOrders') IS NOT NULL DROP TABLE LegacyOrders;

CREATE TABLE LegacyOrders (
    RowId          int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CustomerName   nvarchar(100) NOT NULL,
    CustomerEmail  nvarchar(200) NOT NULL,
    CustomerCity   nvarchar(100) NOT NULL,
    OrderedOn      date          NOT NULL,
    ProductName    nvarchar(100) NOT NULL,
    AmountZar      decimal(10,2) NOT NULL
);
GO

INSERT INTO LegacyOrders (CustomerName, CustomerEmail, CustomerCity, OrderedOn, ProductName, AmountZar)
VALUES
    ('Thandi Mokoena', 'thandi@example.co.za',  'Johannesburg', '2026-02-03', 'Standing desk',    4250.00),
    ('Thandi Mokoena', 'thandi@example.co.za',  'Johannesburg', '2026-02-19', 'Monitor arm',       899.00),
    ('Thandi Mokoena', 'thandi@example.co.za',  'Johannesburg', '2026-03-01', 'Mechanical keyboard', 1450.00),
    ('Pieter van Wyk', 'pieter@example.co.za',  'Cape Town',    '2026-02-11', 'Laptop stand',      640.00),
    ('Pieter van Wyk', 'pieter@example.co.za',  'Cape Town',    '2026-03-04', 'USB-C dock',       2199.00),
    ('Ayanda Dlamini', 'ayanda@example.co.za',  'Durban',       '2026-02-27', 'Office chair',     5600.00),
    ('Ayanda Dlamini', 'ayanda@example.co.za',  'Durban',       '2026-03-08', 'Footrest',          420.00),
    ('Ayanda Dlamini', 'ayanda@example.co.za',  'Durban',       '2026-03-15', 'Desk lamp',         780.00),
    ('Nadia Petersen', 'nadia@example.co.za',   'Gqeberha',     '2026-03-11', 'Webcam',           1180.00),
    ('Nadia Petersen', 'nadia@example.co.za',   'Gqeberha',     '2026-03-22', 'Headset',          1990.00);
GO
