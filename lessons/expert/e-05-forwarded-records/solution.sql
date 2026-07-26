-- Rebuild the heap to remove the forwarding pointers (forwarded_record_count -> 0).
-- The scan no longer chases pointers to migrated rows, so logical reads drop sharply.
ALTER TABLE dbo.Orders REBUILD;

-- (Alternatively, CREATE CLUSTERED INDEX CIX_Orders ON dbo.Orders(OrderId); would also
--  eliminate forwarding by turning the heap into a b-tree.)

SELECT COUNT(*) FROM Orders;
