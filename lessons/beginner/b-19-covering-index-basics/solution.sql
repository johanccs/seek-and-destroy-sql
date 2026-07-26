-- Fix: cover the query by INCLUDE-ing the returned columns, so the seek carries
-- Name and Price in the index leaf and needs no lookup. DROP_EXISTING rebuilds
-- the same index in place.
CREATE UNIQUE NONCLUSTERED INDEX IX_Products_Sku
    ON Products(Sku)
    INCLUDE (Name, Price)
    WITH (DROP_EXISTING = ON);

SELECT Sku, Name, Price
FROM Products
WHERE Sku = 'SKU012345';
