-- A filtered index over only the ~4k 'Pending' rows, covering the query with INCLUDE.
-- Tiny to store and maintain; the query becomes a small Index Seek with no key lookup.
CREATE NONCLUSTERED INDEX IX_Orders_Pending
    ON Orders(Status)
    INCLUDE (CustomerId, Total)
    WHERE Status = 'Pending';

SELECT OrderId, CustomerId, Total FROM Orders WHERE Status = 'Pending';
