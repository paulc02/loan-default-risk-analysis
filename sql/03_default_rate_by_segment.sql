-- 1. How does the default rate vary by contract type and by gender?
-- by contract type:

SELECT
    name_contract_type						  AS contract_type,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM application_train
GROUP BY name_contract_type
ORDER BY default_percentage DESC;

-- by gender:

SELECT
    code_gender							      AS gender,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM application_train
GROUP BY gender
ORDER BY default_percentage DESC;

-- Conclusion: Cash loans have a noticeably higher default rate (8.35%) than
-- revolving loans (5.48%). Male clients also default more often than female
-- clients (10.14% vs. 7%), both being compared to the overall rate of ~8%.

-- 2. How does it vary by education level and income type?
-- by education_type:

SELECT
    name_education_type						  AS education_type,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM application_train
GROUP BY education_type
ORDER BY default_percentage DESC;

-- by income_type:

SELECT
    name_income_type						  AS income_type,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM application_train
GROUP BY income_type
ORDER BY default_percentage DESC;

-- Conclusion: As expected, the higher the education level the lower the risk of default is,
-- the range being between 10.93% for clients with lower secondary education and 1.83% for
-- those with academic degrees. Default risk varies clearly by income type. Among the large
-- groups, Working clients have the highest default rate (9.59%), above the overall rate of ~8%,
-- followed by Commercial associates (7.48%). State servants (5.75%) and Pensioners (5.39%)
-- are the safest segments. Maternity leave (40.00%) and Unemployed (36.36%) show very high
-- rates, but they contain only 5 and 22 clients, so these values are not statistically
-- reliable. The same applies to Students and Businessmen (0%, 18 and 10 clients).

-- 3. How does it vary by age group?

WITH clients AS (
    SELECT
        target,
        FLOOR(-days_birth / 365.25) AS age
    FROM application_train
),
grouped AS (
    SELECT
        target,
        CASE
            WHEN age < 25 THEN '1. Under 25'
            WHEN age < 35 THEN '2. 25-34'
            WHEN age < 45 THEN '3. 35-44'
            WHEN age < 55 THEN '4. 45-54'
            WHEN age < 65 THEN '5. 55-64'
            ELSE               '6. 65+'
        END AS age_group
    FROM clients
)
SELECT
    age_group,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY age_group
ORDER BY age_group;

-- Conclusion: The default rate decreases with age, from 12.29% for clients under 25 
-- to 3.66% for those aged 65+, compared to the overall rate of ~8%. The youngest group 
-- is the riskiest, while the 65+ group is the safest. All groups have enough clients 
-- (at least 7876) for the rates to be reliable.

-- 4. How does it vary by income bracket?

WITH grouped AS (
    SELECT
        target,
        CASE
            WHEN amt_income_total < 100000 THEN '1. Under 100k'
            WHEN amt_income_total < 150000 THEN '2. 100k-150k'
            WHEN amt_income_total < 200000 THEN '3. 150k-200k'
            WHEN amt_income_total < 300000 THEN '4. 200k-300k'
            ELSE                                '5. 300k+'
        END AS income_bracket
    FROM application_train
)
SELECT
    income_bracket,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY income_bracket
ORDER BY income_bracket;

-- Conclusion: The default rateis roughly flat across income brackets, ranging from 5.96% 
-- (300k+ bracket) to 8.62% (100k-150k bracket). Income alone is not a strong separator of 
-- risk, which suggests it should be combined with other variables (e.g. credit amount, 
-- annuity, employment).

-- 5. Is there a relationship between loan size and default? 
-- by credit amount:

WITH grouped AS (
    SELECT
        target,
        CASE
            WHEN amt_credit < 200000  THEN '1. Under 200k'
            WHEN amt_credit < 400000  THEN '2. 200k-400k'
            WHEN amt_credit < 600000  THEN '3. 400k-600k'
            WHEN amt_credit < 800000  THEN '4. 600k-800k'
            WHEN amt_credit < 1000000 THEN '5. 800k-1M'
            ELSE                           '6. 1M+'
        END AS loan_size_bracket
    FROM application_train
)
SELECT
    loan_size_bracket,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY loan_size_bracket
ORDER BY loan_size_bracket;

-- by annuity (the monthly/periodic payment):

WITH grouped AS (
    SELECT
        target,
        CASE
            WHEN amt_annuity < 15000 THEN '1. Under 15k'
            WHEN amt_annuity < 25000 THEN '2. 15k-25k'
            WHEN amt_annuity < 35000 THEN '3. 25k-35k'
            WHEN amt_annuity < 50000 THEN '4. 35k-50k'
            ELSE                          '5. 50k+'
        END AS annuity_bracket
    FROM application_train
    WHERE amt_annuity IS NOT NULL
)
SELECT
    annuity_bracket,
    COUNT(*)                                  AS clients,
    SUM(target)                               AS default_clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM grouped
GROUP BY annuity_bracket
ORDER BY annuity_bracket;

-- Conclusion: Default risk does change clearly with loan size: from 5.87% for credits 
-- over 1M to 10.10% for credits between 400k and 600k. The annuity brackets show a 
-- similar pattern, ranging from 5.74% for monthly payments of 50k+ to 9.25% for monthly
-- payments of 25k-35k. Larger loans are not necessarily riskier on their own; what
-- matters is the burden relative to income, so a credit-to-income ratio would be a
-- natural next feature.

-- 6. Are there data anomalies that need cleaning?
-- a) days_employed placeholder value (365243):

SELECT
    COUNT(*) FILTER (WHERE days_employed = 365243)  AS placeholder_rows,
    ROUND(100.0 * COUNT(*) FILTER (WHERE days_employed = 365243) / COUNT(*), 2) AS placeholder_percentage
FROM application_train;

-- which income types have the placeholder, and how do they default?

SELECT
    name_income_type						  AS income_type,
    COUNT(*)                                  AS clients,
    ROUND(100.0 * SUM(target) / COUNT(*), 2)  AS default_percentage
FROM application_train
WHERE days_employed = 365243
GROUP BY income_type
ORDER BY clients DESC;

-- b) missing values in key columns:

SELECT
    COUNT(*)                                                                         AS total_clients,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ext_source_1 IS NULL) / COUNT(*), 2)        AS ext_source_1_missing_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ext_source_2 IS NULL) / COUNT(*), 2)        AS ext_source_2_missing_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ext_source_3 IS NULL) / COUNT(*), 2)        AS ext_source_3_missing_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE own_car_age IS NULL) / COUNT(*), 2)         AS own_car_age_missing_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE occupation_type IS NULL) / COUNT(*), 2)     AS occupation_type_missing_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE amt_annuity IS NULL) / COUNT(*), 2)         AS amt_annuity_missing_pct
FROM application_train;

-- c) suspicious categories and income outliers:

SELECT code_gender AS gender, COUNT(*) AS clients
FROM application_train
GROUP BY gender
ORDER BY clients;

SELECT
    MIN(amt_income_total)                                              AS min_income,
    PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY amt_income_total)     AS median_income,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amt_income_total)     AS p99_income,
    MAX(amt_income_total)                                              AS max_income
FROM application_train;

-- Conclusion: days_employed contains the placeholder value 365243 (about 1 year x 1000) for 
-- 18.01% of clients, mostly pensioners and a few unemployed, so it must be replaced with NULL 
-- before modeling as it is not a real employment length. The external score columns have 
-- 56.38% / 0.21% / 19.83% missing values (ext_source_1/2/3), and own_car_age, occupation_type 
-- and amt_annuity are also heavily incomplete, so they need an imputation strategy. The gender 
-- column has 4 rows with the "XNA" category, which can be dropped or grouped. Income has extreme 
-- outliers (max 117M vs. median 147k), so it should be capped or log-transformed.