-- Four tables: three things, and one relationship that carries its own facts.

CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    FullName   nvarchar(120) NOT NULL,
    Email      nvarchar(256) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId),
    CONSTRAINT UQ_Customers_Email UNIQUE (Email)
);

CREATE TABLE Products (
    ProductId    int           NOT NULL IDENTITY(1,1),
    Sku          nvarchar(20)  NOT NULL,
    Name         nvarchar(120) NOT NULL,
    ListPriceZar decimal(10,2) NOT NULL,
    Discontinued bit           NOT NULL CONSTRAINT DF_Products_Discontinued DEFAULT (0),
    CONSTRAINT PK_Products PRIMARY KEY (ProductId),
    -- The code printed on labels. Not the identifier, but it must not repeat.
    CONSTRAINT UQ_Products_Sku UNIQUE (Sku),
    CONSTRAINT CK_Products_ListPriceZar CHECK (ListPriceZar >= 0)
);

CREATE TABLE Orders (
    OrderId    int  NOT NULL IDENTITY(1,1),
    CustomerId int  NOT NULL,
    PlacedOn   date NOT NULL,
    -- NULL means "not shipped yet" -- genuinely unknown, not zero, and not a
    -- date in 1900. See module 8.
    ShippedOn  date NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId),
    -- Holds whether or not ShippedOn is known: a CHECK rejects only FALSE, and
    -- NULL evaluates to UNKNOWN, so the IS NULL branch is belt and braces.
    CONSTRAINT CK_Orders_ShippedOn CHECK (ShippedOn IS NULL OR ShippedOn >= PlacedOn)
);

-- The junction. It exists because an order has many products and a product is
-- on many orders -- but it also carries facts of its own, which is what makes
-- it a table rather than just a pair of keys.
CREATE TABLE OrderLines (
    OrderLineId  int           NOT NULL IDENTITY(1,1),
    OrderId      int           NOT NULL,
    ProductId    int           NOT NULL,
    Quantity     int           NOT NULL,
    -- The price CHARGED, captured at the time. Products.ListPriceZar is the
    -- price NOW. They usually match, and they are not the same fact.
    UnitPriceZar decimal(10,2) NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderLineId),
    CONSTRAINT FK_OrderLines_Orders   FOREIGN KEY (OrderId)   REFERENCES Orders (OrderId),
    CONSTRAINT FK_OrderLines_Products FOREIGN KEY (ProductId) REFERENCES Products (ProductId),
    CONSTRAINT CK_OrderLines_Quantity     CHECK (Quantity > 0),
    CONSTRAINT CK_OrderLines_UnitPriceZar CHECK (UnitPriceZar >= 0),
    -- The same product twice on one order should be one line with quantity 2.
    CONSTRAINT UQ_OrderLines_Order_Product UNIQUE (OrderId, ProductId)
);

-- Products come from the published list.
INSERT INTO Products (Sku, Name, ListPriceZar, Discontinued)
SELECT Sku, ProductName, ListPrice, Discontinued FROM PriceListExtract;

INSERT INTO Customers (FullName, Email) VALUES ('Thandi Mokoena', 'thandi@example.co.za');

-- One order, not yet shipped.
INSERT INTO Orders (CustomerId, PlacedOn, ShippedOn)
SELECT CustomerId, '2026-04-11', NULL FROM Customers WHERE Email = 'thandi@example.co.za';

-- Two lines, priced from the list as it stands today.
INSERT INTO OrderLines (OrderId, ProductId, Quantity, UnitPriceZar)
SELECT o.OrderId, p.ProductId, v.Qty, p.ListPriceZar
FROM (VALUES ('SKU-0002', 2), ('SKU-0003', 1)) AS v(Sku, Qty)
JOIN Products p ON p.Sku = v.Sku
CROSS JOIN (SELECT TOP 1 OrderId FROM Orders ORDER BY OrderId DESC) o;

-- The order total is derived rather than stored, so it cannot disagree with its
-- own lines:
--   SELECT o.OrderId, SUM(l.Quantity * l.UnitPriceZar) AS TotalZar
--     FROM Orders o JOIN OrderLines l ON l.OrderId = o.OrderId
--    GROUP BY o.OrderId;
--
-- Now raise the list price of SKU-0002 and run that total again. It does not
-- move, because the line kept what was charged:
--   UPDATE Products SET ListPriceZar = 199.00 WHERE Sku = 'SKU-0002';
--
-- And each of these is refused by the database rather than accepted quietly:
--   INSERT INTO OrderLines (OrderId, ProductId, Quantity, UnitPriceZar)
--   VALUES (1, 1, 0, 10.00);    -- CK_OrderLines_Quantity
--   UPDATE Orders SET ShippedOn = '2026-01-01' WHERE OrderId = 1;  -- CK_..._ShippedOn
