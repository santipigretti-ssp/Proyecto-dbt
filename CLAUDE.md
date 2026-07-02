# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

All dbt commands must be run from the project root with the venv active:

```bash
source venv/bin/activate
```

```bash
dbt run                          # build all models
dbt run --select staging         # build only staging layer
dbt run --select marts           # build only mart layer
dbt run --select stg_orders      # build a single model
dbt test                         # run all 49 tests
dbt test --select stg_reviews    # run tests for a single model
dbt deps                         # install packages (dbt-utils)
dbt docs generate && dbt docs serve  # generate and open docs at localhost:8080
dbt clean                        # remove target/ and dbt_packages/
```

To load raw CSVs into BigQuery:

```bash
python upload_to_bigquery.py
```

## Authentication

This project uses **Application Default Credentials** (no key file). Before running anything for the first time:

```bash
gcloud auth application-default login
gcloud config set project mi-proyecto-dbt
```

The dbt profile (`~/.dbt/profiles.yml`) uses `method: oauth`. The upload script reads `GCP_PROJECT` and `GCP_DATASET` from `.env` (copy `.env.example` to get started).

## Architecture

**Stack:** dbt Core 1.11 + BigQuery (`mi-proyecto-dbt`, dataset `dbt_staging`, region EU) + dbt-utils.

**Data flow:**

```
datasets_kaggle/*.csv
      ↓ upload_to_bigquery.py
BigQuery: raw_* tables (dbt_staging)
      ↓ sources.yml (source: olist_raw)
models/staging/stg_*.sql       →  materialized as views
      ↓ ref()
models/intermediate/int_*.sql  →  materialized as views
      ↓ ref()
models/marts/fct_*.sql         →  materialized as tables
```

**Staging layer** (`models/staging/`) — one model per raw table. Responsibilities: column renaming to Spanish business names, type casting (timestamps, ints), deduplication (`stg_reviews` uses `ROW_NUMBER()` to keep the latest review per `review_id`), and joining `raw_category_translation` inside `stg_products`.

**Intermediate layer** (`models/intermediate/`) — reusable aggregations shared across marts, e.g. `int_pagos_por_orden` (payments rolled up to one row per `order_id`), so marts don't duplicate the same grouping logic.

**Marts layer** (`models/marts/`) — all prefixed `fct_`. Each mart answers a specific business question and joins only from staging/intermediate models via `ref()`, never directly from sources.

**Testing** (`models/staging/stg_olist.yml`, `models/intermediate/intermediate.yml`, `models/marts/marts.yml`) — `unique`/`not_null` on PKs (including each mart's grain), `accepted_values` on categoricals (`order_status`, `puntaje`, `tipo_pago`), `relationships` for FK integrity (order_id, product_id), `not_null` on mart metrics.

## Key Conventions

- Column names are in **Spanish** (e.g. `ciudad`, `estado`, `monto`, `puntaje`)
- Marts filter to `order_status = 'delivered'` where revenue/delivery metrics are involved
- `sources.yml` points to `database: mi-proyecto-dbt`, `schema: dbt_staging` — update these if using a different GCP project
- `raw_category_translation` has a BOM character in its source CSV; the join in `stg_products` works because pandas strips it on upload
- `raw_reviews` CSV has embedded newlines in free-text fields; `upload_to_bigquery.py` handles this with `csv.reader(newline='')` instead of pandas
