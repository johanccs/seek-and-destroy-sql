-- Rewrite NOT IN as NOT EXISTS. It expresses the "no matching row" intent without
-- NULL ambiguity, so the optimizer builds a single-pass anti-join (hash/merge) that
-- reads Suppressed ONCE instead of re-scanning it for every one of the 300,000
-- orders. Same result, ~300,000 reads down to a few hundred.
SELECT COUNT(*)
FROM Orders o
WHERE NOT EXISTS (SELECT 1 FROM Suppressed s WHERE s.CustomerId = o.CustomerId);
