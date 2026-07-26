IF DB_ID('Lesson_i_18_covering_index_avoids_lookup') IS NOT NULL
BEGIN
    ALTER DATABASE Lesson_i_18_covering_index_avoids_lookup SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Lesson_i_18_covering_index_avoids_lookup;
END
GO
CREATE DATABASE Lesson_i_18_covering_index_avoids_lookup;
GO
USE Lesson_i_18_covering_index_avoids_lookup;
GO
CREATE TABLE dbo.Tickets
(
    TicketId   INT IDENTITY(1,1) CONSTRAINT PK_Tickets PRIMARY KEY CLUSTERED,
    AssignedTo INT           NOT NULL,
    Priority   VARCHAR(10)   NOT NULL,
    Subject    VARCHAR(200)  NOT NULL
);
GO
;WITH n AS (SELECT TOP (300000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) rn
            FROM sys.all_objects a CROSS JOIN sys.all_objects b)
INSERT INTO dbo.Tickets (AssignedTo, Priority, Subject)
SELECT (rn % 2000) + 1,
       CASE rn % 3 WHEN 0 THEN 'High' WHEN 1 THEN 'Medium' ELSE 'Low' END,
       'Ticket subject line number ' + CAST(rn AS VARCHAR(10))
FROM n;
GO
-- A non-covering index: it can seek by AssignedTo but must look up Priority/Subject
-- from the clustered index for every matching row.
CREATE NONCLUSTERED INDEX IX_Tickets_AssignedTo ON dbo.Tickets(AssignedTo);
GO
UPDATE STATISTICS dbo.Tickets WITH FULLSCAN;
GO
