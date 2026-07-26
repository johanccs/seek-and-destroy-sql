-- Fix: composite index with the equality column (StoreId) first and the range
-- column (SaleDate) second, INCLUDE-ing Amount to cover the query. The engine seeks
-- to StoreId = 7 and then range-seeks June within that store.
CREATE NONCLUSTERED INDEX IX_Sales_Store_Date ON Sales(StoreId, SaleDate) INCLUDE (Amount);

SELECT SaleId, SaleDate, Amount
FROM Sales
WHERE StoreId = 7
  AND SaleDate >= '2025-06-01' AND SaleDate < '2025-07-01';
