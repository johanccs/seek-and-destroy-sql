-- Small on purpose. Building the table is not the lesson; what the engine did
-- with it is.
CREATE TABLE Customers (
    CustomerId int           NOT NULL IDENTITY(1,1),
    FullName   nvarchar(120) NOT NULL,
    Email      nvarchar(256) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerId)
);

-- The table above is now itself a row in sys.tables. The catalog is a database
-- describing a database, which is also why the Check button can read your work
-- back rather than trusting the diagram.
--
--   SELECT t.name, s.name AS schema_name
--     FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id;
--
-- And its columns are rows in sys.columns -- the shape of the table, as data:
--
--   SELECT name, system_type_id, max_length, is_nullable
--     FROM sys.columns WHERE object_id = OBJECT_ID('Customers');
--
-- Which schema did all of that land in? Not dbo:
--
--   SELECT SCHEMA_NAME() AS my_default_schema;
