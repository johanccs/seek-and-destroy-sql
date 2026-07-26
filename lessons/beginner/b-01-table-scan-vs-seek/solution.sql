-- Support the CustomerId predicate with a nonclustered index so SQL Server can seek.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId);

-- Same query now performs an Index Seek + Key Lookup with a handful of logical reads.
SELECT * FROM Orders WHERE CustomerId = 42;
