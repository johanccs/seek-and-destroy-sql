-- A CTE is inlined at every reference, so the aggregate over Orders is recomputed each time.
-- Materialize the expensive intermediate result ONCE into a #temp table, then reference it freely.
SELECT CustomerId, SUM(Total) AS Revenue
INTO #CustTotals
FROM Orders
GROUP BY CustomerId;

SELECT CustomerId, Revenue
FROM #CustTotals
WHERE Revenue > (SELECT AVG(Revenue) FROM #CustTotals)
  AND Revenue < (SELECT MAX(Revenue) FROM #CustTotals);
