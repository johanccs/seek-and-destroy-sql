-- Fix: a single composite index over both filter columns lets the engine seek
-- straight to the matching rows. INCLUDE Qty so the index covers the SELECT.
CREATE NONCLUSTERED INDEX IX_Inventory_Wh_Prod ON Inventory(WarehouseId, ProductId) INCLUDE (Qty);

SELECT WarehouseId, ProductId, Qty
FROM Inventory
WHERE WarehouseId = 35 AND ProductId = 1235;
