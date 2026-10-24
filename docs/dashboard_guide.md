# Dashboard guide (Looker Studio)

How to connect the marts to Looker Studio and which chart to build from each one. Metric
definitions live in [metrics.md](metrics.md). The same layout works in Tableau, Power BI or
Metabase.

## Connecting

1. [lookerstudio.google.com](https://lookerstudio.google.com) → **Create** → **Report** → **BigQuery**.
2. Pick your project → dataset **`olist_marts`** → table → **Add**. Repeat per table.
3. Aggregates are already aggregated by dbt. Use **SUM** for counts and amounts. For rates,
   don't use **AVG** across rows: build a calculated field as a ratio of sums, or weight by the base
   count each row carries (`total_pedidos`, `pedidos_con_resena`, …).
4. Use the `es_significativo` flag as a report filter instead of typing thresholds.

---

## Page 1: Executive overview

**Scorecards** from `rpt_resumen_ejecutivo` (one row):

| Field | Format | Note |
|---|---|---|
| `gmv_total` | Currency (BRL), compact | Headline "revenue". Pick one revenue figure as the title. |
| `total_pedidos_entregados` | Number | |
| `ticket_promedio_pagado` | Currency | |
| `tasa_entrega_a_tiempo_global` | Percent | Not `tasa_entrega_a_tiempo`, which is survivorship-biased. |
| `colchon_promesa_dias` | Number, 1 decimal | Put it next to on-time: it explains why on-time is high. |
| `puntaje_promedio_resenas` | Number, 2 decimals | |
| `tasa_clientes_recurrentes` | Percent | |
| `tasa_cancelacion` | Percent | |

**Growth** from `agg_ventas_mensual`, filtered to `es_mes_parcial = false`:
- Time series: `mes` × `ingresos_productos` (left axis) and `total_pedidos` (right axis).
- Next to it, bars of `ingresos_mom_pct`. That chart shows the 2018 plateau, which the level
  line hides. The pilot months are already NULL, so no extra filter is needed.
- Optional: stacked area of `clientes_nuevos` vs. `clientes_unicos − clientes_nuevos`, which
  shows the one-purchase nature of the business.

**Take rate** from `agg_take_rate`: time series of `gmv_total` and `margen_plataforma_estimado`
on separate axes. Label it **"estimate"**, because it depends on assumptions, not observed data.
The overall take rate card is `SUM(margen_plataforma_estimado) / SUM(gmv_total)` (9.86%), not
`AVG(take_rate_efectivo)`.

---

## Page 2: Operations

**Operations over time** from `agg_operacion_mensual`, filtered to `es_significativo = true`:
- Line chart: `tasa_atraso` and `puntaje_promedio` (secondary axis) by `mes`. The two
  deterioration episodes (2017-11, 2018-02/03) should jump out.
- Stacked bars: `dias_aprobacion`, `dias_handling_vendedor`, `dias_transito_courier` by `mes`,
  which shows that the spikes are courier transit.
- Line: `colchon_promesa_dias`, the early-warning signal.

**Promise vs. satisfaction** from `agg_puntualidad_satisfaccion`:
- Combo chart: bars of `total_pedidos`, line of `puntaje_promedio`, dimension `etiqueta`
  sorted by `dias_vs_promesa`. Add a reference line at "En la fecha".

**Distance** from `fct_pedidos` (order grain, so averages are safe), filtered to `fue_entregado = true`:
- Bars by `bucket_distancia`: AVG `gastos_envio`, AVG `dias_entrega_total`, and
  `puntaje_promedio` as a line.

---

## Page 3: Geography

**Map** from `agg_estados_cliente`:
- Filled map with `iso_3166_2` as the geo dimension (type: *Country subdivision (1st level)*).
- Color by `tasa_atraso` or `dias_entrega_p90`, not by GMV: a GMV map only says São Paulo is
  big. A delay map shows where the problem is.
- Side table: `estado`, `region`, `total_pedidos`, `pct_gmv_nacional`, `dias_entrega_p90`,
  `pct_tiempo_courier`, `puntaje_promedio`.

**Route heatmap** from `agg_rutas_logisticas`, filtered to `es_significativo = true`:
- Pivot table with heatmap: rows `estado_origen`, columns `estado_destino`, metric `tasa_atraso`
  (or `dias_entrega_promedio`). A second pivot with `total_pedidos` gives volume context.

---

## Page 4: Categories and sellers

**Category scatter** from `agg_categorias`, filtered to `es_significativo = true`:
- X `ingresos_productos`, Y `puntaje_promedio`, bubble size `total_pedidos`, color
  `ratio_flete_precio`. Reference lines at the medians create the protect / fix / grow quadrants.
- Pareto: bars of `ingresos_productos` + line of `pct_ingresos_acumulado`, sorted by `ranking`.
- Table with `crecimiento_6m_pct` and conditional formatting.

**Seller concentration** from `agg_vendedores`:
- Lorenz curve: line chart, X `pct_vendedores_acumulado`, Y `pct_ingresos_acumulado`.
- Bars: SUM `pct_ingresos` by `tramo_concentracion`.

**Seller scorecard** from `agg_vendedores`, filtered to `es_significativo = true`:
- Table: `seller_id`, `estado`, `categoria_principal`, `ingresos_productos`, `total_pedidos`,
  `dias_handling_vendedor`, `tasa_atraso`, `tasa_cancelacion`, `puntaje_promedio`. Red conditional
  formatting on handling, late and cancellation rates.

**Payment mix** from `agg_metodos_pago`:
- 100% stacked bars of `volumen_pagado` by `mes` and `tipo_pago`. Use `pct_pedidos_mes` for
  order shares and never sum `pedidos` across methods (orders can use several).

**Retention** from `agg_cohortes_retencion`:
- Pivot table with heatmap: rows `cohorte_mes`, columns `meses_desde_primera_compra`, metric
  `tasa_retencion`. Exclude month 0 (always 100%) so the color scale stays readable.

---

## Caveats to print on the dashboard

1. **Distance is approximate**: zip-prefix centroids, not exact addresses.
2. **Take rate is an estimate** built on declared assumptions.
3. **Recency is measured against 2018-08-29**, the last date in the dataset, not today.
4. **Revenue suffixes**: `*_productos` excludes freight, `*_pagado` / `gmv_*` includes it.
   Never mix them in one chart.
