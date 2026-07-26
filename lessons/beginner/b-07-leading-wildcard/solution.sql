-- You only need usernames that START WITH 'admin', so drop the leading %.
-- 'admin%' has a fixed left anchor, which SQL Server turns into an index RANGE
-- seek (>= 'admin' and < the next prefix). The result is identical here because
-- 'admin' only occurs at the start of a username.
SELECT UserId, Username FROM Users WHERE Username LIKE 'admin%';
