-- Simplify the algebra so the column is bare and compared to a constant:
-- Balance * 1.10 > 110000  <=>  Balance > 100000
SELECT * FROM Accounts WHERE Balance > 100000;
