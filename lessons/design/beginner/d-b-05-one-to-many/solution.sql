-- The reference model, as the canvas would generate it.
-- Customers is the "one" side; Orders is the "many" side and carries the key.

CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    Name       nvarchar(100) NOT NULL,
    Email      nvarchar(200) NOT NULL,
    City       nvarchar(100) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)
);

CREATE TABLE Orders (
    OrderId     int           NOT NULL IDENTITY(1,1),
    CustomerId  int           NOT NULL,
    OrderedOn   date          NOT NULL,
    ProductName nvarchar(100) NOT NULL,
    AmountZar   decimal(10,2) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY (OrderId)
);

-- The relationship itself. NOT NULL on Orders.CustomerId is what makes it
-- mandatory: an order cannot exist without a customer.
ALTER TABLE Orders ADD CONSTRAINT FK_Orders_Customers
    FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId);

-- SQL Server does NOT create this index for you. See the module narrative.
CREATE INDEX IX_Orders_CustomerId ON Orders (CustomerId);

-- Move the spreadsheet data across: one customer row per distinct person,
-- then each order pointing at its customer.
INSERT INTO Customers (Name, Email, City)
SELECT DISTINCT CustomerName, CustomerEmail, CustomerCity FROM LegacyOrders;

INSERT INTO Orders (CustomerId, OrderedOn, ProductName, AmountZar)
SELECT c.CustomerId, l.OrderedOn, l.ProductName, l.AmountZar
FROM LegacyOrders l
JOIN Customers c ON c.Email = l.CustomerEmail;
