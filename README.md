# Loan Default Risk Analysis

End-to-end analysis of loan default risk on the [Home Credit Default Risk](https://www.kaggle.com/c/home-credit-default-risk) dataset: raw CSVs loaded into PostgreSQL, feature engineering in SQL, modeling with scikit-learn and LightGBM, and a dashboard for presenting the results.

> **TODO:** add 1–2 sentences on the business question (e.g. "Which applicants are most likely to default, and which factors drive that risk?") and a screenshot or GIF of the dashboard here.

![Dashboard preview](docs/dashboard.png) <!-- TODO: add a screenshot and adjust the path -->

## Key results

<!-- TODO: fill in with your real numbers. Recruiters read this section first. -->

- **Best model:** LightGBM, ROC-AUC = `0.xx` on validation
- **Baseline:** Logistic Regression, ROC-AUC = `0.xx`
- **Top drivers of default:** `...`, `...`, `...`
- **Class imbalance:** ~8% defaults, handled via `...`

## Project structure

```
loan-default-risk-analysis/
├── dashboard/          # Dashboard files          (TODO: tool used, e.g. Power BI / Tableau / Streamlit)
├── modeling_exports/   # Exported datasets / model outputs   (TODO: describe contents)
├── notebooks/          # Jupyter notebooks for EDA and modeling
├── sql/                # SQL scripts for data preparation and feature engineering
├── load.py             # Loads the raw CSVs into PostgreSQL
├── requirements.txt    # Python dependencies
├── .env.example        # Template for database credentials
└── .python-version     # Python version used
```

## Tech stack

- **Language:** Python
- **Database:** PostgreSQL (via SQLAlchemy + psycopg2)
- **Data and ML:** pandas, scikit-learn, LightGBM
- **Visualization:** matplotlib, seaborn
- **Environment:** Jupyter, python-dotenv

## Data

The project uses the Home Credit Default Risk dataset from Kaggle. The raw files are **not included** in this repository because of their size. Download them from Kaggle and place them in a `data/` folder at the project root:

| File | Description |
|---|---|
| `application_train.csv` / `application_test.csv` | Main application data, with the `TARGET` label in the train set |
| `bureau.csv` / `bureau_balance.csv` | Applicants' credit history from other institutions |
| `previous_application.csv` | Previous applications at Home Credit |
| `POS_CASH_balance.csv` | Monthly balance of previous POS and cash loans |
| `installments_payments.csv` | Repayment history of previous credits |
| `credit_card_balance.csv` | Monthly balance of previous credit cards |

## Getting started

### Prerequisites

- Python (see `.python-version`)
- A running PostgreSQL instance
- The dataset files in `data/`

### 1. Clone and install

```bash
git clone https://github.com/paulc02/loan-default-risk-analysis.git
cd loan-default-risk-analysis

python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure the database

Copy the example file and fill in your credentials:

```bash
cp .env.example .env
```

```env
PGHOST=localhost
PGPORT=5432
PGUSER=postgres
PGPASSWORD=your_password_here
PGDATABASE=home_credit
```

Create the `home_credit` database in PostgreSQL if it does not exist yet.

### 3. Load the data

```bash
python load.py
```

The script creates one table per CSV (column names lowercased) and bulk-loads the data with PostgreSQL `COPY`. Tables that already exist are skipped, so it is safe to re-run.

### 4. Run the analysis

<!-- TODO: confirm the order and the file names -->

1. Run the scripts in `sql/` to build the feature tables.
2. Open the notebooks in `notebooks/` in order:

```bash
jupyter notebook
```

## Methodology

<!-- TODO: adjust to what you actually did -->

1. **Data loading:** raw CSVs into PostgreSQL
2. **Exploratory analysis:** distributions, missing values, default rate by segment
3. **Feature engineering:** aggregations from the bureau, previous application, installments and card tables, joined to the main application table in SQL
4. **Modeling:** baseline model vs. LightGBM, evaluated with ROC-AUC (`...` validation strategy)
5. **Interpretation:** feature importance and what it means for risk
6. **Dashboard:** summary of findings for non-technical readers

## Future improvements

- Hyperparameter tuning and model calibration
- Cost-sensitive threshold selection based on business costs
- Model explainability with SHAP
- Packaging the pipeline as a reproducible script or service
