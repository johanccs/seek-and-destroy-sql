-- The price list the business already publishes. The learner reads it to see
-- what a product is and what identifies one; they do not model this table.
IF OBJECT_ID('PriceListExtract') IS NOT NULL DROP TABLE PriceListExtract;

CREATE TABLE PriceListExtract (
    Sku          nvarchar(20)  NOT NULL PRIMARY KEY,
    ProductName  nvarchar(120) NOT NULL,
    ListPrice    decimal(10,2) NOT NULL,
    Discontinued bit           NOT NULL
);
GO

INSERT INTO PriceListExtract (Sku, ProductName, ListPrice, Discontinued) VALUES
    ('SKU-0001', 'Rooibos tea, 250g',       64.99, 0),
    ('SKU-0002', 'Enamel mug, 350ml',      129.00, 0),
    ('SKU-0003', 'Cast iron pan, 24cm',    749.00, 0),
    ('SKU-0004', 'Linen apron',            329.50, 1),
    ('SKU-0005', 'Beeswax wrap, set of 3', 189.00, 0);
GO
