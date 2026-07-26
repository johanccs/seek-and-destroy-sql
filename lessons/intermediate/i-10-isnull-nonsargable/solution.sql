-- Use IS NULL instead of wrapping the column in ISNULL(): the index can seek
-- directly to the NULL group (NULLs sort at the start of the index).
SELECT OrderId, CustomerId, OrderDate, Total FROM Orders WHERE AssignedTo IS NULL;
