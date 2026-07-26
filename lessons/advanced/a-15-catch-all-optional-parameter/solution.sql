-- OPTION(RECOMPILE) recompiles the statement with the ACTUAL value of @CustomerId.
-- With @CustomerId = 42 (not NULL), the optimizer simplifies the OR away to
-- CustomerId = 42 and seeks the index. (Dynamic SQL is the other common fix.)
DECLARE @CustomerId INT = 42;

SELECT OrderId, CustomerId, OrderDate, Total, Status
FROM Orders
WHERE (@CustomerId IS NULL OR CustomerId = @CustomerId)
OPTION (RECOMPILE);
