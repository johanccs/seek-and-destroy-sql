-- Compare the underlying columns individually instead of gluing them together.
-- Now the composite index on (LastName, FirstName) can seek directly to the matches.
SELECT CustomerId, FirstName, LastName, Email
FROM Customers
WHERE FirstName = 'John' AND LastName = 'Smith';
