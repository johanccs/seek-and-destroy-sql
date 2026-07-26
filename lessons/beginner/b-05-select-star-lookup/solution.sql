-- Ask only for the columns the index already covers. No Notes => no Key Lookup;
-- the seek is now covering.
SELECT OrderId, CustomerId, OrderDate, Status FROM Orders WHERE CustomerId = 777;
