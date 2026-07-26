-- Compare the VARCHAR column to a VARCHAR literal so no per-row CONVERT is needed.
SELECT * FROM Customers WHERE AccountCode = '1050000';
