-- Two entities, because there are two different kinds of thing in the flat
-- table. A customer is not an order, however often they arrive together.
CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    FullName   nvarchar(120) NOT NULL,
    Email      nvarchar(256) NOT NULL,
    Phone      nvarchar(30)  NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)
);

-- One customer has many orders, so the key lives HERE, on the many side.
-- The other way round -- an OrderId column on Customers -- would allow a
-- customer exactly one order, which is not the world we are describing.
CREATE TABLE Orders (
    OrderId    int           NOT NULL IDENTITY(1,1),
    CustomerId int           NOT NULL,
    OrderRef   nvarchar(20)  NOT NULL,
    PlacedOn   date          NOT NULL,
    TotalZar   decimal(10,2) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId)
);

-- Each customer arrives once, however many orders they placed.
INSERT INTO Customers (FullName, Email, Phone)
SELECT DISTINCT CustomerName, CustomerEmail, CustomerPhone FROM CustomerOrdersFlat;

INSERT INTO Orders (CustomerId, OrderRef, PlacedOn, TotalZar)
SELECT c.CustomerId, f.OrderRef, f.PlacedOn, f.TotalZar
FROM CustomerOrdersFlat f
JOIN Customers c ON c.Email = f.CustomerEmail;

-- Two customers, five orders -- where before there were five of each:
--   SELECT (SELECT COUNT(*) FROM Customers) AS customers,
--          (SELECT COUNT(*) FROM Orders)    AS orders;
--
-- And a phone number now has exactly one place to be corrected:
--   UPDATE Customers SET Phone = '082 555 0999' WHERE Email = 'thandi@example.co.za';
