-- Lesson i-11: Searching a concatenated value blocks the seek
IF DB_ID('Lesson_i_11_nonsargable_concat') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_11_nonsargable_concat SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_11_nonsargable_concat;
END
GO
CREATE DATABASE Lesson_i_11_nonsargable_concat;
GO
USE Lesson_i_11_nonsargable_concat;
GO
CREATE TABLE dbo.Customers
(
    CustomerId INT IDENTITY(1,1) CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED,
    FirstName  VARCHAR(50)  NOT NULL,
    LastName   VARCHAR(50)  NOT NULL,
    Email      VARCHAR(100) NOT NULL,
    City       VARCHAR(50)  NOT NULL
);
GO
-- 50 first names and 50 last names => 2,500 full-name combos, ~80 rows each across 200k rows.
DECLARE @first TABLE (id INT IDENTITY(0,1), nm VARCHAR(50));
INSERT INTO @first (nm) VALUES
 ('John'),('Mary'),('James'),('Patricia'),('Robert'),('Jennifer'),('Michael'),('Linda'),
 ('William'),('Elizabeth'),('David'),('Barbara'),('Richard'),('Susan'),('Joseph'),('Jessica'),
 ('Thomas'),('Sarah'),('Charles'),('Karen'),('Christopher'),('Nancy'),('Daniel'),('Lisa'),
 ('Matthew'),('Betty'),('Anthony'),('Margaret'),('Mark'),('Sandra'),('Donald'),('Ashley'),
 ('Steven'),('Kimberly'),('Paul'),('Emily'),('Andrew'),('Donna'),('Joshua'),('Michelle'),
 ('Kenneth'),('Carol'),('Kevin'),('Amanda'),('Brian'),('Dorothy'),('George'),('Melissa'),
 ('Edward'),('Deborah');
DECLARE @last TABLE (id INT IDENTITY(0,1), nm VARCHAR(50));
INSERT INTO @last (nm) VALUES
 ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),
 ('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),('Gonzalez'),('Wilson'),('Anderson'),('Thomas'),
 ('Taylor'),('Moore'),('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),('White'),
 ('Harris'),('Sanchez'),('Clark'),('Ramirez'),('Lewis'),('Robinson'),('Walker'),('Young'),
 ('Allen'),('King'),('Wright'),('Scott'),('Torres'),('Nguyen'),('Hill'),('Flores'),
 ('Green'),('Adams'),('Nelson'),('Baker'),('Hall'),('Rivera'),('Campbell'),('Mitchell'),
 ('Carter'),('Roberts');
;WITH n AS
(
    SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Customers (FirstName, LastName, Email, City)
SELECT f.nm, l.nm,
       LOWER(f.nm) + '.' + LOWER(l.nm) + CAST(n.rn AS VARCHAR(10)) + '@example.com',
       CASE n.rn % 4 WHEN 0 THEN 'London' WHEN 1 THEN 'Leeds' WHEN 2 THEN 'Bristol' ELSE 'York' END
FROM n
JOIN @first f ON f.id = n.rn % 50
JOIN @last  l ON l.id = (n.rn / 50) % 50;
GO
-- Composite index that CAN seek by individual name columns (but not by a concatenation).
CREATE NONCLUSTERED INDEX IX_Customers_Name
    ON dbo.Customers(LastName, FirstName) INCLUDE (Email);
GO
UPDATE STATISTICS dbo.Customers WITH FULLSCAN;
GO
