-- Keep the indexed column bare. Move the arithmetic to the constant side so the
-- predicate becomes a sargable range the IX_Orders_Total index can seek.
-- Total * 1.1 > 1500  is algebraically  Total > 1500 / 1.1.
SELECT OrderId, CustomerId, OrderDate, Total FROM Orders WHERE Total > 1500 / 1.1;
