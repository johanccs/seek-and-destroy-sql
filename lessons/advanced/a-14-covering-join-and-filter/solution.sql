-- A composite index on the join key + filter column, INCLUDE-ing the measure,
-- lets SQL Server seek Orders once per matching customer instead of scanning the
-- whole table and hash-joining.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Status
    ON dbo.Orders(CustomerId, Status) INCLUDE(Total);

SELECT c.Region, COUNT(*) AS Cnt, SUM(o.Total) AS Rev
FROM Customers c
JOIN Orders o ON o.CustomerId = c.CustomerId
WHERE c.Region = 'R7' AND o.Status = 'Open'
GROUP BY c.Region;
