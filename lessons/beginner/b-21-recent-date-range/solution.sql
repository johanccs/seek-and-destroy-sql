-- Fix: index the timestamp so the range predicate becomes a seek to the recent tail.
-- INCLUDE UserId so the index covers the query.
CREATE NONCLUSTERED INDEX IX_Logins_LoginAt ON Logins(LoginAt) INCLUDE (UserId);

SELECT LoginId, UserId, LoginAt
FROM Logins
WHERE LoginAt >= '2025-12-31T00:00:00';
