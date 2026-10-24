# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

All dbt commands must be run from the project root with the venv active:

```powershell
.\.venv\Scripts\Activate.ps1     # Windows (macOS/Linux: source .venv/bin/activate)
```

First-time setup: `python -m venv .venv`, activate, `pip install -r requirements-dev.txt`, `dbt deps`.

```bash
dbt build                        # build all 27 models and run all 190 tests
dbt build --select staging       # only staging layer
dbt build --select marts         # only mart layer
dbt build --select agg_vendedores  # a single model + its tests
dbt deps                         # install packages (dbt-utils)
dbt docs generate && dbt docs serve  # docs at localhost:8080
sqlfluff lint models tests       # lint (same check CI runs)
dbt clean                        # remove target/ and dbt_packages/
```

To load raw CSVs into BigQuery (dataset `olist_raw`):

```bash
python scripts/upload_to_bigquery.py
```

## Authentication

Locally the project uses a service-account key (`GCP_KEYFILE` in `.env`, file in `keys/`) for
the upload script, and the dbt profile (`~/.dbt/profiles.yml`) uses `method: oauth`
(Application Default Credentials: `gcloud auth application-default login`). The upload script
reads `GCP_PROJECT`, `GCP_DATASET` (`olist_raw`) and `GCP_LOCATION` from `.env`.

**Gotcha:** `load_dotenv` does not override variables already in the environment. VS Code can
inject a stale `GCP_DATASET` from an older `.env` into its terminals; if the upload goes to the
wrong dataset, check `$env:GCP_DATASET` (reopening VS Code refreshes it).

## Location

This repo lives on **local disk** (`C:\Users\<user>\dev\mi_proyecto_datos`), not in Google Drive. It used
to live in `G:\Mi unidad\...`, and Drive sync caused three confusing failures: SSL handshake drops on every
BigQuery call (Drive stalls the read of certifi's `cacert.pem`), a macOS venv synced onto Windows, and
`dbt_packages/` silently losing files (symptom: `'dict object' has no attribute
'test_unique_combination_of_columns'`; fix: `dbt deps`). **Do not move the repo back into a synced folder**;
back it up through git (`origin` on GitHub) instead. If those symptoms reappear, check the location first.

Layout: `models/` `tests/` `macros/` `seeds/` `snapshots/` `analyses/` (dbt), `scripts/` (ingestion),
`docs/` (English public docs: `metrics.md`, `dashboard_guide.md`), `datasets_kaggle/`, `keys/` and
`docs/entregables/` (local only, gitignored).

Also on Windows: `scripts/upload_to_bigquery.py` prints ASCII `->` rather than the arrow, because the default
`cp1252` console encoding raises `UnicodeEncodeError` on it.

## Architecture

**Stack:** dbt Core 1.11 + BigQuery (`mi-proyecto-dbt`, region EU) + dbt-utils. CI (GitHub
Actions) runs `sqlfluff lint` and `dbt parse` with a placeholder profile; no cloud credentials.

**Datasets (one per layer):** `olist_raw` (raw CSVs) → `olist_staging` → `olist_intermediate` →
`olist_marts`. Set via `+schema` in `dbt_project.yml`; `macros/generate_schema_name.sql` uses the
schema name verbatim instead of dbt's default `<target>_<schema>` concatenation. `sources.yml`
reads the project from `target.project` and the raw dataset from `var('raw_dataset')`. The old
single dataset `dbt_staging` is legacy.

**Data flow:**

```
datasets_kaggle/*.csv
      ↓ scripts/upload_to_bigquery.py
olist_raw.raw_*  (source: olist_raw)
      ↓
olist_staging.stg_*        → views (stg_geolocation is a table)
      ↓ ref()
olist_intermediate.int_*   → views
      ↓ ref()
olist_marts.{dim,fct,agg,rpt}_*  → tables
```

**Staging** — one model per raw table: Spanish business names, type casts, and the category
translation join inside `stg_products`. Staging does **not** deduplicate: `stg_reviews` keeps its
natural `(review_id, order_id)` grain (99,224 rows = 99,224 distinct pairs). An earlier
`ROW_NUMBER()` there passed a `unique` test on `review_id` but silently discarded 814 legitimate
review–order links. Per-order fan-out is collapsed in `fct_pedidos`.

**Intermediate** — logic shared by more than one mart: `int_pagos_por_orden` (payments → one row
per order) and `int_items_geo` (buyer–seller distance per item; used by both `fct_order_items` and
`fct_pedidos`, which is why it can't live in `fct_order_items`: that model depends on `fct_pedidos`).

**Marts** — the prefix is load-bearing:

| Prefix | Role | Models |
|---|---|---|
| `dim_` | Entity with attributes | `dim_clientes` (all 96,096 customers), `dim_productos`, `dim_vendedores`, `dim_fecha` |
| `fct_` | Transactional grain + FKs | `fct_pedidos` (order), `fct_order_items` (item) |
| `agg_` | Pre-aggregated for BI, one chart each | `agg_ventas_mensual`, `agg_operacion_mensual`, `agg_metodos_pago`, `agg_take_rate`, `agg_estados_cliente`, `agg_rutas_logisticas`, `agg_puntualidad_satisfaccion`, `agg_categorias`, `agg_vendedores`, `agg_cohortes_retencion` |
| `rpt_` | Served dashboard, no grain | `rpt_resumen_ejecutivo` (1 row) |

**Every `agg_*` reads from `fct_pedidos` or `fct_order_items`, never from staging** (exception:
`agg_metodos_pago` joins `stg_payments` because payment-method rows don't exist in the facts; it
is reconciled against `fct_pedidos.valor_pagado`). That guarantees a single definition of revenue,
freight and distance — `tests/assert_reconciliacion_ingresos.sql` fails the build if any aggregate
drifts. **When adding an aggregate:** source it from the facts, add it to the reconciliation test
and its rates to `tests/assert_tasas_entre_0_y_1.sql`, ship the base count next to every average
(`total_pedidos`, `pedidos_con_resena`, ...), and add an `es_significativo` flag if small groups are noisy.

Order-grain attributes and pre-computed segments (`bucket_distancia`, `bucket_puntualidad`,
`estado_vendedor`, `es_mismo_estado`) live in `fct_pedidos`, so most new questions are a `group by`
in the BI tool over `fct_pedidos` or `fct_order_items`, not a new model.

**Testing** — `unique`/`not_null` on every PK and agg grain, `relationships` on every fact → dim FK
(that's why `dim_clientes` includes customers with no delivered order), `accepted_values` on
categoricals/segments, plus the two singular tests above. `exposures.yml` declares the planned
Looker Studio dashboard.

**Lint** — `.sqlfluff` (bigquery, jinja templater so CI needs no credentials). Excluded on purpose:
LT01 (column-aligned aliases), AM04, ST06, AM06. `tests/.sqlfluff` relaxes layout rules for the
stacked `union all` checks.

## Key Conventions

- Column names, SQL comments and yml docs are in **Spanish**; README and `docs/` are in **English**
  (portfolio audience). The README has a Spanish→English glossary.
- Marts filter to `order_status = 'delivered'` for revenue/delivery metrics. Exceptions on purpose:
  cancellation rates (`rpt_resumen_ejecutivo`, `agg_estados_cliente`, `agg_vendedores`) and the
  order-outcome columns of `agg_operacion_mensual`.
- `raw_category_translation` has a BOM character in its source CSV; the join in `stg_products` works because pandas strips it on upload
- `raw_reviews` CSV has embedded newlines in free-text fields; `upload_to_bigquery.py` handles this with `csv.reader(newline='')` instead of pandas. The script aborts if any row is malformed instead of skipping it
- `stg_orders` exposes `fecha_aprobacion_pago` and `fecha_despacho_courier`. These make the delivery-time decomposition possible — **75% of delivery time is courier transit, 22% seller handling** — and most public projects on this dataset drop them
- `stg_geolocation` is the only staging model materialized as a `table`: it averages ~1M raw rows to one per zip prefix and is joined from the facts
- Zip-code prefixes are cast to `int64` on both sides of every join (pandas autodetect already drops leading zeros on load)
- Distance uses BigQuery's `ST_DISTANCE`/`ST_GEOGPOINT` in `int_items_geo`. It's approximate (zip-prefix centroid) — call this out on dashboards. Geo joins are LEFT on purpose: 0.49% of items have no matching prefix. An order's distance is its farthest item; its origin state is its main seller's (highest-priced item; 98.7% of orders have one seller)
- **Volumetric weight units:** `dim_productos.peso_facturable_g` divides by `6.0`, not `6000`. `L×W×H/6000` yields **kilograms**, compared against `peso_g` in **grams**. With `/6000` the volumetric term won in 4 of 32,949 products (a silent no-op); with `/6.0` it wins in 66%. Do not "fix" this back
- `dim_productos.categoria`: the 2 categories missing from the translation CSV keep their Portuguese name; products with no category are `'uncategorized'`
- Exactly 1 order of 99,441 has no payment record (`bfbd0f9b…`, 2016-09-15), the only order of its month. `fct_pedidos.valor_pagado` falls back to merchandise + freight and flags it via `valor_pagado_imputado`
- Revenue is defined two ways, and **the column-name suffix always says which**: `*_productos` = item price only (R$ 13.22M); `*_pagado` / `gmv_total` = merchandise + freight (R$ 15.42M). The ~17% gap is **entirely freight** — installment financing is only 0.02%, so do not describe `payment_value` as "including installment interest". Never mix the two in one chart
- `agg_vendedores.tramo_concentracion` tiers are **exclusive** and named with their range (`Top 1%`, `Top 1-10%`, `Top 10-50%`, `Bottom 50%`). A previous version named exclusive tiers like cumulative ones ("Top 10%") and the README misreported top-10% seller share as 41.2%; the real figure is 67.1%. Cumulative reads come from `pct_ingresos_acumulado`
- MoM/YoY in `agg_ventas_mensual` use a calendar self-join, not `LAG()`: 2016-11 has no delivered orders
