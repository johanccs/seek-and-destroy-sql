-- An order-line table with no constraints at all, and data that shows exactly
-- what that permits: negative quantities, a discount above 100%, four spellings
-- of one status, and a duplicated reference.
IF OBJECT_ID('OrderLineImport') IS NOT NULL DROP TABLE OrderLineImport;

CREATE TABLE OrderLineImport (
    RowId      int           NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Reference  nvarchar(20)  NOT NULL,
    Status     nvarchar(30)  NOT NULL,
    Quantity   int           NOT NULL,
    UnitPrice  decimal(10,2) NOT NULL,
    DiscountPc int           NOT NULL
);
GO

INSERT INTO OrderLineImport (Reference, Status, Quantity, UnitPrice, DiscountPc)
VALUES
    ('ORD-1001', 'pending',   2,   450.00,  0),
    ('ORD-1002', 'Pending',   1,  1299.00, 10),
    ('ORD-1003', 'PENDING',  -3,   220.00,  0),   -- negative quantity
    ('ORD-1004', 'shipped',   5,    89.50, 15),
    ('ORD-1005', 'Shipped',   1,   640.00, 150),  -- 150% discount
    ('ORD-1006', 'delivered', 4,   310.00,  5),
    ('ORD-1001', 'cancelled', 1,   450.00,  0);   -- duplicate reference
GO
