-- A covering index on the filter column (with the measures INCLUDE-d) lets SQL
-- seek just the recent slice and aggregate it, instead of scanning every row.
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate_Cov
    ON Orders(OrderDate) INCLUDE (Status, Total);

SELECT Status, COUNT(*) AS Cnt, SUM(Total) AS Revenue
FROM Orders
WHERE OrderDate >= '2025-11-01'
GROUP BY Status;
