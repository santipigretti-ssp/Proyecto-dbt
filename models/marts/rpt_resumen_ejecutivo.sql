{{ config(materialized='table') }}

-- REPORTE de una sola fila con los KPIs de cabecera del dashboard.
-- Prefijo rpt_ y no fct_ porque no es una tabla de hechos: no tiene grano (es 1 fila) ni
-- claves foráneas, es un tablero servido.
--
-- Cada métrica se calcula en su propio grano y recién al final se combinan con cross join.
-- Calcularlas todas sobre un único join de órdenes + ítems inflaría las métricas de orden
-- (on-time, puntaje) por el fan-out: una orden de 3 ítems contaría 3 veces.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

clientes as (
    select * from {{ ref('dim_clientes') }}
),

entregados as (
    select * from pedidos where fue_entregado
),

-- grano: orden entregada
metricas_pedidos as (
    select
        min(fecha_compra)                          as fecha_inicio,
        max(fecha_compra)                          as fecha_fin,
        count(*)                                   as total_pedidos_entregados,
        count(distinct id_unico_cliente)           as total_clientes_unicos,
        round(sum(ingresos_productos), 2)          as ingresos_productos,
        round(sum(gastos_envio), 2)                as gastos_envio_totales,
        round(sum(valor_pagado), 2)                as gmv_total,
        round(safe_divide(sum(ingresos_productos), count(*)), 2) as ticket_promedio_productos,
        round(safe_divide(sum(valor_pagado), count(*)), 2)       as ticket_promedio_pagado,
        round(safe_divide(
            countif(entregado_a_tiempo),
            countif(fecha_entrega is not null and fecha_estimada_entrega is not null)
        ), 4)                                      as tasa_entrega_a_tiempo,
        approx_quantiles(dias_entrega_total, 100)[offset(90)] as dias_entrega_p90,
        -- días que la promesa le da de más al cliente respecto de la entrega real. Un
        -- colchón grande explica un on-time alto sin que eso signifique entregar rápido.
        round(avg(date_diff(
            date(fecha_estimada_entrega), date(fecha_entrega), day
        )), 1)                                     as colchon_promesa_dias,
        round(avg(puntaje_promedio), 2)            as puntaje_promedio_resenas
    from entregados
),

-- versión sin sesgo de supervivencia: sobre todas las órdenes que debían llegar al
-- cliente, incluidas las canceladas y las que quedaron en tránsito
metricas_ontime_global as (
    select round(safe_divide(
        countif(entregado_a_tiempo),
        count(*)
    ), 4) as tasa_entrega_a_tiempo_global
    from pedidos
    where order_status not in ('created', 'approved', 'invoiced', 'processing')
),

-- grano: cliente único
metricas_clientes as (
    select round(safe_divide(
        countif(segmento_cliente = 'Recurrente'),
        count(*)
    ), 4) as tasa_clientes_recurrentes
    from clientes
),

-- grano: orden, sobre TODAS las órdenes
metricas_cancelacion as (
    select round(safe_divide(countif(fue_cancelado), count(*)), 4) as tasa_cancelacion
    from pedidos
),

final as (
    select
        p.*,
        og.tasa_entrega_a_tiempo_global,
        c.tasa_clientes_recurrentes,
        x.tasa_cancelacion
    from metricas_pedidos as p
    cross join metricas_ontime_global as og
    cross join metricas_clientes as c
    cross join metricas_cancelacion as x
)

select * from final
