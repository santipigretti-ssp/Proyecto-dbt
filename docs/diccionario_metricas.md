# Diccionario de métricas del dashboard

Qué significa cada número, cómo se calcula, quién lo mira, cada cuánto y **qué se hace con él**.

Una métrica que nadie mira o que no dispara ninguna decisión no debería estar en un dashboard.
Por eso cada ficha incluye audiencia, periodicidad y acciones: si esas tres filas no se pueden
completar, la métrica sobra.

> **Nota sobre la periodicidad.** El dataset de Olist es histórico y está congelado (2016-09 a
> 2018-08), así que hoy no hay refresco real. Las cadencias que se indican son las que
> corresponderían **si el pipeline estuviera conectado a datos vivos**, y es el criterio con el
> que se diseñó cada mart.

---

## Índice

- [Parte 1 — Resumen ejecutivo](#parte-1--resumen-ejecutivo) (`rpt_resumen_ejecutivo`)
- [Parte 2 — Crecimiento y comercial](#parte-2--crecimiento-y-comercial)
- [Parte 3 — Logística y satisfacción](#parte-3--logística-y-satisfacción)
- [Parte 4 — Clientes](#parte-4--clientes)
- [Parte 5 — Riesgo y rentabilidad](#parte-5--riesgo-y-rentabilidad)
- [Anexo — Convenciones que evitan malinterpretar](#anexo--convenciones-que-evitan-malinterpretar)

---

# Parte 1 — Resumen ejecutivo

Fuente: **`rpt_resumen_ejecutivo`** — una única fila. Alimenta las tarjetas de cabecera.

Se calcula directamente desde `fct_pedidos` y `dim_clientes`, **nunca desde otros agregados**,
para no promediar promedios. Cada métrica se computa en su propio grano y recién al final se
combinan con `cross join`: si todas salieran de un único join de órdenes con ítems, las métricas
de orden (on-time, puntaje) quedarían infladas porque una orden de 3 ítems contaría 3 veces.

---

### `gmv_total` — R$ 15.422.605

**Definición.** Volumen bruto de mercadería: todo lo que los clientes efectivamente pagaron,
incluyendo flete. Es la medida estándar de "tamaño" de un marketplace.

**Construcción.** `sum(valor_pagado)` sobre órdenes entregadas en `fct_pedidos`. `valor_pagado`
sale de un `coalesce` de dos fuentes: primero `int_pagos_por_orden.valor_total_orden` (que a su
vez es `stg_payments` agrupado por `order_id` con `sum(valor_pago)`, porque una orden puede
pagarse con varios medios); si esa orden no tiene registro de pago —pasa exactamente una vez en
todo el dataset, la orden `bfbd0f9b…` del 2016-09-15— cae a `ingresos_productos + gastos_envio`
como aproximación. La columna `valor_pagado_imputado` en `fct_pedidos` marca ese caso para
quien necesite excluirlo y trabajar solo con dato observado.

**Audiencia.** CEO, directorio, inversores. Es la cifra que se cita hacia afuera.

**Periodicidad.** Mensual para reporte de gestión; diaria en un tablero operativo.

**Acciones que dispara.**
- Es la base de la meta anual y del cálculo de crecimiento.
- Contra el presupuesto: si el GMV va debajo del plan, se activan palancas de demanda
  (inversión en adquisición, promociones) o de oferta (sumar vendedores).

**Cuidado.** El GMV **no es la facturación de la plataforma**. Ver `agg_take_rate`: el ingreso
real es ~10x menor. Confundirlos sobreestima el negocio en un orden de magnitud.

---

### `ingresos_productos` — R$ 13.221.498

**Definición.** Mercadería neta vendida, **sin flete**. Es el valor de lo que se compró, separado
del costo de moverlo.

**Construcción.** Nace a nivel ítem: `fct_pedidos` agrupa `stg_order_items` por `order_id`
(subconsulta `items_por_orden`) con `sum(monto)`, donde `monto` es el `price` de `order_items`
sin `freight_value`. `rpt_resumen_ejecutivo` vuelve a sumar esa columna ya agregada por orden
sobre las órdenes entregadas — no relee `order_items` directamente, así que no puede volver a
inflarse por el fan-out de ítems.

**Audiencia.** Comercial y category management.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Es la base sobre la que se cobra comisión, así que es el input del take rate.
- Comparado contra `gastos_envio_totales` dice cuánto del ticket se va en logística.

**Cuidado.** No compararlo con `ticket_promedio_pagado` ni con `volumen_pagado`: esas incluyen
flete y son ~17 % mayores. El sufijo `_productos` vs `_pagado` siempre indica cuál es cuál.

---

### `gastos_envio_totales` — R$ 2.198.276

**Definición.** Total pagado en concepto de flete. Representa el **14,3 %** del GMV
(R$ 2.198.276 / R$ 15.422.605).

**Construcción.** Mismo patrón que `ingresos_productos`: `sum(costo_envio)` de `order_items`
agregado por orden en `fct_pedidos`, vuelto a sumar sobre entregadas en el reporte.

**Audiencia.** Operaciones y logística; finanzas para el análisis de márgenes.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Es el argumento cuantitativo para renegociar tarifas con transportistas.
- Cruzado con `agg_distancia_entrega`, sostiene la decisión de abrir centros de distribución
  regionales: el flete promedio pasa de R$ 13,33 (local) a R$ 39,95 (larga distancia).
- Cruzado con `agg_rentabilidad_flete`, identifica categorías donde el envío se come el margen.

---

### `total_pedidos_entregados` — 96.478

**Definición.** Órdenes que llegaron efectivamente al cliente en todo el período.

**Construcción.** `count(*)` en `fct_pedidos` donde `fue_entregado` (`order_status = 'delivered'`).
`fct_pedidos` construye a `orders` como tabla base y hace `left join` contra ítems, pagos y
reseñas —no `inner join`— así que una orden entregada sin alguna de esas tres cosas (rarísimo,
pero pasa con pagos) sigue contando acá; lo que cambia es que sus columnas dependientes quedan
en `null` o imputadas.

**Audiencia.** Toda la organización; es el denominador de casi todo lo demás.

**Periodicidad.** Diaria/semanal en operaciones, mensual en gestión.

**Acciones que dispara.**
- Dimensiona la operación: cuántos paquetes hay que mover, cuánta atención al cliente hace falta.
- Junto con GMV determina el ticket promedio, que es la palanca alternativa al volumen.

**Cuidado.** Excluye canceladas y no entregadas. Para el total real de demanda ver
`agg_estados_pedido`: **97,02 %** de las órdenes termina entregada.

---

### `total_clientes_unicos` — 93.358

**Definición.** Personas distintas que compraron al menos una vez (por `id_unico_cliente`, el ID
estable del cliente real, no el `customer_id` que Olist genera por orden).

**Construcción.** `count(distinct id_unico_cliente)` sobre órdenes entregadas.

**Audiencia.** Marketing y dirección.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Base para el cálculo de CAC (inversión en marketing dividida por clientes nuevos).
- Contrastado con `total_pedidos_entregados` (96.478 pedidos / 93.358 clientes = **1,03 pedidos
  por cliente**) muestra de inmediato que casi nadie repite.

**Cuidado.** Usar `id_unico_cliente` y no `customer_id`. Olist emite un `customer_id` nuevo por
cada orden, así que contar por esa columna infla la base de clientes y borra toda recompra.

---

### `ticket_promedio_pagado` — R$ 159,86

**Definición.** Cuánto desembolsa en promedio un cliente por orden, flete incluido. Es el número
que el cliente reconocería como "lo que gasté".

**Construcción.** `gmv_total / total_pedidos_entregados`. Se calcula como cociente de dos totales,
**no** como `avg()` de un promedio por estado o por ciudad: promediar promedios da un número
distinto y equivocado.

**Audiencia.** Comercial, marketing, dirección.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Es una de las dos palancas de crecimiento (la otra es volumen de pedidos). Si el ticket cae y
  los pedidos suben, el mix se está abaratando.
- Habilita tácticas concretas: envío gratis a partir de cierto monto, bundles, cross-sell.
- El umbral de envío gratis se define contra este número, no a ojo.

**Cuidado.** Su gemelo `ticket_promedio_productos` (R$ 137,04) excluye flete. La diferencia de
R$ 22,82 es exactamente el flete promedio. Mostrar ambos sin etiquetar parece un error de datos.

---

### `ticket_promedio_productos` — R$ 137,04

**Definición.** Valor promedio de mercadería por orden, sin flete.

**Construcción.** `ingresos_productos / total_pedidos_entregados`.

**Audiencia.** Category management y pricing.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Es la métrica correcta para evaluar estrategia de precios y mix de producto, porque no está
  contaminada por el costo de envío (que depende de la geografía, no del producto).

---

### `tasa_entrega_a_tiempo_global` — 89,71 %

**Definición.** De todas las órdenes que **debían** llegar al cliente, qué proporción llegó en o
antes de la fecha prometida. Incluye en el denominador las canceladas y las que quedaron en
tránsito sin entregarse nunca.

**Construcción.** `countif(entregado_a_tiempo) / count(*)` sobre `fct_pedidos`, excluyendo solo
los estados que todavía no llegaron a la etapa de envío (`created`, `approved`, `invoiced`,
`processing`).

**Audiencia.** COO, operaciones, y es el SLA que se le comunica al cliente.

**Periodicidad.** Semanal en operaciones (para reaccionar a tiempo), mensual en gestión.

**Acciones que dispara.**
- Por debajo del umbral acordado, dispara revisión de transportista y de la fecha prometida.
- Segmentado por estado (`agg_tiempo_entrega`) señala en qué regiones incumplir es sistemático.

**Cuidado — esta es la métrica más fácil de leer mal del dashboard.** Su versión "amable",
`tasa_entrega_a_tiempo` (91,89 %), solo mira pedidos entregados y por construcción **excluye a
los que nunca llegaron**, que son justamente los peores casos. Siempre usar la global en la
tarjeta principal. Y leerla junto a `colchon_promesa_dias`, abajo.

---

### `colchon_promesa_dias` — 11,9 días

**Definición.** Cuántos días de más le promete la plataforma al cliente respecto de lo que
realmente tarda en entregar.

**Construcción.** Promedio de `fecha_estimada_entrega − fecha_entrega` en días, sobre órdenes
entregadas.

**Audiencia.** COO y producto. Es una métrica interna, no se comunica hacia afuera.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- **Es la métrica que desarma el falso orgullo del on-time.** Se entrega en 12,5 días promedio
  pero se prometen ~24,4: el 90 % de cumplimiento se consigue prometiendo de más, no entregando
  rápido.
- Acción directa: recortar la promesa acerca la fecha comprometida a la realidad y mejora
  conversión (un plazo de entrega más corto vende más), a costa de comerse el colchón. Es una
  decisión de riesgo explícita que solo se puede tomar teniendo este número.
- Si el colchón es grande **y** el on-time igual falla, el problema no es la estimación sino la
  operación.

---

### `dias_entrega_p90` — 23 días

**Definición.** 9 de cada 10 pedidos llegan en 23 días o menos. El percentil 90 de la
distribución de días entre compra y entrega.

**Construcción.** `approx_quantiles(dias_entrega_total, 100)[offset(90)]` sobre órdenes entregadas.

**Audiencia.** Operaciones y atención al cliente.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Es la promesa realista que se le puede hacer a un cliente, mucho mejor que el promedio: la
  distribución tiene cola larga (hay entregas de 100+ días) que corre el promedio hacia arriba
  sin describir la experiencia típica.
- Dimensiona la carga de atención al cliente: los pedidos que superan el p90 son los que generan
  reclamos.

**Cuidado.** Reemplazó a `entrega_mas_rapida` / `entrega_mas_lenta`, que eran ruido: un máximo de
209 días sobre una muestra de 41 pedidos no habilita ninguna decisión.

---

### `puntaje_promedio_resenas` — 4,16 / 5

**Definición.** Satisfacción declarada promedio de las órdenes entregadas.

**Construcción.** `avg(puntaje_promedio)` sobre `fct_pedidos` entregados, donde `puntaje_promedio`
ya viene colapsado a nivel orden: `fct_pedidos` agrupa `stg_reviews` por `order_id` con
`avg(puntaje)` antes de unir (547 órdenes tienen más de una reseña; sin colapsar, esas pesarían
doble y además inflarían el conteo de filas al hacer `join` orden↔reseña).

**Audiencia.** Dirección, atención al cliente, category management.

**Periodicidad.** Semanal.

**Acciones que dispara.**
- Cruzado con `agg_puntualidad_satisfaccion` cuantifica cuánto cuesta en satisfacción cada día de
  atraso — el argumento para invertir en logística.
- Por categoría (`agg_satisfaccion_categoria`) identifica catálogo problemático y dispara
  revisión de vendedores o de descripciones de producto.

**Cuidado.** Es satisfacción **de quienes respondieron**, no de todos los clientes. La tasa de
respuesta no está medida en el proyecto, así que hay un sesgo de autoselección conocido y no
cuantificado.

---

### `tasa_clientes_recurrentes` — 3,00 %

**Definición.** Proporción de clientes que compraron más de una vez.

**Construcción.** `countif(segmento_cliente = 'Recurrente') / count(*)` sobre `dim_clientes`.

**Audiencia.** CEO, marketing, inversores.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- **Define la estrategia entera del negocio.** Con 3 % de recompra, este es un negocio de
  adquisición, no de retención: el KPI que lo gobierna es el CAC y el margen de la primera compra,
  porque no hay una segunda que amortice.
- Invalida de entrada cualquier iniciativa de fidelización que asuma una base recurrente.

**Cuidado.** La duda obvia es si el 3 % es un artefacto del dataset truncado. **No lo es:**
`fct_cohortes_retencion` muestra que las cohortes con 13-18 meses de historia observable siguen
en ~0,5 % de retención al mes 1. Es comportamiento real, no corte de datos.

---

### `tasa_cancelacion` — 1,24 %

**Definición.** Proporción de órdenes canceladas o marcadas como no disponibles, sobre el total.

**Construcción.** `countif(fue_cancelado) / count(*)` sobre **todas** las órdenes de `fct_pedidos`,
sin filtrar por entregadas.

**Audiencia.** Operaciones y calidad de vendedores.

**Periodicidad.** Semanal.

**Acciones que dispara.**
- Un pico dispara investigación de causa: quiebre de stock, un vendedor puntual, fraude.
- Desagregado por vendedor (`agg_rendimiento_vendedores.tasa_cancelacion`) alimenta el proceso de
  advertencia o baja de vendedores problemáticos.

**Cuidado.** Esta métrica y `agg_estados_pedido` son **las únicas que ven órdenes no entregadas**.
Todo el resto del dashboard filtra a `delivered`, así que sin ellas las cancelaciones serían
completamente invisibles.

---

### `fecha_inicio` / `fecha_fin` — 2016-09-15 a 2018-08-29

**Definición.** Rango temporal cubierto por los datos.

**Audiencia.** Cualquiera que lea el dashboard.

**Acciones que dispara.** Ninguna por sí misma, pero **debe estar visible**: sin el período, todas
las cifras absolutas son ambiguas. También advierte que el primer y último mes están truncados
(ver `es_mes_parcial`).

---

# Parte 2 — Crecimiento y comercial

### `ingresos_mom_pct` — variación mensual

Fuente: `agg_ventas_mensual`.

**Definición.** Crecimiento de ingresos contra el mes anterior.

**Construcción.** Self-join del mart contra sí mismo por fecha calendario (`mes` vs.
`date_sub(mes, interval 1 month)`), no `lag()` por posición de fila. Se calcula en dbt y no en
el BI a propósito: es una métrica de negocio, no un formateo de gráfico.

**Audiencia.** CEO y directorio.

**Periodicidad.** Mensual, sin excepción.

**Acciones que dispara.**
- **Es el titular real del dashboard.** El nivel de ingresos siempre sube (es acumulativo) y
  sugiere salud; la variación muestra que el negocio se aplanó desde marzo 2018: +2,1 %, +0,4 %,
  −12,4 %, +1,4 %.
- Dos meses consecutivos negativos deberían disparar una revisión de plan comercial.

**Cuidado — dos trampas ya resueltas en el mart, no en el gráfico.**
1. **Bases casi cero.** Sep 2016 a ene 2017 son la fase piloto de la plataforma (1, 265, 0, 1,
   750 pedidos). Comparar contra esas bases producía variaciones de cientos de miles de %. La
   columna queda en `null` cuando el mes actual o el anterior tienen menos de 100 pedidos — un
   `null` no dibuja barra, así que el gráfico queda limpio sin necesitar un filtro manual en el
   BI. Primer valor real: **2017-02 (+109,5 %)**.
2. **Hueco de calendario.** No hay un solo pedido en **2016-11**. Comparar "12 filas atrás" en vez
   de "12 meses calendario atrás" corría la comparación un mes entero sin avisar. Por eso la
   fórmula une por fecha (`date_sub`), no por posición: un mes sin par calendario da `null` en
   vez de un número calculado contra el mes equivocado.

También filtrar `es_mes_parcial = false` en el gráfico: el primer y último mes del dataset están
cortados por la ventana de recolección y muestran una caída artificial que no es negocio.

---

### `ranking` y `pct_ingresos_acumulado` por categoría

Fuente: `agg_ventas_categoria`.

**Definición.** Qué categorías facturan más y cuántas hacen falta para explicar el grueso del
negocio. **18 categorías de 72 explican el 80 %** de la facturación.

**Construcción.** Suma de ingresos por categoría desde `fct_order_items` (solo ítems
`fue_entregado`), con `row_number() over (order by ingresos_productos desc)` para el ranking y
`sum(...) over (order by ingresos_productos desc rows between unbounded preceding and current row)`
para la participación acumulada. El corte del 80 % cae exactamente en la categoría 18
(`pet_shop`): la 17 acumula 79,69 %, la 18 la cruza en 81,29 %, así que "18 categorías" es el
número correcto de filas a mostrar, no un redondeo.

**Audiencia.** Category management y compras.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Define dónde poner el esfuerzo de surtido y de negociación con proveedores.
- La curva acumulada identifica la cola larga: categorías que ocupan operación y aportan poco.

---

### `take_rate_efectivo` — 9,86 % (estimado, global)

Fuente: `agg_take_rate`, agregado a nivel de todo el período.

**Definición.** Qué porcentaje del GMV se queda efectivamente la plataforma, después de descontar
el costo de procesar los pagos. Sobre R$ 15,42 M de GMV, el margen estimado es **R$ 1,52 M**.

**Construcción.** El mart calcula, **mes a mes**: `ingreso_comision_estimado = ingresos_productos
× comisión`, `costo_procesamiento_pagos = gmv_total × tarifa_pago`,
`margen_plataforma_estimado = ingreso_comision_estimado − costo_procesamiento_pagos`, y
`take_rate_efectivo = margen_plataforma_estimado / gmv_total` de **ese mes**. La comisión y la
tarifa **no están en el dataset**: son supuestos declarados en `dbt_project.yml` como `vars`
(15 % y 3 %), recalculables sin tocar SQL con `dbt run --vars '{take_rate_comision: 0.18}'`.

La cifra global de cabecera (**9,86 %**) es `sum(margen_plataforma_estimado) / sum(gmv_total)`
sobre las 23 filas mensuales — **no** el promedio simple de la columna `take_rate_efectivo`.
Promediar esa columna sin ponderar da 9,75 %, y el error viene de la misma fase piloto que
distorsiona `ingresos_mom_pct` más abajo: diciembre de 2016 tuvo un solo pedido y un GMV de
R$ 19,62, y su `take_rate_efectivo` de ese mes (5,33 %) pesa en el promedio exactamente igual que
un mes con R$ 1 M de GMV real. Es el mismo error de "promediar promedios" que este documento
evita en todos lados (ver `ticket_promedio_pagado`), aplicado sin querer a este mart porque no
tiene una fila `rpt_` propia que lo resuelva.

**Audiencia.** CEO, CFO, directorio.

**Periodicidad.** Mensual (la cifra global se recalcula sobre el acumulado corrido).

**Acciones que dispara.**
- Es **la** métrica de ingreso real de un marketplace. Sostiene decisiones de pricing de comisión
  y de negociación con el procesador de pagos.
- Permite simular escenarios: cuánto cambia el margen si la comisión sube 3 puntos.

**Cuidado — obligatorio.** Etiquetar siempre como **estimado** en el dashboard. Presentar un
número modelado como si fuera observado es el peor error posible en BI. Los supuestos deben
mostrarse junto al número (`supuesto_comision`, `supuesto_tarifa_pago` están en la tabla
justamente para eso). Y si se arma un KPI global en el BI a partir de esta tabla mensual,
**sumar numerador y denominador por separado antes de dividir** — nunca usar `AVG()` sobre
`take_rate_efectivo` directamente.

---

### `gmv_total`, `ingresos_productos` por ciudad/estado

Fuente: `agg_ventas_ciudad`.

**Definición.** Rendimiento económico (pedidos, mercadería, flete, GMV) por ciudad y estado del
**cliente** — no del vendedor. Responde "qué ciudades y estados generan más negocio".

**Construcción.** `fct_pedidos` filtrado a `fue_entregado`, agrupado por
`(ciudad_cliente, estado_cliente)` con sumas directas de `ingresos_productos`, `gastos_envio` y
`valor_pagado`. El grano es el par (ciudad, estado) y no solo ciudad porque hay nombres de
ciudad repetidos en distintos estados de Brasil.

**Audiencia.** Expansión comercial, marketing regional.

**Periodicidad.** Trimestral.

**Acciones que dispara.**
- Dónde concentrar inversión de marketing regional o, cruzado con `agg_distancia_entrega`, dónde
  abrir un centro de distribución.
- São Paulo (ciudad) es R$ 2,11 M de GMV — **13,7 % del total nacional** en apenas 15.045
  pedidos — seguida de Rio de Janeiro con menos de la mitad de eso.

**Cuidado.** Filtrar `es_significativo` (100+ pedidos): de **4.272 ciudades** distintas en el
dataset, solo **134** llegan a ese umbral; el resto es un puñado de ventas sueltas que no
sostiene ninguna decisión. Y para un mapa, este mart solo va a confirmar que São Paulo domina —
para encontrar un problema accionable en un mapa, usar `agg_tiempo_entrega`
(`dias_entrega_p90` o `pct_tiempo_courier`), no este.

---

### `ticket_promedio_pagado`, `promedio_cuotas` por estado

Fuente: `agg_ticket_estado`.

**Definición.** Ticket promedio (con y sin flete) y financiación por estado del cliente. Permite
ver si el gasto por orden varía geográficamente y por qué.

**Construcción.** `fct_pedidos` filtrado a `fue_entregado`, agrupado por `estado_cliente`:
`avg(valor_pagado)`, `avg(ingresos_productos)` y `avg(max_cuotas)` — este último viene de
`int_pagos_por_orden.max_cuotas`, el máximo de cuotas entre los medios de pago de la orden.

**Audiencia.** Pricing regional, logística.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- **El ticket más alto no es el estado con productos más caros: es el más lejos de São Paulo.**
  Roraima, Alagoas, Rondônia, Pará y Piauí encabezan el ranking con tickets de R$ 210 a R$ 241,
  mientras que São Paulo —el estado con más pedidos con diferencia, 40.501— tiene el ticket
  promedio **más bajo de todo el país** (R$ 142,48). El patrón es casi enteramente flete, no
  precio de producto: confirma cruzando con `agg_distancia_entrega`, que muestra el mismo
  gradiente por distancia.
- Sostiene diferenciar el umbral de envío gratis por región en vez de uno único nacional.

**Cuidado.** Filtrar `es_significativo` (100+ pedidos): Roraima tiene apenas 41 pedidos y no
debería entrar en un ranking de "estado más caro" sin esa marca.

---

# Parte 3 — Logística y satisfacción

### `dias_handling_vendedor` vs `dias_transito_courier` — 2,78 vs 9,31 días

Fuente: `agg_tiempo_entrega`, agregado a nivel nacional. A nivel nacional **ponderado por
orden**: **74,5 %** del tiempo total de entrega (12,5 días) es tránsito del courier, 22,2 % es
handling del vendedor y el 3,3 % restante es aprobación del pago.

**Definición.** Descomposición del tiempo de entrega en tramos con dueño distinto:
compra → aprobación (plataforma), aprobación → despacho (**vendedor**), despacho → entrega
(**courier**).

**Construcción.** Diferencias entre `fecha_compra`, `fecha_aprobacion_pago`,
`fecha_despacho_courier` y `fecha_entrega`, calculadas en `fct_pedidos`. Requiere dos columnas
del raw (`order_approved_at`, `order_delivered_carrier_date`) que este proyecto expone en staging
y que la mayoría de los proyectos sobre este dataset descarta.

`agg_tiempo_entrega` agrega estos tramos **por estado** (su grano es `estado`), no tiene una fila
nacional. El 2,78 / 9,31 de arriba sale de promediar `dias_handling_vendedor` /
`dias_transito_courier` directamente sobre `fct_pedidos` sin agrupar por estado — es decir,
ponderado por orden, cada pedido pesa lo mismo sin importar en qué estado se entregó.

**Cuidado — no confundir con el promedio simple entre estados.** Si en cambio se promedian las
27 filas de `agg_tiempo_entrega` sin ponderar (`avg(dias_transito_courier)` sobre el mart, no
sobre `fct_pedidos`), da **14,58 días** — un número **57 % más alto** y engañoso, porque le da a
un estado con 30 pedidos el mismo peso que a São Paulo con 40 mil. Usar siempre la versión
ponderada por orden para el titular; el promedio simple entre estados solo tiene sentido para
comparar la dispersión geográfica, no para reportar "el" tiempo de tránsito nacional.

**Audiencia.** COO y responsable de logística.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- **Determina a quién reclamarle.** Exigirle más a los vendedores tiene techo: aun eliminando por
  completo su handling, la entrega bajaría de 12,5 a 9,7 días. La palanca real es renegociar con
  el transportista o descentralizar la distribución.
- Un vendedor con handling muy por encima del promedio sí es un caso individual accionable.

---

### `bucket_distancia` — flete, tiempo y satisfacción por distancia

Fuente: `agg_distancia_entrega`.

| Distancia | Pedidos | Flete | Días | Atraso | Reseña |
|---|---|---|---|---|---|
| Local (<100 km) | 17.803 | R$ 13,33 | 6,4 | 6,4 % | 4,28 |
| Regional (100-500 km) | 36.967 | R$ 20,96 | 11,4 | 7,2 % | 4,18 |
| Nacional (500-1500 km) | 32.440 | R$ 25,38 | 14,8 | 8,7 % | 4,10 |
| Larga distancia (1500 km+) | 8.792 | R$ 39,95 | 20,5 | 13,1 % | 4,00 |

Las cuatro columnas se degradan de forma monótona con la distancia: el flete se triplica, los
días de entrega se triplican, el atraso se duplica y la reseña cae 0,28 puntos. **43 % de los
pedidos entregados viaja más de 500 km** (41.232 de 96.002 con distancia calculada).

**Construcción.** Distancia entre centroides de prefijo postal de cliente y vendedor con
`ST_DISTANCE`/`ST_GEOGPOINT`, calculada a nivel ÍTEM en `fct_order_items` mediante un `left join`
contra `stg_geolocation` (una vez por cliente, otra por vendedor). Es `left join` a propósito:
0,49 % de los ítems no tiene prefijo que matchee en el padrón geográfico y queda con
`distancia_km = null` en vez de desaparecer por un `inner join` silencioso. `agg_distancia_entrega`
filtra esos nulos y **colapsa a grano orden antes de agregar** —`max(distancia_km)` por
`order_id`, porque días de entrega y puntaje son atributos de la orden y no del ítem, y tomar el
ítem más lejano es el que en la práctica manda el plazo de envío—. Por eso el total de esta tabla
(96.002 órdenes) es un poco menor a `total_pedidos_entregados` (96.478): las órdenes cuyos ítems
quedaron todos sin geolocalizar no entran en ningún bucket.

**Audiencia.** COO, expansión, category management.

**Periodicidad.** Trimestral — es una métrica estructural, no operativa del día a día.

**Acciones que dispara.**
- Es el caso de negocio cuantificado para **centros de distribución regionales**: acercar oferta
  a la demanda en el tramo 500 km+ mejora flete, tiempo, atraso y satisfacción a la vez.
- Sostiene la captación de vendedores en regiones desatendidas, en vez de solo optimizar precio
  de flete con el transportista actual.

**Cuidado.** La distancia es aproximada (centroide de prefijo postal, no dirección exacta).
Sirve para comparar tramos, no para calcular fletes reales.

---

### `bucket_puntualidad` vs puntaje

Fuente: `agg_puntualidad_satisfaccion`.

**Definición.** Cuánto cae la satisfacción a medida que la entrega se atrasa respecto de lo
prometido.

**Construcción.** `fct_pedidos` entregados, clasificados por `dias_vs_promesa` (entrega real
menos estimada) en cuatro buckets: `Adelantado` (<0), `A tiempo` (=0), `Tarde (1-3 dias)` y
`Muy tarde (4+ dias)`, agrupados además por `estado`. `tasa_resenas_negativas` es
`countif(puntaje_promedio <= 2) / countif(puntaje_promedio is not null)` dentro de cada celda.

**Audiencia.** COO y atención al cliente.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Convierte un problema logístico en un número de satisfacción, que es lo que permite justificar
  inversión en logística ante finanzas. Agregado a nivel nacional (ponderado por pedido, no
  promedio simple entre estados): `Adelantado` puntúa 4,29 con 9,2 % de reseñas negativas;
  `A tiempo`, 4,03 y 12,3 %; `Tarde (1-3 días)` ya cae a 3,29 y 32,2 %; y `Muy tarde (4+ días)` se
  desploma a **1,86 y 74,7 % de reseñas negativas**. El salto grande no es entre "a tiempo" y
  "tarde" — es entre "unos días tarde" y "muy tarde": ahí es donde vale la pena poner el foco de
  comunicación proactiva.
- Define la prioridad de la comunicación proactiva: avisar de una demora antes de que el cliente
  la descubra reduce el impacto en la reseña.

---

# Parte 4 — Clientes

### `segmento_cliente`, `recencia_dias`, `frecuencia_pedidos`, `monetario_total_pagado`

Fuente: `dim_clientes`.

**Definición.** Atributos de comportamiento por cliente único: cuándo compró por última vez,
cuántas veces y cuánto gastó.

**Construcción.** Agregación de órdenes entregadas por `id_unico_cliente`. La recencia se mide
contra **la última fecha del dataset**, no contra `current_date()`, porque es un dataset histórico
congelado; usar la fecha de hoy daría recencias de años y sin sentido.

**Audiencia.** Marketing y CRM.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Segmentación para campañas: quiénes son los pocos que sí repiten y qué tienen en común.
- Base para calcular valor de vida del cliente.

**Cuidado — por qué esto NO es un RFM clásico.** No se calculan quintiles de frecuencia porque la
distribución del dataset no los admite: 90.556 clientes con 1 pedido, 2.573 con 2, 181 con 3, 47
con 4 o más. No existen cinco grupos posibles. Forzar un RFM de manual acá produciría segmentos
vacíos y conclusiones falsas; se expone R y M como continuos y la frecuencia como flag binario,
que es lo único que la data sostiene.

**Cuidado — grano de `dim_clientes` vs. `total_clientes_unicos`.** `dim_clientes` tiene 93.357
filas, una menos que `total_clientes_unicos` (93.358) en `rpt_resumen_ejecutivo`. La diferencia
es la misma orden sin registro de pago que se menciona en `gmv_total`: `fct_pedidos` la mantiene
(imputa `valor_pagado`), pero `dim_clientes` construye su base con un `inner join` contra
`int_pagos_por_orden`, así que el cliente cuya única orden es esa queda fuera de la dimensión por
completo. No afecta ninguna métrica agregada de forma material, pero explica por qué los dos
totales no cierran exacto si alguien los cruza.

---

### `tasa_retencion` por cohorte

Fuente: `fct_cohortes_retencion`.

**Definición.** De los clientes adquiridos en un mes dado, qué proporción volvió a comprar N meses
después.

**Construcción.** Cada compra ubicada respecto del mes de primera compra del cliente
(`cohorte_mes` en `dim_clientes`), dividida por el tamaño original de la cohorte.

**Audiencia.** CEO, marketing, inversores.

**Periodicidad.** Mensual, mirando la curva completa.

**Acciones que dispara.**
- **Responde si la recompra baja es real o un artefacto del corte de datos.** Es real: cohortes
  con 13-18 meses de historia observable siguen en ~0,5 % de retención al mes 1 —
  2017-02 (1.628 clientes, 18 meses observables): 0,18 %; 2017-04 (2.256, 16 meses): 0,62 %;
  2017-06 (3.037, 14 meses): 0,49 %; 2017-07 (3.752, 13 meses): 0,53 %. Cuatro cohortes con
  ventanas de observación distintas, todas en el mismo rango angosto — no es ruido de una sola
  cohorte con pocos datos.
- Si una cohorte reciente mostrara mejor retención que las viejas, indicaría que algo que se
  cambió está funcionando. Hoy no se observa esa mejora.

**Cuidado.** Leer siempre `meses_observables` junto a la celda. Si
`meses_desde_primera_compra` se acerca a ese valor, la celda está censurada por corte de datos:
un 0 % ahí significa "no hay información", no "nadie volvió".

---

# Parte 5 — Riesgo y rentabilidad

### `pct_ingresos` por tramo de concentración

Fuente: `agg_concentracion`.

**Definición.** Cuánta facturación depende de los pocos de arriba. Top 10 categorías = **62,4 %**;
top 10 % de vendedores (267 de 2.970) = **41,2 %**.

**Construcción.** Dos rankings independientes sobre `fct_order_items` (`fue_entregado`), uno por
`seller_id` y otro por `categoria`, cada uno con `row_number()` e `ingresos_globales` calculado
por `sum(sum(ingresos_productos)) over ()`. El tramo se asigna por `ranking`: `Top 10` son las 10
primeras filas siempre; `Top 1 %` y `Top 10 %` se recalculan sobre `total_entidades` (no son un
número fijo de filas). La base de vendedores es **2.970**, no los 3.095 de `dim_vendedores`: son
los que tienen al menos un ítem en una orden entregada — el resto está registrado pero nunca
vendió nada que llegara a destino.

**Audiencia.** CEO y directorio.

**Periodicidad.** Trimestral.

**Acciones que dispara.**
- Cuantifica el riesgo de dependencia: perder un puñado de vendedores del decil superior mueve la
  aguja de forma desproporcionada.
- Justifica un programa de retención de vendedores clave (que sí tiene sentido, a diferencia de la
  fidelización de compradores).
- Si la concentración crece trimestre a trimestre, el riesgo se está acumulando.

---

### `ratio_flete_precio`

Fuente: `agg_rentabilidad_flete`.

**Definición.** Qué proporción del precio del producto representa su flete, por categoría y rango
de peso facturable. A mayor valor, más erosiona el margen.

**Construcción.** `agg_rentabilidad_flete` agrupa `fct_order_items` (`fue_entregado` y
`peso_facturable_g is not null`) por `(categoria, bucket_peso)` y calcula
`sum(gastos_envio) / sum(ingresos_productos)` dentro de cada celda — nunca `avg()` de un ratio por
ítem, que pesaría igual un ítem de R$5 que uno de R$500. El peso facturable y su bucket
(`Liviano <500g` … `Muy pesado 5kg+`) vienen ya calculados en `dim_productos`, no se recalculan
acá: es el mayor entre peso real y volumétrico.

**Audiencia.** Category management y pricing.

**Periodicidad.** Trimestral.

**Acciones que dispara.**
- Identifica categorías donde conviene renegociar el flete, subir el precio, o directamente
  discontinuar porque no dejan margen.
- Define umbrales de envío gratis diferenciados por categoría en vez de uno único.

**Cuidado — unidades.** El peso volumétrico usa divisor `6.0` y no `6000`: la fórmula estándar de
couriers `largo×alto×ancho/6000` devuelve **kilos**, y acá se compara contra `peso_g` en
**gramos**. Con `/6000` el término volumétrico ganaba en 4 de 32.949 productos (o sea, el cálculo
no hacía nada); con `/6.0` gana en el 66 %, que es el comportamiento correcto.

---

### `tasa_cancelacion` y `tasa_atraso` por vendedor

Fuente: `agg_rendimiento_vendedores`.

**Definición.** Scorecard de calidad por vendedor.

**Construcción.** Combina dos granos distintos de `fct_order_items` en un solo `seller_id`: los
ingresos (`ingresos`, `precio_promedio_item`) se calculan a grano **ítem**, filtrado a
`fue_entregado`; la calidad (`dias_entrega_promedio`, `tasa_atraso`, `puntaje_promedio`) se
calcula sobre `select distinct seller_id, order_id, ...` — una fila por (vendedor, orden), no por
ítem — para que un vendedor que puso 5 ítems en la misma orden no pese 5 veces en su propio
puntaje. `total_pedidos_todos` y `tasa_cancelacion` salen de una tercera subconsulta sin filtrar
`fue_entregado`, para poder ver cancelaciones.

**Audiencia.** Equipo de gestión de vendedores.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Proceso formal de advertencia y eventual baja de vendedores con métricas malas sostenidas.
- Reconocimiento de los mejores (mejor posicionamiento en el sitio).

**Cuidado.** Filtrar por `es_significativo = true` (20+ pedidos). De 2.970 vendedores solo **804**
son significativos: sin el filtro, el ranking lo dominan vendedores con una sola venta perfecta o
un solo atraso, que no dicen nada.

Además, `total_pedidos_todos` y `tasa_cancelacion` miran **todos** los estados, no solo entregados.
Sin eso, un vendedor que cancela la mitad de sus pedidos luce idéntico a uno que no cancela.

---

### `pct_ordenes` por medio de pago

Fuente: `agg_metodos_pago`. Tarjeta de crédito **77,0 %** de las órdenes y R$ 12,1 M de volumen;
boleto 19,9 % (R$ 2,77 M); voucher 3,8 % (R$ 343 mil); débito 1,5 % (R$ 208 mil).

**Definición.** Distribución de medios de pago.

**Construcción.** Sobre `stg_payments` filtrado a órdenes entregadas (join contra
`fct_pedidos`), agrupado por `tipo_pago`: `count(distinct order_id)` para volumen de órdenes,
`sum(valor_pago)` para volumen monetario, `avg(valor_pago)` para el ticket **por transacción de
pago** (distinto del ticket por orden, porque una orden puede tener varias transacciones).
`ordenes_totales` se calcula aparte, sobre el total de `order_id` distintos, no sobre la suma de
filas — es la base de `pct_ordenes`.

**Audiencia.** Finanzas y producto.

**Periodicidad.** Mensual.

**Acciones que dispara.**
- Negociación de tarifas con procesadores según el mix real.
- El uso de cuotas (**3,5 promedio en tarjeta**) informa la política de financiación: es una
  palanca de conversión con costo financiero asociado.
- El ticket promedio por transacción varía fuerte por medio: R$ 162 en tarjeta, R$ 144 en
  boleto, apenas R$ 62 en voucher — el voucher se usa sobre todo para compras chicas o saldos
  promocionales, no como medio principal de pago.

**Cuidado.** `sum(total_pedidos)` **no** da el total de órdenes: 2.181 órdenes se pagan con más de
un medio y cuentan en varias filas. Para participación usar `pct_ordenes`. Y `promedio_cuotas`
viene en `null` salvo para tarjeta a propósito: los demás medios son siempre 1 cuota, y
promediarlos medía mix de medios de pago, no apetito de financiación.

---

# Anexo — Convenciones que evitan malinterpretar

**1. El sufijo dice qué incluye la plata.**
`*_productos` = solo mercadería, sin flete (R$ 13,22 M). `*_pagado` / `gmv_total` = lo que pagó el
cliente, mercadería + flete (R$ 15,42 M). La brecha de ~17 % es **enteramente flete**; los
intereses de cuotas son 0,02 %, despreciable. Nunca comparar una métrica de un grupo con una del
otro sin aclararlo.

**2. Casi todo filtra a órdenes entregadas.**
Las únicas excepciones son `agg_estados_pedido` y `tasa_cancelacion`, que existen justamente para
mostrar lo que las demás esconden.

**3. El prefijo del modelo dice su rol.**
`dim_` entidad · `fct_` grano transaccional con FKs · `agg_` pre-agregado para el BI · `rpt_`
tablero servido sin grano.

**4. Las tasas están siempre entre 0 y 1.**
Hay un test (`assert_tasas_entre_0_y_1`) que falla el build si alguna se sale del rango. Una tasa
mayor a 1 delata un error de grano — típicamente numerador a nivel de ítem contra denominador a
nivel de orden. Ese test existe porque ese error ya ocurrió: el on-time llegó a reportar 105,46 %.

**5. Los agregados no pueden discrepar entre sí.**
Todos los `agg_*` salen de `fct_pedidos` o `fct_order_items`, nunca de staging por separado, y
`assert_reconciliacion_ingresos` verifica en cada build que sumen exactamente lo mismo.

**6. Marcas de significancia en vez de filtros manuales.**
`es_significativo` viene calculado en los marts que lo necesitan. Poner el umbral a mano en Looker
es frágil: se pierde cuando alguien duplica el reporte.
