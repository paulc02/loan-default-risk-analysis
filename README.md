# Loan Default Risk Analysis

An end-to-end analytics project on **307,511 loan applicants** from the [Home Credit Default Risk](https://www.kaggle.com/c/home-credit-default-risk) dataset: raw data loaded into PostgreSQL, explored and transformed with SQL, scored with a machine learning model, and presented in an interactive Tableau dashboard.

**[View the live dashboard on Tableau Public](https://public.tableau.com/views/loan-default-risk-dashboard/Portfoliooverview)**

## Business questions answered

1. **Who defaults, and where is risk concentrated?** Default rate across demographic, loan and credit-history segments.
2. **What drives default risk?** Which behaviors and attributes separate good clients from bad ones.
3. **Can we rank applicants by risk?** A model that sorts clients from lowest to highest risk, using only data available at application time.
4. **Where should a bank set its rejection cut-off?** The trade-off between defaults avoided and good clients lost.

## Key findings

- **Default is rare:** about 8% of clients (24.8k of 307.5k) defaulted, so accuracy is a misleading metric and models are judged with AUC, precision and recall.
- **Younger and less educated clients are riskier:** the default rate falls from 12.3% for clients under 25 to 3.7% for those 65+, and from 10.9% (lower secondary education) to 1.8% (academic degree).
- **Payment behavior is a strong signal:** clients with average credit card utilization of 75% or more default at 16.2%, versus 5.7% for those under 25%. Clients who underpaid more than a quarter of their installments default at 12.0%, versus 7.1% for those who never underpaid.
- **Missing history is informative:** clients with no credit bureau record default at 10.1%, above the portfolio average, so "no history" is kept as a signal rather than treated as noise.
- **External credit scores dominate the model:** `ext_source_1/2/3` are the most important features in both models, followed by employment length and payment behavior.
- **The model separates risk clearly:** LightGBM reaches **AUC 0.765** (logistic regression baseline: 0.756). Splitting clients into five equal risk groups, the default rate rises from **1.6% to 21.5%**, roughly 14 times higher.
- **Rejecting the riskiest 10% of applicants avoids about 35% of all defaults while losing under 8% of good clients.** The default rate is 28.2% among rejected applicants versus 5.8% among approved ones.

<!-- Interest income lost on rejected clients and loss per default are not modeled, so the final cut-off is a business decision. -->

## Workflow

```
Raw CSVs  ->  PostgreSQL  ->  SQL analysis  ->  customer_features  ->  Modeling  ->  customer_scores  ->  Tableau
 (Kaggle)      load.py        sql/01 - 06        sql/07 (1 row/       notebooks/     (out-of-fold        dashboard
                                                  client, 29 cols)    modeling       risk scores)
```

1. **Load:** `load.py` creates one table per CSV and bulk-loads it with PostgreSQL `COPY`.
2. **Prepare the database:** primary keys, indexes and foreign keys (`sql/01a`, `sql/01b`).
3. **Explore with SQL:** default rate overview and by segment, credit bureau history, previous applications, payment behavior (`sql/02` to `sql/06`). Each query file ends with a written conclusion.
4. **Build features:** `sql/07_customer_features.sql` joins application data with aggregates from five history tables into one row per client. It includes ratios such as credit-to-income, bureau debt ratio, average payment delay and credit card utilization.
5. **Model:** `notebooks/modeling.ipynb` cleans the data, trains a logistic regression baseline and a LightGBM model (balanced class weights, stratified split, early stopping on a held-out validation set), and interprets both.
6. **Score and export:** out-of-fold risk scores (5-fold cross-validation) are written back to PostgreSQL as `customer_scores`, and summary files are saved to `modeling_exports/` for the dashboard.

## Project structure

```
loan-default-risk-analysis/
├── dashboard/          # Dashboard files
├── modeling_exports/   # Model outputs used by the dashboard (metrics, ROC points, feature importance, business scenario)
├── notebooks/
│   └── modeling.ipynb  # Cleaning, modeling, evaluation, interpretation, business scenario
├── sql/
│   ├── 01a_keys_and_indexes.sql
│   ├── 01b_foreign_keys.sql
│   ├── 02_default_rate_overview.sql
│   ├── 03_default_rate_by_segment.sql
│   ├── 04_bureau_analysis.sql
│   ├── 05_previous_applications.sql
│   ├── 06_payment_behavior.sql
│   └── 07_customer_features.sql
├── load.py             # Loads the raw CSVs into PostgreSQL
├── requirements.txt
├── .env.example        # Template for database credentials
└── .python-version
```

## Tech stack

| Area | Tools |
|---|---|
| Database and SQL | PostgreSQL, window functions, CTEs, aggregate filters, `CREATE TABLE AS` |
| Python | pandas, SQLAlchemy, psycopg2, python-dotenv |
| Machine learning | scikit-learn (pipelines, logistic regression), LightGBM |
| Visualization | matplotlib, seaborn, Tableau Public |

## Data

The raw files are **not included** in this repository because of their size. Download them from the [Kaggle competition page](https://www.kaggle.com/c/home-credit-default-risk/data) and place them in a `data/` folder at the project root.

| File | Description |
|---|---|
| `application_train.csv` / `application_test.csv` | Main application data, with the `TARGET` label in the train set |
| `bureau.csv` / `bureau_balance.csv` | Credit history from other institutions |
| `previous_application.csv` | Previous applications at Home Credit |
| `POS_CASH_balance.csv` | Monthly balance of previous POS and cash loans |
| `installments_payments.csv` | Repayment history of previous credits |
| `credit_card_balance.csv` | Monthly balance of previous credit cards |

## How to reproduce

**Prerequisites:** Python (see `.python-version`), a running PostgreSQL instance, and the dataset in `data/`.

```bash
# 1. Install
git clone https://github.com/paulc02/loan-default-risk-analysis.git
cd loan-default-risk-analysis
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 2. Configure the database (create the "home_credit" database first)
cp .env.example .env             # then edit .env with your credentials

# 3. Load the raw data
python load.py

# 4. Run the SQL scripts in order
psql -d home_credit -f sql/01a_keys_and_indexes.sql
psql -d home_credit -f sql/01b_foreign_keys.sql
psql -d home_credit -f sql/07_customer_features.sql
# 02-06 are analysis queries: open them in your SQL client and run them step by step

# 5. Run the modeling notebook
jupyter notebook notebooks/modeling.ipynb
```

## Limitations and next steps

- **Scores are rankings, not probabilities.** Class weights were used to handle the imbalance, so risk scores are not calibrated default probabilities. Calibration would be needed to estimate expected losses.
- **The cut-off ignores money.** The business scenario counts clients, not amounts. Including interest income and loss per default would allow a cost-based threshold.
- **Fairness.** Gender is predictive in the model but should not be used directly in real credit decisions because of regulatory and fairness concerns.
- **Next steps:** hyperparameter tuning, SHAP explanations, and additional features from `bureau_balance` and the monthly history tables.
