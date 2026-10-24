-- 1. What is the average payment delay per client, and how does it relate to default?
-- days_instalment = day the installment was due, days_entry_payment = day it was actually paid
-- (both relative to the application date). A positive difference means a late payment.
-- Installments with no recorded payment date are ignored.

WITH client_delay AS (
    SELECT
        sk_id_curr,
        AVG(days_entry_payment - days_instalment) AS avg_delay_days
    FROM installments_payments
    WHERE days_entry_payment IS NOT NULL
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN d.avg_delay_days IS NULL THEN '0. No installment history'
            WHEN d.avg_delay_days <= 0    THEN '1. On time or early'
            WHEN d.avg_delay_days <= 3    THEN '2. Up to 3 days late'
            WHEN d.avg_delay_days <= 7    THEN '3. 3-7 days late'
            ELSE                               '4. Over 7 days late'
        END AS delay_group
    FROM application_train a
    LEFT JOIN client_delay d ON a.sk_id_curr = d.sk_id_curr
)
SELECT
    delay_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY delay_group
ORDER BY delay_group;

-- Conclusion: Clients who pay late on average default much more often: 11.33% for those over 7 days late vs. 8.09% for those
-- paying on time or early. Average delay is a strong candidate feature for the model.

-- 2. How many clients underpaid installments, and is that linked to default?
-- A 1-unit tolerance is used so that rounding differences are not counted as underpayment.

WITH client_underpaid AS (
    SELECT
        sk_id_curr,
        1.0 * COUNT(*) FILTER (WHERE amt_payment < amt_instalment - 1) / COUNT(*) AS underpaid_share
    FROM installments_payments
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN u.underpaid_share IS NULL THEN '0. No installment history'
            WHEN u.underpaid_share = 0     THEN '1. Never underpaid'
            WHEN u.underpaid_share < 0.10  THEN '2. Underpaid in under 10% of installments'
            WHEN u.underpaid_share < 0.25  THEN '3. Underpaid in 10-25% of installments'
            ELSE                                '4. Underpaid in over 25% of installments'
        END AS underpayment_group
    FROM application_train a
    LEFT JOIN client_underpaid u ON a.sk_id_curr = u.sk_id_curr
)
SELECT
    underpayment_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY underpayment_group
ORDER BY underpayment_group;

-- Conclusion: Default rises from 7.10% for clients who never underpaid to 12.04% for those who underpaid in over 25% of 
-- their installments.

-- 3. How does credit card utilization relate to default?
-- Utilization is averaged over all monthly records of a client (months with a zero limit are ignored).
-- Negative balances (rare data errors) fall into the first bracket.

WITH client_utilization AS (
    SELECT
        sk_id_curr,
        AVG(amt_balance::numeric / NULLIF(amt_credit_limit_actual, 0)) AS avg_utilization
    FROM credit_card_balance
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN u.sk_id_curr IS NULL       THEN '0. No credit card'
            WHEN u.avg_utilization IS NULL  THEN '1. Card with no usable limit'
            WHEN u.avg_utilization < 0.25   THEN '2. Under 25%'
            WHEN u.avg_utilization < 0.50   THEN '3. 25-50%'
            WHEN u.avg_utilization < 0.75   THEN '4. 50-75%'
            ELSE                                 '5. 75% or more'
        END AS utilization_group
    FROM application_train a
    LEFT JOIN client_utilization u ON a.sk_id_curr = u.sk_id_curr
)
SELECT
    utilization_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY utilization_group
ORDER BY utilization_group;

-- Conclusion: Default rises with utilization: 5.71% for those under 25% vs. 16.17% for those at 75% or more. Clients with no
-- credit card stand at 7.84%.

-- 4. Do clients with late payments in POS/cash loans default more often?

WITH client_dpd AS (
    SELECT
        sk_id_curr,
        MAX(sk_dpd) AS max_dpd
    FROM pos_cash_balance
    GROUP BY sk_id_curr
),
grouped AS (
    SELECT
        a.target,
        CASE
            WHEN d.sk_id_curr IS NULL THEN '0. No POS/cash history'
            WHEN d.max_dpd = 0        THEN '1. Never past due'
            WHEN d.max_dpd <= 30      THEN '2. Up to 30 days past due'
            WHEN d.max_dpd <= 90      THEN '3. 31-90 days past due'
            ELSE                           '4. Over 90 days past due'
        END AS dpd_group
    FROM application_train a
    LEFT JOIN client_dpd d ON a.sk_id_curr = d.sk_id_curr
)
SELECT
    dpd_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY dpd_group
ORDER BY dpd_group;

-- Conclusion: Clients who were more than 90 days past due on a POS/cash loan default at 8.51% vs. 7.72% for those never 
-- past due. The past-due groups are small (~400 clients in the 90+ group), so the signal is strong but rare.

-- 5. How has payment behavior evolved over time for defaulting vs. non-defaulting clients?
-- Average payment delay by month before the application (0 = the month of the application,
-- 11 = eleven months earlier), over the last 12 months. LAG shows the month-over-month change.

WITH monthly AS (
    SELECT
        a.target,
        FLOOR(-i.days_instalment / 30.0)::int          AS months_before_application,
        COUNT(*)                                        AS installments,
        AVG(i.days_entry_payment - i.days_instalment)   AS avg_delay_days
    FROM installments_payments i
    JOIN application_train a ON a.sk_id_curr = i.sk_id_curr
    WHERE i.days_entry_payment IS NOT NULL
      AND i.days_instalment BETWEEN -359 AND 0
    GROUP BY a.target, months_before_application
)
SELECT
    target,
    months_before_application,
    installments,
    ROUND(avg_delay_days::numeric, 2) AS avg_delay_days,
    ROUND((avg_delay_days - LAG(avg_delay_days) OVER (
        PARTITION BY target
        ORDER BY months_before_application DESC
    ))::numeric, 2)                   AS change_vs_previous_month
FROM monthly
ORDER BY target, months_before_application DESC;

-- Conclusion: On average, both groups pay their installments before the due date (negative delay), but defaulting clients 
-- (target = 1) pay noticeably closer to the deadline: 6.85 days early in the month of the application vs. 8.59 days early 
-- for non-defaulting clients. The gap between the two groups widens as the application date approaches, from about 1.1 days 
-- twelve months earlier (-9.70 vs. -8.57) to about 1.9 days one month before (-8.66 vs. -6.76). Both groups drift towards 
-- later payments over time, but the drift is stronger for defaulting clients (+1.72 days vs. +1.11), which suggests that 
-- payment behavior gradually deteriorates before a default. The absolute differences are small (1-2 days), so average delay 
-- is a moderate signal that is best used together with other features. Month 0 has fewer installments (it covers only the 
-- part of the month before the application), so it is less reliable than the other months.	