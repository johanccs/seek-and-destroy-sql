-- Fix: a nonclustered index on the range column. INCLUDE the returned columns so
-- the index covers the query and the engine seeks straight to the salary band.
CREATE NONCLUSTERED INDEX IX_Employees_Salary ON Employees(Salary) INCLUDE (Name);

SELECT EmployeeId, Name, Salary
FROM Employees
WHERE Salary BETWEEN 149000 AND 149100;
