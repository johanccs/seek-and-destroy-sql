-- Fix: index the range column and cover the aggregate. The query range-seeks to
-- December and reads only those rows (and only Method/Amount) from the index leaf.
CREATE NONCLUSTERED INDEX IX_Payments_PaidAt ON Payments(PaidAt) INCLUDE (Method, Amount);

SELECT Method, SUM(Amount) AS Total
FROM Payments
WHERE PaidAt >= '2025-12-01'
GROUP BY Method;
