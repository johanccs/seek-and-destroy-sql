-- Access rows in a CONSISTENT order in every transaction (always AccountId 1 then 2).
-- With a global ordering, one session simply waits briefly for the other; no cycle forms.
-- Session A:
BEGIN TRAN;
UPDATE Accounts SET Balance = Balance - 100 WHERE AccountId = 1;
UPDATE Accounts SET Balance = Balance + 100 WHERE AccountId = 2;
COMMIT;
-- Session B (SAME order 1 -> 2):
BEGIN TRAN;
UPDATE Accounts SET Balance = Balance - 50 WHERE AccountId = 1;
UPDATE Accounts SET Balance = Balance + 50 WHERE AccountId = 2;
COMMIT;
