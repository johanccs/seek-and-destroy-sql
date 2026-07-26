-- Fix: a nonclustered index on the range column. INCLUDE the returned columns so
-- the index covers the query and the engine seeks straight to the salary band.
CREATE NONCLUSTERED INDEX IX_Employees_Salary ON dbo.Employees(Salary) INCLUDE (Name);

SELECT EmployeeId, Name, Salary
FROM dbo.Employees
WHERE Salary BETWEEN 149000 AND 149100;
