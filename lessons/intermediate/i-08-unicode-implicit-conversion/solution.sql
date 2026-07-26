-- Match the column's type. The literal must be VARCHAR (no N prefix) so the engine
-- compares VARCHAR to VARCHAR and can SEEK the IX_Products_Sku index instead of
-- converting every row's Sku to NVARCHAR and scanning.
SELECT ProductId, Sku, Name, Price FROM Products WHERE Sku = 'SKU012345';
