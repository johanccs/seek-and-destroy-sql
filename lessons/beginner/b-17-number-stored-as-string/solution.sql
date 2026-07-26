-- Fix: quote the literal so it's VARCHAR, matching the column. The comparison stays
-- string-to-string and the unique index seeks straight to the one row.
SELECT AccountId, AccountNumber, Owner, Balance
FROM Accounts
WHERE AccountNumber = '4001234';
