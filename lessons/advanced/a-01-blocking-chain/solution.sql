-- Option 1 (recommended for read-mostly workloads): let readers use row versioning
-- so a SELECT never waits on an uncommitted writer.
ALTER DATABASE Lesson_a_01_blocking_chain SET READ_COMMITTED_SNAPSHOT ON;
-- Session B's SELECT now returns the last committed values immediately instead of blocking.

-- Option 2: keep write transactions as short as possible so locks are released quickly
-- (do the UPDATE and COMMIT together; never hold a transaction open across think-time).
