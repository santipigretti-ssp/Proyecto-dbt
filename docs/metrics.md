# Metric definitions

What each number means, how it is built, who would look at it and **what decision it drives**.
A metric that nobody acts on doesn't belong on a dashboard, so every section ends with the
actions it enables.

> The Olist dataset is historical and frozen (2016-09 to 2018-08). The cadences below are the
> ones each mart was designed for if it were connected to live data.

Column names are in Spanish; see the glossary at the end of the [README](../README.md#a-note-on-language).

**Contents**
[Conventions](#conventions) ·
[Executive KPIs](#executive-kpis--rpt_resumen_ejecutivo) ·
[Growth](#growth--agg_ventas_mensual) ·
[Operations](#operations--agg_operacion_mensual) ·
[Payments](#payments--agg_metodos_pago) ·
[Take rate](#take-rate--agg_take_rate) ·
[States](#states--agg_estados_cliente) ·
[Routes](#routes--agg_rutas_logisticas) ·
[Promise vs. satisfaction](#promise-vs-satisfaction--agg_puntualidad_satisfaccion) ·
[Categories](#categories--agg_categorias) ·
[Sellers](#sellers--agg_vendedores) ·
[Cohorts](#cohorts--agg_cohortes_retencion)

---

## Conventions

1. **The suffix says what the money includes.** `*_productos` = merchandise only, no freight
   (R$ 13.22M). `*_pagado` / `gmv_*` = what the customer paid, merchandise + freight
   (R$ 15.42M). The ~17% gap is entirely freight. Never put one of each in the same chart.
2. **Almost everything filters to delivered orders.** The exceptions are cancellation rates and
   the order-outcome columns of `agg_operacion_mensual`, which exist to show what the rest hides.
3. **Every average ships with its base count** (`total_pedidos`, `pedidos_con_resena`,
   `pedidos_con_promesa`). If the BI tool re-groups rows, weight by that count instead of
   averaging averages.
4. **Rates are always in [0, 1].** `assert_tasas_entre_0_y_1` fails the build otherwise. A rate
   above 1 is the signature of a fan-out bug (item-level numerator, order-level denominator).
5. **Aggregates can't disagree.** All `agg_*` tables are built from `fct_pedidos` or
   `fct_order_items`, and `assert_reconciliacion_ingresos` checks that they add up to the same totals.
6. **Significance flags instead of manual filters.** `es_significativo` marks rows with enough
   volume to read (100 orders for states, categories and months; 50 for routes; 20 for sellers).
   A threshold typed into a BI filter gets lost the first time someone duplicates the report.

---

## Executive KPIs — `rpt_resumen_ejecutivo`

One row. Each metric is computed at its own grain (order, customer) and combined with a
cross join. A single orders × items join would inflate order-level metrics.

| Metric | Value | Definition |
|---|---|---|
| `gmv_total` | R$ 15,422,605 | Sum of `valor_pagado` on delivered orders: what customers paid, freight included. |
| `ingresos_productos` | R$ 13,221,498 | Merchandise only. Base for commission (see take rate). |
| `total_pedidos_entregados` | 96,478 | Delivered orders. |
| `ticket_promedio_pagado` | R$ 159.86 | GMV / delivered orders. |
| `tasa_entrega_a_tiempo` | 91.9% | On-time over **delivered** orders. Survivorship-biased. |
| `tasa_entrega_a_tiempo_global` | 89.7% | On-time over all orders that should have reached the customer, including cancelled and never delivered. **Use this one on the headline card.** |
| `colchon_promesa_dias` | 11.9 days | Average days between actual and promised delivery. Explains why on-time looks high. |
| `dias_entrega_p90` | 23 days | 1 in 10 orders takes longer than this. |
| `puntaje_promedio_resenas` | 4.16 / 5 | Average review score of delivered orders. |
| `tasa_clientes_recurrentes` | 3.0% | Customers with 2+ delivered orders over customers with at least one. |
| `tasa_cancelacion` | 1.24% | Cancelled or unavailable over all orders. |

**Audience:** CEO, board. **Cadence:** monthly.
**Actions:** GMV against plan triggers demand levers (acquisition spend, promotions) or supply
levers (onboard sellers). On-time and buffer go together: a high on-time with a large buffer
means the promise can be shortened to compete, once courier transit allows it.
**Watch out:** GMV is not the platform's revenue. See [take rate](#take-rate--agg_take_rate).

---

## Growth — `agg_ventas_mensual`

Grain: purchase month (delivered orders).

- `ingresos_mom_pct`, `pedidos_mom_pct`, `ingresos_yoy_pct`: computed with a calendar
  self-join, not `LAG()`, because 2016-11 has no delivered orders. They are NULL when either
  month has fewer than 100 orders (the 2016 pilot phase), where percentages are noise.
- `clientes_nuevos`: customers whose first delivered order is in that month. In 2018 they are
  97–98% of each month's buyers.
- `es_mes_parcial`: first and last month are cut by the dataset boundaries. Filter them out for trends.

**Audience:** commercial lead, CEO. **Cadence:** monthly.
**Actions:** a negative or flat MoM for 2+ months (as in 2018-04 to 2018-07) is the signal to
review acquisition spend and category mix. The level curve alone hides it.

---

## Operations — `agg_operacion_mensual`

Grain: purchase month, **all** orders. Delivery metrics only cover delivered orders.

- Order outcome: `pedidos_entregados`, `pedidos_cancelados`, `pedidos_sin_entregar`, `tasa_cancelacion`.
- Delivery legs: `dias_aprobacion` (platform), `dias_handling_vendedor` (seller),
  `dias_transito_courier` (courier); `dias_entrega_p50` / `p90`.
- Promise: `tasa_atraso` (late over delivered orders with both dates), `colchon_promesa_dias`
  (positive = arrived before the promise).
- Satisfaction: `puntaje_promedio`, `tasa_resenas_negativas` (1–2★).

**Audience:** operations / logistics lead. **Cadence:** weekly.
**Actions:** when `tasa_atraso` rises, the legs say who to call. In 2017-11 and 2018-02/03,
courier transit jumped 8.4 → 13.4 days while seller handling stayed at ~3. That is a carrier
conversation, not a seller one. A shrinking `colchon_promesa_dias` is the early warning: the
promise should widen before late deliveries show up in reviews.

---

## Payments — `agg_metodos_pago`

Grain: month × payment type (delivered orders).

- `pedidos` / `pct_pedidos_mes`: distinct orders using that method. **They don't add up across
  methods**, because ~2.2k orders combine methods (e.g. voucher + card).
- `volumen_pagado` / `pct_volumen_mes`: these do add up to 100% within a month.
- `promedio_cuotas`: credit card only (NULL elsewhere). Other methods are always one installment,
  so averaging them would measure payment mix, not financing appetite.

Overall: credit card 77% of orders, boleto (bank slip) 20%, voucher 4%, debit 1.5%.

**Audience:** finance, payments. **Cadence:** monthly.
**Actions:** boleto share drives cash-conversion and fraud exposure; installment depth drives the
cost of offering interest-free installments.

---

## Take rate — `agg_take_rate`

**An estimate, not observed data.** Olist's commission is not in the dataset, so it is modeled
with assumptions declared as dbt `vars`:

| Var | Default | Meaning |
|---|---|---|
| `take_rate_comision` | 15% | Commission charged on merchandise (not freight) |
| `take_rate_tarifa_pago` | 3% | Payment processing cost on GMV |

`margen_plataforma_estimado = ingresos_productos × comision − gmv_total × tarifa_pago`.
Over the whole period: R$ 1.52M margin, **9.86% effective take rate** (sum of margin / sum of
GMV; the simple average of the monthly column gives 9.75% because it weights pilot months equally).

Recompute without touching SQL: `dbt build --select agg_take_rate --vars '{take_rate_comision: 0.18}'`.

---

## States — `agg_estados_cliente`

Grain: customer state (27 rows). `iso_3166_2` (`BR-SP`) is recognized as a geographic field by
Looker Studio and Tableau; `region` groups states into the 5 IBGE regions.

Commercial (GMV, ticket, installments, `pct_gmv_nacional`), freight burden
(`ratio_flete_precio`), where orders ship from (`distancia_promedio_km`,
`pct_pedidos_mismo_estado`), delivery legs and percentiles, promise, satisfaction and
cancellation, all in one row.

**Audience:** logistics, expansion. **Cadence:** monthly.
**Actions:** Northeast states (AL, MA, CE, SE, PI) combine 15–24% late rates with 83–86% of the
time in courier transit. They are where a regional fulfillment hub or a second carrier would move
satisfaction the most.

---

## Routes — `agg_rutas_logisticas`

Grain: seller state (origin) × customer state (destination), delivered orders. Origin is the
state of the order's main seller (highest-priced item; 98.7% of orders have a single seller).

**Audience:** logistics. **Cadence:** monthly.
**Actions:** rank corridors by `total_pedidos × tasa_atraso` to find where late deliveries
actually come from. São Paulo → Rio de Janeiro (8% of orders, 15.5% late, 12.9 courier days for
443 km) underperforms São Paulo → Minas Gerais (6.4% late, 9.1 days for 496 km). That gap is
specific to the carrier on that route, not to distance.

---

## Promise vs. satisfaction — `agg_puntualidad_satisfaccion`

Grain: days between actual and promised delivery, clipped to [−20, +20] (the ends hold the tails).

The curve is mostly flat while orders arrive early (4.1–4.3) and drops at once after the promise:
3.73 at 1 day late, 2.68 at 3 days (half of reviews negative), 1.92 at 7.

**Audience:** CX, operations, product. **Cadence:** quarterly.
**Actions:** this is the quantitative case for setting promise dates conservatively and
proactively notifying customers before an order turns late. It also prices the trade-off: a
shorter promise wins conversion but every late day costs ~0.3–0.5 review points.

---

## Categories — `agg_categorias`

Grain: product category (74). Sales metrics are item-grain. Delivery and satisfaction are
computed over distinct (order, category) pairs, so a 3-item order counts once.

- `ranking`, `pct_ingresos`, `pct_ingresos_acumulado`: Pareto. The top 10 make 62.4%; 18 make 80%.
- `ratio_flete_precio`, `peso_facturable_promedio_g`: where freight eats the margin.
- `puntaje_promedio`, `tasa_resenas_negativas`, `tasa_atraso`: quality.
- `crecimiento_6m_pct`: last 6 complete months vs. the 6 before; NULL on small bases (< R$ 10k).

**Audience:** category managers. **Cadence:** monthly.
**Actions:** a scatter of `ingresos_productos` vs. `puntaje_promedio` splits categories into
"protect" (big and well rated), "fix" (big and poorly rated) and "grow or drop" (small).

---

## Sellers — `agg_vendedores`

Grain: seller with at least one delivered sale (2,970).

- Scorecard: revenue, orders, `dias_handling_vendedor` (the only leg the seller controls),
  late rate, score, negative reviews, `tasa_cancelacion` (over all orders, not just delivered),
  `categoria_principal`, `meses_con_ventas`.
- Concentration: `ranking`, `pct_ingresos_acumulado` and `pct_vendedores_acumulado` plot a
  Lorenz curve. `tramo_concentracion` groups sellers into **exclusive** tiers (`Top 1%`,
  `Top 1-10%`, `Top 10-50%`, `Bottom 50%`). The top 1% (30 sellers) make 25.9% of revenue, the
  top 10% make 67.1%, and the bottom half makes 3.3%.

**Audience:** marketplace / seller success. **Cadence:** weekly for the scorecard, quarterly for concentration.
**Actions:** a dedicated account manager for the top 1%; seller coaching or penalties where
`dias_handling_vendedor` or `tasa_cancelacion` stand out among significant sellers
(`es_significativo`, 20+ orders).

---

## Cohorts — `agg_cohortes_retencion`

Grain: acquisition month × months since first purchase.

- `tasa_retencion`: active customers / cohort size.
- `meses_observables`: how many months of history the cohort has inside the dataset. If
  `meses_desde_primera_compra` is close to it, the cell is censored by the data cut, not by
  customer behavior.

Cohorts with 13–18 months of history retain 0.2–0.6% in month 1. The 3% repeat rate is real,
not a truncation artifact.

**Audience:** CEO, growth. **Cadence:** quarterly.
**Actions:** with near-zero retention, the governing metric is acquisition cost per customer.
Loyalty programs start from a base of almost nothing.
