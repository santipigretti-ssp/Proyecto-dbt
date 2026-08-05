# Guía de armado del dashboard en Looker Studio

Cómo conectar los marts de este proyecto a Looker Studio y qué gráfico usar con cada tabla.
Todos los datos viven en BigQuery, proyecto `mi-proyecto-dbt`, dataset `dbt_staging`.

> **¿Buscás qué significa cada número?** Este documento es el *cómo armarlo*. La definición de
> cada métrica, cómo se calcula, a quién se le presenta, con qué periodicidad y qué decisiones
> habilita está en **[diccionario_metricas.md](diccionario_metricas.md)**.

---

## 1. Conectar Looker Studio a BigQuery

1. Entrar a [lookerstudio.google.com](https://lookerstudio.google.com) → **Crear** → **Informe**.
2. En el panel de fuentes de datos: **BigQuery** → autorizar si lo pide.
3. Elegir **Mi proyecto** → `mi-proyecto-dbt` → dataset `dbt_staging` → tabla → **Agregar**.
4. Repetir "Agregar datos" por cada mart que se quiera usar (cada tabla es una fuente).

> Importante: los marts ya vienen **pre-agregados** por dbt. En Looker Studio hay que poner
> las métricas con agregación **SUM** (o **AVG** para promedios/tasas), nunca recalcular sobre
> los datos crudos. Ese es justamente el motivo de que estas tablas existan.

---

## 2. Página 1 — Resumen ejecutivo

### Tarjetas de KPI (Scorecards) — fuente: `rpt_resumen_ejecutivo`

Es una tabla de **una sola fila**, pensada para las tarjetas de cabecera.

| Campo | Formato | Valor actual |
|---|---|---|
| `gmv_total` | Moneda (BRL), compacto | R$ 15.422.605 |
| `ingresos_productos` | Moneda (BRL), compacto | R$ 13.221.498 |
| `total_pedidos_entregados` | Número | 96.478 |
| `ticket_promedio_pagado` | Moneda (BRL) | R$ 159,86 |
| `total_clientes_unicos` | Número | 93.358 |
| `tasa_entrega_a_tiempo_global` | Porcentaje | 89,71 % |
| `colchon_promesa_dias` | Número (1 dec.) | 11,9 días |
| `puntaje_promedio_resenas` | Número (2 dec.) | 4,16 / 5 |
| `tasa_clientes_recurrentes` | Porcentaje | 3,00 % |
| `tasa_cancelacion` | Porcentaje | 1,24 % |

> **Usá `tasa_entrega_a_tiempo_global` (89,71 %) y no `tasa_entrega_a_tiempo` (91,89 %)** en la
> tarjeta principal: la segunda solo mira pedidos entregados y por lo tanto excluye por
> construcción a los que nunca llegaron. Y poné `colchon_promesa_dias` al lado — sin ese dato,
> un on-time del 90 % se lee como excelencia operativa cuando en realidad se consigue
> prometiendo ~24,4 días para entregar en 12,5.

> **Elegí una sola cifra de "ingresos" como titular del dashboard.** Recomendado: `gmv_total`
> (lo que pagó el cliente), que es la lectura habitual de "facturación". Dejá
> `ingresos_productos` como tarjeta secundaria si querés mostrar el neto de mercadería. Lo que
> no hay que hacer es poner las dos sin etiquetar: difieren en ~17 % y parecen un error.

### Tendencia — fuente: `agg_ventas_mensual`

- **Gráfico de series temporales.** Dimensión: `mes`. Métrica: `ingresos_productos`.
- Agregar una segunda métrica `total_pedidos` en eje derecho para ver volumen vs. facturación.
- **Al lado, un gráfico de barras con `ingresos_mom_pct`.** Es la mitad que faltaba: la curva
  de nivel sube siempre y sugiere crecimiento sano, mientras que la de variación muestra que el
  negocio se aplanó desde marzo 2018 (+2,1 %, +0,4 %, −12,4 %, +1,4 %). Sin este gráfico el
  dashboard cuenta una historia optimista que los datos no sostienen.
- ⚠️ **Filtrar los meses parciales** con `es_mes_parcial = false` (el mart ya trae la marca; no
  hace falta filtrar por fechas a mano). Esto saca la falsa caída del corte del dataset —
  pero **no** confundir eso con el aplanamiento real del punto anterior, que sí hay que mostrar.
- **No hace falta filtrar la fase piloto (2016-09 a 2017-01) a mano.** `ingresos_mom_pct` y
  `ingresos_yoy_pct` ya vienen en `null` para esos meses (dividir por 1 o 265 pedidos daba
  variaciones de cientos de miles de %). Un `null` no dibuja barra en Looker, así que el gráfico
  de barras arranca limpio directamente en 2017-02 sin ningún filtro adicional. Los niveles
  (`total_pedidos`, `ingresos_productos`) de esos meses sí se muestran en el gráfico de línea:
  ahí tiene sentido ver el arranque desde cero.
- Para YoY, tené presente que 2017 y la primera mitad de 2018 muestran variaciones altas (51 %
  a 1.507 %) que **son reales**, no un error: la plataforma estaba en su primer año de
  hipercrecimiento. Si el rango hace ilegible el eje, usá un gráfico separado para YoY 2017-2018
  vs. YoY desde mediados de 2018 en adelante (que ya se estabiliza en ~80-100 %), en vez de forzar
  los dos períodos a la misma escala.

### Embudo — fuente: `agg_estados_pedido`

- **Gráfico de barras horizontales.** Dimensión: `order_status`, métrica: `total_pedidos`,
  orden descendente.
- Lectura: 97,02 % `delivered`, 0,63 % `canceled`, 0,61 % `unavailable`.

---

## 3. Página 2 — Logística y satisfacción

### Distancia vs. costo/tiempo/satisfacción — fuente: `agg_distancia_entrega`

El hallazgo más fuerte del dataset. **Gráfico de barras combinado**, dimensión `bucket_distancia`
(ordenar por `distancia_promedio_km`), métricas `costo_envio_promedio` y `dias_entrega_promedio`,
con `puntaje_promedio` como línea en eje secundario.

| Bucket | Pedidos | Flete prom. | Días | Atraso | Score |
|---|---|---|---|---|---|
| Local (<100km) | 17.803 | R$ 13,33 | 6,4 | 6,4 % | 4,28 |
| Regional (100-500km) | 36.967 | R$ 20,96 | 11,4 | 7,2 % | 4,18 |
| Nacional (500-1500km) | 32.440 | R$ 25,38 | 14,8 | 8,7 % | 4,10 |
| Larga distancia (1500km+) | 8.792 | R$ 39,95 | 20,5 | 13,1 % | 4,00 |

### Puntualidad vs. reseñas — fuente: `agg_puntualidad_satisfaccion`

- **Tabla dinámica** o barras: dimensión `bucket_puntualidad`, métrica `puntaje_promedio` y
  `tasa_resenas_negativas`. Filtro opcional por `estado`.

### Mapa geográfico — fuente: `agg_ventas_ciudad`

- **Gráfico de mapa** (Google Maps / burbujas). Dimensión: `estado` (tipo geo: Región de Brasil).
  Métrica: `ingresos_productos`. Alternativa: tabla top-20 por `ciudad`.

### Tiempos de entrega por estado — fuente: `agg_tiempo_entrega`

- **Barras** ordenadas por `dias_entrega_p90` (no por el promedio: el p90 es la promesa que se
  le puede hacer al cliente). Filtrar con `es_significativo = true` — el mart ya trae la marca,
  no hace falta poner el umbral a mano.
- **Barra apilada con los tres tramos** (`dias_aprobacion_promedio`, `dias_handling_vendedor`,
  `dias_transito_courier`) por estado: es el gráfico que muestra que el 74,5 % del tiempo
  nacional ponderado por pedido (2,78 días de handling vs. 9,31 de tránsito) es tránsito del
  courier y no handling del vendedor. Probablemente el gráfico más accionable de todo el
  dashboard. Ojo: si el propio Looker promedia las 27 filas del mart sin ponderar por
  `pedidos_entregados`, el número que sale es otro (~14,6 días de tránsito) y ya no es
  comparable con el 74,5 % citado acá.
- **Para el mapa, usá esta tabla y no `agg_ventas_ciudad`:** un mapa de ingresos solo va a
  mostrar que São Paulo domina (obvio). Un mapa de `dias_entrega_p90` o `pct_tiempo_courier`
  muestra dónde está el problema, que es lo que produce una decisión.

---

## 4. Página 3 — Clientes, producto y vendedores

### Segmento de clientes — fuente: `dim_clientes`

- **Gráfico de torta/dona**: dimensión `segmento_cliente`, métrica `Record Count`.
- **Histograma**: dimensión `frecuencia_pedidos`, métrica `Record Count`.
- **Scatter**: `recencia_dias` (X) vs. `monetario_total_pagado` (Y), tamaño `frecuencia_pedidos`.

### Satisfacción por categoría — fuente: `agg_satisfaccion_categoria`

- **Barras** con `puntaje_promedio`, filtrando `total_resenas >= 100` (sin ese filtro, categorías
  con 3 reseñas dominan los extremos del ranking).

### Rentabilidad vs. flete — fuente: `agg_rentabilidad_flete`

- **Tabla con mapa de calor** en `ratio_flete_precio`: filas `categoria`, columnas `bucket_peso`.
  Valores altos = el flete se come el margen.

### Scorecard de vendedores — fuente: `agg_rendimiento_vendedores`

- **Tabla** con `seller_id`, `ingresos_productos`, `total_pedidos`, `dias_entrega_promedio`,
  `tasa_atraso`, `tasa_cancelacion`, `puntaje_promedio`.
- Formato condicional en rojo para `tasa_atraso` y `tasa_cancelacion` altos.
- Filtro `total_pedidos >= 20` para que el ranking sea estadísticamente significativo.

### Métodos de pago — fuente: `agg_metodos_pago`

- **Barra apilada horizontal** (no torta) por `volumen_pagado`: con 4 categorías donde una se
  lleva ~77 %, la torta desperdicia espacio y no deja comparar las tres chicas entre sí.
- Para participación usar **`pct_ordenes`**, nunca `total_pedidos` como porción de un total:
  2.181 órdenes se pagan con más de un medio, así que la columna suma más que el total real.
- `promedio_cuotas` viene en null salvo para `credit_card`, a propósito: los demás medios son
  siempre 1 cuota y promediarlos medía mix de medios de pago, no financiación.

### Take rate del marketplace — fuente: `agg_take_rate`

- **Serie temporal** con `gmv_total` y `margen_plataforma_estimado` en ejes distintos, más una
  tarjeta con el take rate global (**9,86 %**). Esa tarjeta calculá el ratio en Looker como
  `SUM(margen_plataforma_estimado) / SUM(gmv_total)` (agregación **ratio de sumas**, no `AVG`
  de la columna `take_rate_efectivo`): promediar la columna mensual sin ponderar da 9,75 %,
  arrastrado hacia abajo por los meses de fase piloto con GMV casi nulo.
- ⚠️ **Etiquetar el gráfico como "estimado"**. Estas columnas dependen de supuestos declarados
  en `dbt_project.yml`, no de datos observados: el dataset de Olist no expone la comisión. Un
  número estimado presentado como observado es el peor error posible en un dashboard.

---

## 5. Advertencias de interpretación (importantes para no leer mal el dashboard)

1. **Dos definiciones de "ingresos", ahora explícitas en el nombre de cada columna.** El sufijo
   dice de cuál se trata:
   - `*_productos` → solo mercadería, **sin flete** (`ingresos_productos`,
     `ticket_promedio_productos`). Total: R$ 13,22 M.
   - `*_pagado` / `gmv_total` → lo que **efectivamente pagó el cliente**, mercadería + flete
     (`ticket_promedio_pagado`, `volumen_pagado`, `monetario_total_pagado`). Total: R$ 15,42 M.

   La diferencia es **exactamente el flete** (~17 %). El componente de intereses por cuotas es
   apenas 0,02 %, o sea despreciable. Nunca compares una métrica `*_productos` contra una
   `*_pagado` sin aclararlo.
2. **Casi todos los marts filtran `order_status = 'delivered'`.** La única excepción es
   `agg_estados_pedido`, que existe justamente para mostrar lo que los demás ocultan.
3. **La distancia es aproximada:** se calcula entre centroides de prefijo de código postal, no
   entre direcciones exactas.
4. **`recencia_dias` se mide contra la última fecha del dataset (2018-08-29)**, no contra la fecha
   de hoy — es un dataset histórico congelado.
5. **La tasa de recompra de 3 % es real**, no un error de cálculo: es una característica conocida
   de Olist (marketplace con altísima proporción de compradores de una sola vez).
