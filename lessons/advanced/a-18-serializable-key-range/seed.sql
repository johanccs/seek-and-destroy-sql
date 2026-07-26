IF DB_ID('Lesson_a_18_serializable_key_range') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_a_18_serializable_key_range SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_a_18_serializable_key_range;
END
GO
CREATE DATABASE Lesson_a_18_serializable_key_range;
GO
USE Lesson_a_18_serializable_key_range;
GO
CREATE TABLE dbo.Orders
(
    OrderId    INT IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED,
    CustomerId INT           NOT NULL,
    Amount     DECIMAL(10,2) NOT NULL
);
GO
-- An index on CustomerId lets SERIALIZABLE take fine-grained KEY-RANGE locks on
-- the CustomerId = 5 range (rather than escalating to something coarser).
INSERT INTO dbo.Orders (CustomerId, Amount)
SELECT TOP (2000) (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 100) + 1,
                  CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) % 900 + 1 AS DECIMAL(10,2))
FROM sys.all_objects a CROSS JOIN sys.all_objects b;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);
GO
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
GO
