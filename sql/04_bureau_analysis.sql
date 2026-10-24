-- 1. Do clients with prior credits at other institutions default more than clients without any?

WITH bureau_clients AS (
    SELECT
        sk_id_curr,
        COUNT(*) AS bureau_credits
    FROM bureau
    GROUP BY sk_id_curr
)
SELECT
    CASE
        WHEN b.sk_id_curr IS NULL THEN '1. No bureau history'
        ELSE                           '2. Has bureau history'
    END                                       AS bureau_history,
    COUNT(*)                                  AS clients,
    SUM(a.target)                             AS default_clients,
    ROUND(100.0 * SUM(a.target) / COUNT(*), 2) AS default_percentage
FROM application_train a
LEFT JOIN bureau_clients b ON a.sk_id_curr = b.sk_id_curr
GROUP BY bureau_history
ORDER BY bureau_history;

-- Conclusion: Clients without bureau history default more often (10.12%), compared to the overall rate of ~8%.
-- 44020 clients have no record at the credit bureau, which needs to be treated as a separate category (not as missing data) 
-- when modeling.

-- 2. Which credit types are associated with the highest default rate? A client can hold several credit types, so the groups 
-- below overlap (a client is counted once in each type he has).

WITH client_types AS (
    SELECT DISTINCT
        sk_id_curr,
        credit_type
    FROM bureau
)
SELECT
    ct.credit_type,
    COUNT(*)                                   AS clients,
    SUM(a.target)                              AS default_clients,
    ROUND(100.0 * SUM(a.target) / COUNT(*), 2) AS default_percentage
FROM client_types ct
JOIN application_train a ON a.sk_id_curr = ct.sk_id_curr
GROUP BY ct.credit_type
ORDER BY default_percentage DESC;

-- Conclusion: Among the large groups, credit card has the highest default rate (8.13%), while consumer credit has the 
-- lowest (7.67%). Microloans shows an extremely high rate, but it contain only 3.5k clients, so it is not reliable.

-- 3. Does the number of active credits relate to default?

WITH active AS (
    SELECT
        sk_id_curr,
        COUNT(*) FILTER (WHERE credit_active = 'Active') AS active_credits
    FROM bureau
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN act.sk_id_curr IS NULL     THEN '0. No bureau history'
            WHEN act.active_credits = 0     THEN '1. No active credits'
            WHEN act.active_credits = 1     THEN '2. 1 active credit'
            WHEN act.active_credits = 2     THEN '3. 2 active credits'
            WHEN act.active_credits <= 4    THEN '4. 3-4 active credits'
            ELSE                                 '5. 5+ active credits'
        END AS active_credits_group
    FROM application_train a
    LEFT JOIN active act ON a.sk_id_curr = act.sk_id_curr
)
SELECT
    active_credits_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY active_credits_group
ORDER BY active_credits_group;

-- Conclusion: The default rate increases with the number of active credits, from 12.05% for clients with no active 
-- credits to 12.05% for those with 5 or more while clients with no bureau history stand at 10.12%. 

-- 4. What is each client's debt ratio, and how does it relate to default?
-- Ratios below 0 (rare data errors) fall into the first bracket.

WITH client_debt AS (
    SELECT
        sk_id_curr,
        SUM(amt_credit_sum_debt) / NULLIF(SUM(amt_credit_sum), 0) AS debt_ratio
    FROM bureau
    WHERE credit_active = 'Active'
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN d.debt_ratio IS NULL THEN '0. No active credits / ratio unavailable'
            WHEN d.debt_ratio < 0.25  THEN '1. Under 25%'
            WHEN d.debt_ratio < 0.50  THEN '2. 25-50%'
            WHEN d.debt_ratio < 0.75  THEN '3. 50-75%'
            WHEN d.debt_ratio <= 1.00 THEN '4. 75-100%'
            ELSE                           '5. Over 100%'
        END AS debt_ratio_group
    FROM application_train a
    LEFT JOIN client_debt d ON a.sk_id_curr = d.sk_id_curr
)
SELECT
    debt_ratio_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY debt_ratio_group
ORDER BY debt_ratio_group;

-- Conclusion: The more indebted a client already is, the higher the default rate: 5.94% for 
-- clients under 25% of their credit limit vs. 10.67% for those at 75-100%. The "over 100%" group has
-- only ~5k clients. This ratio is a good candidate feature for the model.

-- 5. Do clients with overdue credits default more often?

WITH client_overdue AS (
    SELECT
        sk_id_curr,
        MAX(credit_day_overdue) AS max_days_overdue
    FROM bureau
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN o.sk_id_curr IS NULL       THEN '0. No bureau history'
            WHEN o.max_days_overdue = 0     THEN '1. Never overdue'
            WHEN o.max_days_overdue <= 30   THEN '2. 1-30 days overdue'
            WHEN o.max_days_overdue <= 90   THEN '3. 31-90 days overdue'
            ELSE                                 '4. Over 90 days overdue'
        END AS overdue_group
    FROM application_train a
    LEFT JOIN client_overdue o ON a.sk_id_curr = o.sk_id_curr
)
SELECT
    overdue_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY overdue_group
ORDER BY overdue_group;

-- Conclusion: Clients with overdue credits tend to default more often: 11.35% for those more than 90 days overdue vs.
-- 7.62% for those never overdue. The most likely to default category is the 1-30 days overdue clients.