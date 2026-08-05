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
dbt test                         # run all 194 tests
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

## Windows / Google Drive gotchas

This repo lives on a Google Drive–synced path (`G:\Mi unidad\...`), which causes two failures that
look like something else entirely:

1. **`SSLError(SSLEOFError ... UNEXPECTED_EOF_WHILE_READING)` on every BigQuery call.** urllib3
   reads certifi's `cacert.pem` *after* opening the socket, and the Drive virtual filesystem stalls
   that read long enough for Google to drop the handshake. It is **not** a firewall/antivirus/network
   problem — it reproduces on any network, and `curl`/stdlib `urllib` work fine (they use the Windows
   cert store). Fix: copy the bundle to local disk and export before running dbt:
   ```
   REQUESTS_CA_BUNDLE=C:\Users\<user>\.certs\cacert.pem
   SSL_CERT_FILE=C:\Users\<user>\.certs\cacert.pem
   ```
2. **`mi_proyecto_datos/venv/` is a macOS venv synced from another machine** and is unusable on
   Windows (its shebangs point at `/Users/...`). Use `dbt-env/` at the repo *parent* instead:
   `../dbt-env/Scripts/dbt.exe`.
3. **`dbt_packages/` silently loses files to Drive sync.** Symptom: `Compilation Error ... 'dict
   object' has no attribute 'test_unique_combination_of_columns'` even though `dbt_packages/dbt_utils/`
   exists — the folder is there but most of `macros/generic_tests/` is missing. Fix: `dbt deps`.
   If tests that passed yesterday fail today with a "macro does not exist" error and nothing in
   the code changed, this is why — check for `dbt_packages 2/`-style duplicate folders too.

Also on Windows: `upload_to_bigquery.py` prints ASCII `->` rather than `→`, because the default
`cp1252` console encoding raises `UnicodeEncodeError` on the arrow.

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
models/marts/{dim,fct,agg,rpt}_*.sql  →  materialized as tables
```

**Staging layer** (`models/staging/`) — one model per raw table. Responsibilities: column renaming to Spanish business names, type casting (timestamps, ints), and joining `raw_category_translation` inside `stg_products`. Staging does **not** deduplicate: `stg_reviews` keeps its natural `(review_id, order_id)` grain because the raw table has no exact duplicates (99,224 rows = 99,224 distinct pairs). An earlier `ROW_NUMBER()` there passed a `unique` test on `review_id` but silently discarded 814 legitimate review–order links without fixing the per-order fan-out that actually broke the aggregates. Fan-out is handled where it belongs: by collapsing to order grain in `fct_pedidos`.

**Intermediate layer** (`models/intermediate/`) — reusable aggregations shared across marts, e.g. `int_pagos_por_orden` (payments rolled up to one row per `order_id`), so marts don't duplicate the same grouping logic.

**Marts layer** (`models/marts/`) — organized by dimensional role, and **the prefix is load-bearing**:

| Prefix | Role | Models |
|---|---|---|
| `dim_` | Entity with attributes | `dim_clientes`, `dim_productos`, `dim_vendedores`, `dim_fecha` |
| `fct_` | Transactional grain + FKs | `fct_pedidos` (order), `fct_order_items` (item), `fct_cohortes_retencion` |
| `agg_` | Pre-aggregated for BI | `agg_ventas_ciudad`, `agg_ventas_mensual`, … (14 total) |
| `rpt_` | Served dashboard, no grain | `rpt_resumen_ejecutivo` (1 row) |

**Every `agg_*` reads from `fct_pedidos` or `fct_order_items`, never from staging directly.** That is what guarantees a single definition of revenue, freight and distance — `tests/assert_reconciliacion_ingresos.sql` fails the build if any aggregate drifts from the facts. When adding a new aggregate, source it from the facts and add it to that test.

`fct_order_items` (item grain, FKs to all dims) is the escape hatch: most new questions ("sales by category and month", "delay by seller and state") are a `group by` in the BI tool, not a new dbt model.

**Testing** (`models/staging/stg_olist.yml`, `models/intermediate/intermediate.yml`, `models/marts/marts.yml`) — `unique`/`not_null` on PKs (including each mart's grain), `accepted_values` on categoricals (`order_status`, `puntaje`, `tipo_pago`), `relationships` for FK integrity (order_id, product_id), `not_null` on mart metrics.

## Key Conventions

- Column names are in **Spanish** (e.g. `ciudad`, `estado`, `monto`, `puntaje`)
- Marts filter to `order_status = 'delivered'` where revenue/delivery metrics are involved
- `sources.yml` points to `database: mi-proyecto-dbt`, `schema: dbt_staging` — update these if using a different GCP project
- `raw_category_translation` has a BOM character in its source CSV; the join in `stg_products` works because pandas strips it on upload
- `raw_reviews` CSV has embedded newlines in free-text fields; `upload_to_bigquery.py` handles this with `csv.reader(newline='')` instead of pandas
- `stg_orders` exposes `fecha_aprobacion_pago` and `fecha_despacho_courier` (raw `order_approved_at` / `order_delivered_carrier_date`). These are what make the delivery-time decomposition possible — **74.5% of delivery time is courier transit, only 22% is seller handling** — and most public projects on this dataset drop them in staging, which is why they can't answer who is responsible for a delay
- `olist_geolocation_dataset.csv` is loaded into BigQuery as `raw_geolocation` via `upload_to_bigquery.py` and modeled in `stg_geolocation` (one row per zip-code prefix, lat/lng averaged from the ~1M raw rows). It's the only staging model materialized as a `table` instead of a `view` — it's an aggregation over 1M rows, joined from the facts and hit by tests, so it shouldn't be recomputed on every query.
- Zip-code prefixes (`stg_customers.cp_cliente`, `stg_sellers.cp_vendedor`, `stg_geolocation.cp_prefix`) are cast to `int64`, not kept as zero-padded strings — `upload_to_bigquery.py`'s pandas autodetect already drops leading zeros on load, so joins must be int-to-int on both sides
- Distance is computed in `fct_order_items` with BigQuery's native `ST_DISTANCE`/`ST_GEOGPOINT`, not a manual haversine formula. It's approximate (zip-prefix centroid, not exact address) — call this out if surfacing the metric on a dashboard. The geo join is a LEFT join on purpose: 0.49% of items have no matching prefix, and an inner join used to drop them silently
- `agg_estados_pedido` is the only aggregate that does NOT filter to `order_status = 'delivered'` — that's the point, it exposes cancellations/failures that every other mart hides. It is **not** a funnel (no sequential drop-off, just terminal states), which is why it is no longer called `fct_embudo_pedidos`
- **Volumetric weight units:** `dim_productos.peso_facturable_g` divides by `6.0`, not `6000`. The standard courier formula `L×W×H/6000` yields **kilograms**, and it is compared against `peso_g` in **grams**. With `/6000` the volumetric term won in 4 of 32,949 products (a silent no-op); with `/6.0` it wins in 66%. Do not "fix" this back
- Exactly 1 order of 99,441 has no payment record (`bfbd0f9b…`, 2016-09-15) and it is the only order of its month, so without imputation the September 2016 GMV is null. `fct_pedidos.valor_pagado` falls back to merchandise + freight and flags it via `valor_pagado_imputado`
- Revenue is defined two ways, and **the column-name suffix always says which**: `*_productos` = item price only, no freight (R$ 13.22M); `*_pagado` / `gmv_total` = what the customer actually paid, i.e. merchandise + freight (R$ 15.42M). The gap is ~17% and is **entirely freight** — installment financing accounts for only 0.02%, so do not describe `payment_value` as "including installment interest". Never mix a `*_productos` metric with a `*_pagado` one in the same chart. `rpt_resumen_ejecutivo` carries both side by side on purpose
