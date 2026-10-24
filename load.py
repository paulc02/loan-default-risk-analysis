import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect

load_dotenv()

folder = Path("data")
engine = create_engine(
    f"postgresql+psycopg2://{os.environ['PGUSER']}:{os.environ['PGPASSWORD']}"
    f"@{os.environ['PGHOST']}:{os.environ['PGPORT']}/{os.environ['PGDATABASE']}"
)

files = [
    "application_train",
    "application_test",
    "bureau",
    "bureau_balance",
    "previous_application",
    "POS_CASH_balance",
    "installments_payments",
    "credit_card_balance",
]

existing = set(inspect(engine).get_table_names())

for name in files:
    table = name.lower()
    if table in existing:
        print("skipping (already exists):", name)
        continue

    path = folder / f"{name}.csv"

    # creeaza tabela goala, cu tipurile deduse dintr-un esantion
    sample = pd.read_csv(path, nrows=200_000)
    sample.columns = sample.columns.str.lower()
    sample.head(0).to_sql(table, engine, index=False)

    # incarca tot fisierul cu COPY
    conn = engine.raw_connection()
    try:
        with conn.cursor() as cur, open(path, "r", encoding="utf-8") as f:
            cur.copy_expert(
                f"COPY {table} FROM STDIN WITH (FORMAT csv, HEADER true)", f
            )
        conn.commit()
    finally:
        conn.close()
    print("done:", name)