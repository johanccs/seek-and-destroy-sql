-- Push the math out of the function and off the column. fn_NetAmount(Total) = Total * 0.9,
-- so 'net > 900' is exactly 'Total > 1000' -- a SARGable range the index can seek,
-- with no per-row scalar UDF calls.
SELECT OrderId, Total FROM Orders WHERE Total > 1000;
