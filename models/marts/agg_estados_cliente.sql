{{ config(materialized='table') }}

-- Scorecard por estado del cliente: una fila por estado con todo lo comercial, logístico
-- y de satisfacción, pensada para un mapa de Brasil (iso_3166_2 = 'BR-SP' es el código que
-- reconocen Looker Studio y Tableau). Las métricas de entrega van con su conteo base para
-- que el BI pueda ponderar si agrupa por región.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

entregados as (
    select * from pedidos where fue_entregado
),

total_nacional as (
    select sum(valor_pagado) as gmv_nacional from entregados
),

comercial as (
    select
        estado_cliente                                                      as estado,
        count(*)                                                            as total_pedidos,
        count(distinct id_unico_cliente)                                    as clientes_unicos,
        round(sum(ingresos_productos), 2)                                   as ingresos_productos,
        round(sum(gastos_envio), 2)                                         as gastos_envio_totales,
        round(sum(valor_pagado), 2)                                         as gmv_total,
        round(avg(valor_pagado), 2)                                         as ticket_promedio_pagado,
        round(avg(ingresos_productos), 2)                                   as ticket_promedio_productos,
        round(avg(max_cuotas), 1)                                           as promedio_cuotas,
        round(safe_divide(sum(gastos_envio), sum(ingresos_productos)), 4)   as ratio_flete_precio,

        -- de dónde le llegan los pedidos
        round(avg(distancia_km), 0)                                         as distancia_promedio_km,
        round(safe_divide(countif(es_mismo_estado), count(*)), 4)           as pct_pedidos_mismo_estado,

        -- tiempos, con el tramo de cada responsable
        round(avg(dias_entrega_total), 1)                                   as dias_entrega_promedio,
        approx_quantiles(dias_entrega_total, 100)[offset(50)]               as dias_entrega_p50,
        approx_quantiles(dias_entrega_total, 100)[offset(90)]               as dias_entrega_p90,
        round(avg(dias_aprobacion), 2)                                      as dias_aprobacion,
        round(avg(dias_handling_vendedor), 2)                               as dias_handling_vendedor,
        round(avg(dias_transito_courier), 2)                                as dias_transito_courier,
        round(safe_divide(avg(dias_transito_courier), avg(dias_entrega_total)), 4) as pct_tiempo_courier,

        -- promesa y satisfacción
        round(safe_divide(
            countif(not entregado_a_tiempo),
            countif(entregado_a_tiempo is not null)
        ), 4)                                                               as tasa_atraso,
        round(avg(-dias_vs_promesa), 1)                                     as colchon_promesa_dias,
        countif(puntaje_promedio is not null)                               as pedidos_con_resena,
        round(avg(puntaje_promedio), 2)                                     as puntaje_promedio,
        round(safe_divide(
            countif(puntaje_promedio <= 2),
            countif(puntaje_promedio is not null)
        ), 4)                                                               as tasa_resenas_negativas
    from entregados
    group by 1
),

-- sobre TODAS las órdenes: la cancelación no existe entre las entregadas
cancelacion as (
    select
        estado_cliente                                              as estado,
        round(safe_divide(countif(fue_cancelado), count(*)), 4)     as tasa_cancelacion
    from pedidos
    group by 1
),

final as (
    select
        c.estado,
        concat('BR-', c.estado)                                     as iso_3166_2,
        {{ region_brasil('c.estado') }}                             as region,
        c.* except (estado),
        round(safe_divide(c.gmv_total, t.gmv_nacional), 4)          as pct_gmv_nacional,
        x.tasa_cancelacion,
        c.total_pedidos >= 100                                      as es_significativo
    from comercial as c
    cross join total_nacional as t
    left join cancelacion as x on c.estado = x.estado
)

select * from final
order by gmv_total desc
