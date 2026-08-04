-- One flat table holding two different kinds of thing. The customer's details
-- repeat on every order, which is what makes the second entity visible without
-- anyone having to name it first.
IF OBJECT_ID('CustomerOrdersFlat') IS NOT NULL DROP TABLE CustomerOrdersFlat;

CREATE TABLE CustomerOrdersFlat (
    RowId         int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    CustomerName  nvarchar(120) NOT NULL,
    CustomerEmail nvarchar(256) NOT NULL,
    CustomerPhone nvarchar(30)  NOT NULL,
    OrderRef      nvarchar(20)  NOT NULL,
    PlacedOn      date          NOT NULL,
    TotalZar      decimal(10,2) NOT NULL
);
GO

INSERT INTO CustomerOrdersFlat (CustomerName, CustomerEmail, CustomerPhone, OrderRef, PlacedOn, TotalZar)
VALUES
    ('Thandi Mokoena', 'thandi@example.co.za', '082 555 0114', 'ORD-2001', '2026-03-02', 1240.00),
    ('Thandi Mokoena', 'thandi@example.co.za', '082 555 0114', 'ORD-2002', '2026-03-19',  485.50),
    ('Thandi Mokoena', 'thandi@example.co.za', '082 555 0114', 'ORD-2007', '2026-04-11', 2310.00),
    ('Pieter van Wyk', 'pieter@example.co.za', '083 555 0192', 'ORD-2003', '2026-03-05',  799.99),
    ('Pieter van Wyk', 'pieter@example.co.za', '083 555 0192', 'ORD-2009', '2026-04-22',  150.00);
GO
