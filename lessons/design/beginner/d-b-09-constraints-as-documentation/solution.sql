-- Every rule that was previously an assumption is now enforced by the engine.

CREATE TABLE OrderLines (
    OrderLineId int           NOT NULL IDENTITY(1,1),
    Reference   nvarchar(50)  NOT NULL,
    Status      nvarchar(50)  NOT NULL,
    Quantity    int           NOT NULL,
    UnitPrice   decimal(10,2) NOT NULL,
    DiscountPc  int           NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderLineId),
    -- Not the identifier, but still must not repeat.
    CONSTRAINT UQ_OrderLines_Reference UNIQUE (Reference),
    -- NOT NULL above is load-bearing: a CHECK rejects FALSE, and NULL evaluates
    -- to UNKNOWN, so a nullable column would slip past every rule below.
    CONSTRAINT CK_OrderLines_Quantity   CHECK (Quantity > 0),
    CONSTRAINT CK_OrderLines_DiscountPc CHECK (DiscountPc BETWEEN 0 AND 100),
    CONSTRAINT CK_OrderLines_UnitPrice  CHECK (UnitPrice >= 0),
    CONSTRAINT CK_OrderLines_Status     CHECK (Status IN ('pending', 'shipped', 'delivered', 'cancelled'))
);

-- Only the rows that were always legal survive the move. The others have to be
-- decided on rather than silently carried over — which is the point.
INSERT INTO OrderLines (Reference, Status, Quantity, UnitPrice, DiscountPc)
SELECT Reference, LOWER(Status), Quantity, UnitPrice, DiscountPc
FROM OrderLineImport i
WHERE Quantity > 0
  AND DiscountPc BETWEEN 0 AND 100
  AND LOWER(Status) IN ('pending', 'shipped', 'delivered', 'cancelled')
  AND NOT EXISTS (SELECT 1 FROM OrderLineImport d
                  WHERE d.Reference = i.Reference AND d.RowId < i.RowId);

-- Each of these is now refused by the database rather than accepted quietly:
--   INSERT INTO OrderLines (Reference, Status, Quantity, UnitPrice, DiscountPc)
--   VALUES ('ORD-9001', 'pending', -3, 220.00, 0);        -- CK_..._Quantity
--   VALUES ('ORD-9002', 'posted',   1, 100.00, 0);        -- CK_..._Status
--   VALUES ('ORD-1001', 'pending',  1, 450.00, 0);        -- UQ_..._Reference
