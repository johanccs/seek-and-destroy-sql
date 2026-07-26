-- An index on Price stores rows pre-sorted, so TOP 100 reads straight from the
-- front of the index with no run-time Sort.
CREATE NONCLUSTERED INDEX IX_Products_Price ON Products(Price);

SELECT TOP (100) ProductId, Price FROM Products ORDER BY Price;
