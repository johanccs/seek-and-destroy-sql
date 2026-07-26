-- Fix: apply the optimizer's recommendation (with judgment). A nonclustered index on
-- CustomerId, INCLUDE-ing the returned columns, turns the scan into a covering seek --
-- and the missing-index hint disappears because the need is now met.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON Orders(CustomerId) INCLUDE (OrderDate, Total);

SELECT OrderId, OrderDate, Total
FROM Orders
WHERE CustomerId = 1234;
