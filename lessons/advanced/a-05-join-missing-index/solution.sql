-- Index the join column so the matching items are seeked, not scanned.
CREATE NONCLUSTERED INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);

SELECT i.ItemId, i.Sku, i.Qty
FROM OrderItems i
JOIN Orders o ON o.OrderId = i.OrderId
WHERE o.OrderId = 4242;
