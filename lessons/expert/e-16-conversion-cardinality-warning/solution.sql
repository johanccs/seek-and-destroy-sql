-- Fix: match the literal to the column's type so no conversion happens. The unique
-- index seeks again, and -- just as important -- the optimizer's row estimate becomes
-- accurate, so the convert warning disappears.
SELECT DeviceId, Serial, Model
FROM dbo.Devices
WHERE Serial = '500123';
