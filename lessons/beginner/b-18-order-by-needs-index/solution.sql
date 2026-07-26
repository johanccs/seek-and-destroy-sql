-- Fix: an index on the ORDER BY column stores rows already sorted, so the query
-- reads the first 50 in index order with no Sort operator. INCLUDE Price to cover it.
CREATE NONCLUSTERED INDEX IX_Books_Title ON dbo.Books(Title) INCLUDE (Price);

SELECT TOP (50) BookId, Title, Price
FROM dbo.Books
ORDER BY Title;
