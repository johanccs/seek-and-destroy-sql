-- Compare the prefix with a sargable LIKE range instead of SUBSTRING.
-- LIKE 'ELEC%' seeks the index to the 'ELEC' range; SUBSTRING(Sku,1,4) could not.
SELECT ProductId, Sku, Name FROM Products WHERE Sku LIKE 'ELEC%';
