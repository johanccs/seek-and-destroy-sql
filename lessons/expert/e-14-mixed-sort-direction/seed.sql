CREATE TABLE Products
(
    ProductId INT IDENTITY(1,1) CONSTRAINT PK_Products PRIMARY KEY CLUSTERED,
    Category  INT           NOT NULL,
    Price     DECIMAL(10,2) NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Products (Category, Price)
SELECT (rn % 50) + 1, CAST((rn % 900) + 1 AS DECIMAL(10,2))
FROM n;
GO
-- An all-ASCENDING index. It looks like it should serve the query... but the query
-- wants Price DESCENDING within each Category, which this index cannot provide.
CREATE NONCLUSTERED INDEX IX_Products_Cat_Price_ASC ON Products(Category ASC, Price ASC);
GO
UPDATE STATISTICS Products WITH FULLSCAN;
GO
