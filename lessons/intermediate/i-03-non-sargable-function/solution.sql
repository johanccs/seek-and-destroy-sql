-- Keep the column bare so the predicate is SARGable. A trailing-wildcard LIKE is a
-- range the index can seek: SQL Server navigates straight to ['admin','admio').
SELECT UserId, Email FROM Users WHERE Email LIKE 'admin%';
