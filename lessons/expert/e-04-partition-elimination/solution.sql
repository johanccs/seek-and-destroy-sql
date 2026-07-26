-- A sargable half-open range on the partition key (OrderDate) lets SQL Server
-- eliminate every partition except June 2025 — it reads ~100k rows instead of 1.2M.
SELECT COUNT(*) AS Cnt, SUM(Total) AS Revenue
FROM Orders
WHERE OrderDate >= '2025-06-01' AND OrderDate < '2025-07-01';
