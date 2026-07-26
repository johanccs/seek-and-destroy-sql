-- To answer "are there any open orders?", EXISTS stops at the FIRST matching row
-- instead of counting every one. It reads a handful of pages, not the whole range.
IF EXISTS (SELECT 1 FROM Orders WHERE Status = 'Open')
    SELECT 1 AS AnyOpen;
ELSE
    SELECT 0 AS AnyOpen;
