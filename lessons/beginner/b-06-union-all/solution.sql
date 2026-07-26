-- The two branches are disjoint (different customers, unique OrderId), so there
-- are never any duplicate rows to remove. UNION ALL tells SQL Server exactly that,
-- replacing the dedupe (a Merge union) with a simple Concatenation of the two seeks.
SELECT OrderId, Total FROM Orders WHERE CustomerId = 100
UNION ALL
SELECT OrderId, Total FROM Orders WHERE CustomerId = 200;
