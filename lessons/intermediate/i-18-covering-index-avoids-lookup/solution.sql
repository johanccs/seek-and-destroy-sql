-- Fix: cover the query by INCLUDE-ing the columns it returns, so the seek carries
-- Priority and Subject in the index leaf and never has to look them up. DROP_EXISTING
-- rebuilds the same-named index in place.
CREATE NONCLUSTERED INDEX IX_Tickets_AssignedTo
    ON dbo.Tickets(AssignedTo)
    INCLUDE (Priority, Subject)
    WITH (DROP_EXISTING = ON);

SELECT AssignedTo, Priority, Subject
FROM dbo.Tickets
WHERE AssignedTo = 42;
