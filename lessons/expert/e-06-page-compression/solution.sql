-- Rebuild the clustered index with PAGE compression. Repetitive, low-cardinality
-- data packs far more rows per page, so the scan touches far fewer pages.
ALTER INDEX PK_Orders ON dbo.Orders REBUILD WITH (DATA_COMPRESSION = PAGE);

SELECT COUNT(*) FROM Orders;
