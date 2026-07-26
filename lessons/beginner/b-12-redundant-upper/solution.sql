-- SQL Server's default collation is case-insensitive, so wrapping the column in
-- UPPER() is redundant AND non-sargable. Compare the column directly and the
-- index can seek -- the match is still case-insensitive.
SELECT CustomerId, Email, Name FROM Customers WHERE Email = 'user12345@example.com';
