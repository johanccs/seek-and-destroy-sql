-- Fix: cast the small side's NVARCHAR key DOWN to VARCHAR so the big Orders
-- index stays sargable. Now the join probes IX_Orders_CustomerCode with a Seek.
SELECT o.OrderId, o.Total
FROM Orders o
JOIN Customers c ON o.CustomerCode = CAST(c.CustomerCode AS VARCHAR(20))
WHERE c.CustomerCode = N'CUST000042';
