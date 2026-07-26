CREATE TABLE Books
(
    BookId INT IDENTITY(1,1) CONSTRAINT PK_Books PRIMARY KEY CLUSTERED,
    Title  VARCHAR(200)  NOT NULL,
    Author VARCHAR(100)  NOT NULL,
    Price  DECIMAL(10,2) NOT NULL
);
GO
-- Unique, zero-padded titles so the ORDER BY result is deterministic.
;WITH n AS (SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO Books (Title, Author, Price)
SELECT 'Book ' + RIGHT('000000' + CAST(rn AS VARCHAR(6)), 6),
       'Author ' + CAST((rn % 5000) + 1 AS VARCHAR(6)),
       CAST((rn % 90) + 9.99 AS DECIMAL(10,2))
FROM n;
GO
UPDATE STATISTICS Books WITH FULLSCAN;
GO
