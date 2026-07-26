-- Fix: an index keyed to match the window's PARTITION BY (CustomerId) then ORDER BY
-- (OrderDate DESC) stores rows in exactly the order the window needs, so ROW_NUMBER
-- is assigned from an ordered scan with no Sort. INCLUDE Total to cover the output.
CREATE NONCLUSTERED INDEX IX_Orders_Cust_Date ON Orders(CustomerId, OrderDate DESC) INCLUDE (Total);

WITH Ranked AS (
    SELECT OrderId, CustomerId, OrderDate, Total,
           ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY OrderDate DESC) AS rn
    FROM Orders
)
SELECT CustomerId, OrderId, OrderDate, Total
FROM Ranked
WHERE rn = 1;
