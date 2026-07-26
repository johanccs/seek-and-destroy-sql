-- Give ProductId its own index (as the LEADING key) so the predicate can seek.
CREATE NONCLUSTERED INDEX IX_Orders_Prod ON Orders(ProductId) INCLUDE (CustomerId, Total);

SELECT OrderId, CustomerId, ProductId, Total FROM Orders WHERE ProductId = 42;
