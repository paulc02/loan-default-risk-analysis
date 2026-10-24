-- 1. Do clients with previously refused applications default more than those never refused?

WITH prev AS (
    SELECT
        sk_id_curr,
        COUNT(*) FILTER (WHERE name_contract_status = 'Refused') AS refused_apps
    FROM previous_application
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN p.sk_id_curr IS NULL  THEN '0. No previous applications'
            WHEN p.refused_apps = 0    THEN '1. Never refused'
            WHEN p.refused_apps = 1    THEN '2. Refused once'
            WHEN p.refused_apps <= 3   THEN '3. Refused 2-3 times'
            ELSE                            '4. Refused 4+ times'
        END AS refusal_group
    FROM application_train a
    LEFT JOIN prev p ON a.sk_id_curr = p.sk_id_curr
)
SELECT
    refusal_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY refusal_group
ORDER BY refusal_group;

-- Conclusion: Clients who were refused before default more often: 7.07% for those refused once and 13.34% for those
-- refused 4+ times, vs. 5.96% for clients never refused. The 4+ group contains only 2.5k clients, so its rate should 
-- be read with caution.

-- 2. How does the default rate vary by number of previous applications?

WITH prev AS (
    SELECT
        sk_id_curr,
        COUNT(*) AS prev_apps
    FROM previous_application
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN p.sk_id_curr IS NULL THEN '0. None'
            WHEN p.prev_apps = 1      THEN '1. 1 application'
            WHEN p.prev_apps <= 3     THEN '2. 2-3 applications'
            WHEN p.prev_apps <= 6     THEN '3. 4-6 applications'
            WHEN p.prev_apps <= 10    THEN '4. 7-10 applications'
            ELSE                           '5. 11+ applications'
        END AS prev_apps_group
    FROM application_train a
    LEFT JOIN prev p ON a.sk_id_curr = p.sk_id_curr
)
SELECT
    prev_apps_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY prev_apps_group
ORDER BY prev_apps_group;

-- Conclusion: The default rate changes slitghly with the number of previous applications, from 8.38% for clients with a 
-- single application to 8.42% for those with 7-10 applications and 9.93% for those with 11 or more. The brackets between
-- these stand a little lower at 7.7-7.8%. Clients with no previous application have the lowest default rate of 5.96%.

-- 3. Which loan purposes in past applications are linked to higher risk?
-- XAP (not a cash loan) and XNA (unknown) are excluded, since they carry no purpose information.
-- A client can have several purposes, so the groups overlap.

WITH client_purposes AS (
    SELECT DISTINCT
        sk_id_curr,
        name_cash_loan_purpose AS loan_purpose
    FROM previous_application
    WHERE name_cash_loan_purpose NOT IN ('XAP', 'XNA')
)
SELECT
    cp.loan_purpose,
    COUNT(*)                                   AS clients,
    SUM(a.target)                              AS default_clients,
    ROUND(100.0 * SUM(a.target) / COUNT(*), 2) AS default_percentage
FROM client_purposes cp
JOIN application_train a ON a.sk_id_curr = cp.sk_id_curr
GROUP BY cp.loan_purpose
ORDER BY default_percentage DESC;

-- Conclusion: Among purposes with enough clients (over 1k), payments on other loans is linked to the highest default rate 
-- (15.12%) and everyday expenses to the lowest (10.37%). Purposes with very few clients show extreme rates but are not reliable.

-- 4. Does the gap between the amount requested and the amount approved say anything about default?
-- Only approved applications with a positive requested amount are used.

WITH client_ratio AS (
    SELECT
        sk_id_curr,
        AVG(amt_credit / amt_application) AS avg_approved_ratio
    FROM previous_application
    WHERE name_contract_status = 'Approved'
      AND amt_application > 0
      AND amt_credit IS NOT NULL
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN r.avg_approved_ratio IS NULL THEN '0. No approved applications'
            WHEN r.avg_approved_ratio < 0.80  THEN '1. Approved under 80% of request'
            WHEN r.avg_approved_ratio < 0.98  THEN '2. Approved 80-98% of request'
            WHEN r.avg_approved_ratio <= 1.02 THEN '3. Approved about as requested'
            ELSE                                   '4. Approved above request'
        END AS approval_gap_group
    FROM application_train a
    LEFT JOIN client_ratio r ON a.sk_id_curr = r.sk_id_curr
)
SELECT
    approval_gap_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY approval_gap_group
ORDER BY approval_gap_group;

-- Conclusion: Clients who were approved for about as requested  default at 7.42% vs. 9.45% for those approved above the 
-- request. The gap is not a strong signal on its own, but it can be kept as a candidate feature for the model. Clients 
-- without any approved application (~18k of them) stand at 6.13%.