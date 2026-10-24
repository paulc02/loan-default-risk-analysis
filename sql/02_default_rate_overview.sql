--  Question: What is the overall default rate in the loan portfolio?

SELECT
    COUNT(*)                                   AS total_clients,
    SUM(target)                                AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)   AS default_percentage
FROM application_train;

-- Conclusion: Roughly 8% of clients (about 24.8k out of 307.5k) defaulted.
