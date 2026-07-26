-- Keep the indexed column (o.CustomerCode) bare by converting the OTHER side down
-- to its type. Now the join compares VARCHAR = VARCHAR, so SQL Server can seek
-- IX_Orders_CustomerCode for the matching code instead of scanning every order and
-- converting each CustomerCode to INT. (The real-world fix is to store matching
-- types; casting the literal side demonstrates the seek being restored.)
SELECT o.OrderId, o.Total
FROM Orders o
JOIN Customers c ON o.CustomerCode = CAST(c.CustomerId AS VARCHAR(10))
WHERE c.CustomerId = 100;
