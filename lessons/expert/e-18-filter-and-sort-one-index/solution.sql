-- Fix: a composite index with the filter column first and the sort column next in
-- the sort's direction. The engine seeks Status = 'Open' and reads those rows already
-- ordered CreatedAt DESC (TaskId, the clustering key, follows) -- so no Sort is needed.
CREATE NONCLUSTERED INDEX IX_Tasks_Status_Created ON dbo.Tasks(Status, CreatedAt DESC) INCLUDE (Title);

SELECT TOP (50) TaskId, Title, CreatedAt
FROM dbo.Tasks
WHERE Status = 'Open'
ORDER BY CreatedAt DESC;
