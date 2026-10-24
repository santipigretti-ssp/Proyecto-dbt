import csv
import os
import sys
from pathlib import Path
import pandas as pd
from dotenv import load_dotenv
from google.cloud import bigquery
from google.oauth2 import service_account

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)  # relative paths (datasets_kaggle/, keys/) resolve from any cwd
load_dotenv(ROOT / ".env")  # loads .env file if present

PROJECT  = os.getenv("GCP_PROJECT", "your-gcp-project-id")
DATASET  = os.getenv("GCP_DATASET", "olist_raw")
LOCATION = os.getenv("GCP_LOCATION", "EU")
KEY_FILE = os.getenv("GCP_KEYFILE")  # optional — leave unset to use gcloud ADC

# Auth: service account key file if provided, otherwise Application Default Credentials
# (run `gcloud auth application-default login` for ADC)
if KEY_FILE:
    credentials = service_account.Credentials.from_service_account_file(KEY_FILE)
    client = bigquery.Client(project=PROJECT, credentials=credentials)
else:
    client = bigquery.Client(project=PROJECT)

TABLES = {
    "raw_orders":               "datasets_kaggle/olist_orders_dataset.csv",
    "raw_customers":            "datasets_kaggle/olist_customers_dataset.csv",
    "raw_order_items":          "datasets_kaggle/olist_order_items_dataset.csv",
    "raw_payments":             "datasets_kaggle/olist_order_payments_dataset.csv",
    "raw_products":             "datasets_kaggle/olist_products_dataset.csv",
    "raw_sellers":              "datasets_kaggle/olist_sellers_dataset.csv",
    "raw_category_translation": "datasets_kaggle/product_category_name_translation.csv",
    "raw_reviews":              "datasets_kaggle/olist_order_reviews_dataset.csv",
    "raw_geolocation":          "datasets_kaggle/olist_geolocation_dataset.csv",
}

job_config = bigquery.LoadJobConfig(
    write_disposition="WRITE_TRUNCATE",
    autodetect=True,
)

# a load job fails if the target dataset does not exist yet
dataset = bigquery.Dataset(f"{PROJECT}.{DATASET}")
dataset.location = LOCATION
client.create_dataset(dataset, exists_ok=True)

for table_name, csv_path in TABLES.items():
    print(f"Uploading {csv_path} -> {DATASET}.{table_name} ...", end=" ", flush=True)
    if table_name == "raw_reviews":
        # comments contain embedded newlines inside quoted fields — csv.reader
        # with newline='' is the only parser that handles multiline fields correctly
        with open(csv_path, encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            headers = next(reader)
            all_rows = list(reader)
        total_lines = len(all_rows)
        rows = [row for row in all_rows if len(row) == len(headers)]
        df = pd.DataFrame(rows, columns=headers)
    else:
        with open(csv_path, encoding="utf-8") as f:
            total_lines = sum(1 for _ in f) - 1
        df = pd.read_csv(csv_path, on_bad_lines="skip")

    # a skipped row is silent data loss downstream: stop instead of loading a partial table
    skipped = total_lines - len(df)
    if skipped:
        sys.exit(f"\nERROR: {skipped} malformed rows in {csv_path}; nothing loaded for this table.")

    table_ref = f"{PROJECT}.{DATASET}.{table_name}"
    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()
    print(f"done ({len(df):,} rows)")

print("\nAll tables uploaded successfully.")
