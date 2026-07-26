-- Fix: build the index with key directions that match the ORDER BY. With
-- (Category ASC, Price DESC), a forward scan yields exactly Category ASC, Price DESC
-- (ProductId, the clustering key, is appended ASC) -- so no Sort is needed.
CREATE NONCLUSTERED INDEX IX_Products_Cat_PriceDesc ON Products(Category ASC, Price DESC);

SELECT TOP (100) ProductId, Category, Price
FROM Products
ORDER BY Category ASC, Price DESC, ProductId ASC;
