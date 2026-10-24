-- 1. Building a client-level table that combines application data with aggregates from the history tables.

DROP TABLE IF EXISTS customer_features;

CREATE TABLE customer_features AS
WITH base AS (
    SELECT
        sk_id_curr,
        target,
        name_contract_type,
        code_gender,
        name_education_type,
        name_income_type,
        amt_income_total,
        amt_credit,
        amt_annuity,
        FLOOR(-days_birth / 365.25)                                              AS age_years,
        CASE WHEN days_employed = 365243 THEN NULL
             ELSE -days_employed / 365.25 END                                    AS years_employed,
        amt_credit  / NULLIF(amt_income_total, 0)                                AS credit_to_income,
        amt_annuity / NULLIF(amt_income_total, 0)                                AS annuity_to_income,
        ext_source_1,
        ext_source_2,
        ext_source_3
    FROM application_train
),
bureau_agg AS (
    SELECT
        sk_id_curr,
        COUNT(*)                                                                 AS n_bureau_credits,
        COUNT(*) FILTER (WHERE credit_active = 'Active')                         AS n_bureau_active,
        MAX(credit_day_overdue)                                                  AS bureau_max_days_overdue,
        SUM(amt_credit_sum_debt) FILTER (WHERE credit_active = 'Active')
            / NULLIF(SUM(amt_credit_sum) FILTER (WHERE credit_active = 'Active'), 0) AS bureau_debt_ratio
    FROM bureau
    GROUP BY sk_id_curr
),
prev_agg AS (
    SELECT
        sk_id_curr,
        COUNT(*)                                                                 AS n_prev_apps,
        COUNT(*) FILTER (WHERE name_contract_status = 'Approved')                AS n_prev_approved,
        COUNT(*) FILTER (WHERE name_contract_status = 'Refused')                 AS n_prev_refused,
        1.0 * COUNT(*) FILTER (WHERE name_contract_status = 'Refused') / COUNT(*) AS prev_refused_share
    FROM previous_application
    GROUP BY sk_id_curr
),
inst_agg AS (
    SELECT
        sk_id_curr,
        COUNT(*)                                                                 AS n_installments,
        AVG(days_entry_payment - days_instalment)                                AS inst_avg_delay_days,
        1.0 * COUNT(*) FILTER (WHERE amt_payment < amt_instalment - 1) / COUNT(*) AS inst_underpaid_share
    FROM installments_payments
    GROUP BY sk_id_curr
),
cc_agg AS (
    SELECT
        sk_id_curr,
        AVG(amt_balance::numeric / NULLIF(amt_credit_limit_actual, 0))           AS cc_avg_utilization
    FROM credit_card_balance
    GROUP BY sk_id_curr
),
pos_agg AS (
    SELECT
        sk_id_curr,
        MAX(sk_dpd)                                                              AS pos_max_dpd
    FROM pos_cash_balance
    GROUP BY sk_id_curr
)
SELECT
    b.*,
    COALESCE(ba.n_bureau_credits, 0)  AS n_bureau_credits,
    COALESCE(ba.n_bureau_active, 0)   AS n_bureau_active,
    ba.bureau_max_days_overdue,
    ba.bureau_debt_ratio,
    COALESCE(pa.n_prev_apps, 0)       AS n_prev_apps,
    COALESCE(pa.n_prev_approved, 0)   AS n_prev_approved,
    COALESCE(pa.n_prev_refused, 0)    AS n_prev_refused,
    pa.prev_refused_share,
    COALESCE(ia.n_installments, 0)    AS n_installments,
    ia.inst_avg_delay_days,
    ia.inst_underpaid_share,
    ca.cc_avg_utilization,
    po.pos_max_dpd
FROM base b
LEFT JOIN bureau_agg ba ON ba.sk_id_curr = b.sk_id_curr
LEFT JOIN prev_agg   pa ON pa.sk_id_curr = b.sk_id_curr
LEFT JOIN inst_agg   ia ON ia.sk_id_curr = b.sk_id_curr
LEFT JOIN cc_agg     ca ON ca.sk_id_curr = b.sk_id_curr
LEFT JOIN pos_agg    po ON po.sk_id_curr = b.sk_id_curr;

ALTER TABLE customer_features ADD PRIMARY KEY (sk_id_curr);
ANALYZE customer_features;

SELECT * FROM customer_features;

-- Conclusion: The table combines 16 columns from application_train with 13 aggregated features from 5 history tables, with 
-- one row per client. The 365243 placeholder in days_employed was replaced with NULL.

-- 2. Verifying that the table has exactly one row per sk_id_curr and the same row count as application_train.

SELECT
    COUNT(*)                                   AS feature_rows,
    COUNT(DISTINCT sk_id_curr)                 AS distinct_clients,
    (SELECT COUNT(*) FROM application_train)   AS train_rows
FROM customer_features;

-- Conclusion: The table has 307,511 rows, equal to the number of distinct clients and to the row count of application_train, 
-- so the joins did not duplicate or lose any client.

-- 3. Which of the new features show the clearest difference between defaulting and non-defaulting clients?
-- a) Average of each feature by target:

SELECT
    target,
    COUNT(*)                                          AS clients,
    ROUND(AVG(credit_to_income)::numeric, 2)          AS avg_credit_to_income,
    ROUND(AVG(ext_source_2)::numeric, 3)              AS avg_ext_source_2,
    ROUND(AVG(ext_source_3)::numeric, 3)              AS avg_ext_source_3,
    ROUND(AVG(bureau_debt_ratio)::numeric, 3)         AS avg_bureau_debt_ratio,
    ROUND(AVG(bureau_max_days_overdue)::numeric, 2)   AS avg_bureau_max_days_overdue,
    ROUND(AVG(prev_refused_share)::numeric, 3)        AS avg_prev_refused_share,
    ROUND(AVG(inst_avg_delay_days)::numeric, 2)       AS avg_inst_delay_days,
    ROUND(AVG(inst_underpaid_share)::numeric, 3)      AS avg_inst_underpaid_share,
    ROUND(AVG(cc_avg_utilization)::numeric, 3)        AS avg_cc_utilization,
    ROUND(AVG(pos_max_dpd)::numeric, 2)               AS avg_pos_max_dpd
FROM customer_features
GROUP BY target
ORDER BY target;

-- b) Features ranked by the strength of their correlation with default:

SELECT
    feature,
    ROUND(correlation::numeric, 3) AS correlation_with_target
FROM (
    SELECT 'age_years'               AS feature, CORR(target, age_years)               AS correlation FROM customer_features
    UNION ALL SELECT 'years_employed',           CORR(target, years_employed)           FROM customer_features
    UNION ALL SELECT 'credit_to_income',         CORR(target, credit_to_income)         FROM customer_features
    UNION ALL SELECT 'annuity_to_income',        CORR(target, annuity_to_income)        FROM customer_features
    UNION ALL SELECT 'ext_source_1',             CORR(target, ext_source_1)             FROM customer_features
    UNION ALL SELECT 'ext_source_2',             CORR(target, ext_source_2)             FROM customer_features
    UNION ALL SELECT 'ext_source_3',             CORR(target, ext_source_3)             FROM customer_features
    UNION ALL SELECT 'n_bureau_credits',         CORR(target, n_bureau_credits)         FROM customer_features
    UNION ALL SELECT 'n_bureau_active',          CORR(target, n_bureau_active)          FROM customer_features
    UNION ALL SELECT 'bureau_debt_ratio',        CORR(target, bureau_debt_ratio)        FROM customer_features
    UNION ALL SELECT 'bureau_max_days_overdue',  CORR(target, bureau_max_days_overdue)  FROM customer_features
    UNION ALL SELECT 'n_prev_apps',              CORR(target, n_prev_apps)              FROM customer_features
    UNION ALL SELECT 'prev_refused_share',       CORR(target, prev_refused_share)       FROM customer_features
    UNION ALL SELECT 'inst_avg_delay_days',      CORR(target, inst_avg_delay_days)      FROM customer_features
    UNION ALL SELECT 'inst_underpaid_share',     CORR(target, inst_underpaid_share)     FROM customer_features
    UNION ALL SELECT 'cc_avg_utilization',       CORR(target, cc_avg_utilization)       FROM customer_features
    UNION ALL SELECT 'pos_max_dpd',              CORR(target, pos_max_dpd)              FROM customer_features
) t
ORDER BY ABS(correlation) DESC;

-- Conclusion: The strongest signals are the external scores, ext_source_3 (-0.179), ext_source_2 (-0.160) and 
-- ext_source_1 (-0.155): the higher the score, the lower the risk of default. They are followed by credit card utilization 
-- (+0.136), the only history-based feature with a comparable strength. Age (-0.078), share of previously refused 
-- applications (+0.078), years employed (-0.075) and share of underpaid installments (+0.063) show weaker but consistent 
-- effects. The remaining features (e.g. credit-to-income, maximum days overdue at the bureau, POS/cash days past due)
-- are close to zero. All correlations are below 0.18 in absolute value, which is typical for default prediction, where 
-- signal comes from combining many weak features. 