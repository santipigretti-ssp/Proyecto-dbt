{{ config(materialized='table') }}

-- Tiempos de entrega por estado, descompuestos por responsable del tramo.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado and fecha_entrega is not null
),

final as (
    select
        estado_cliente                                    as estado,
        count(*)                                          as pedidos_entregados,
        round(avg(dias_entrega_total), 1)                 as dias_entrega_promedio,
        approx_quantiles(dias_entrega_total, 100)[offset(50)] as dias_entrega_p50,
        approx_quantiles(dias_entrega_total, 100)[offset(90)] as dias_entrega_p90,
        round(avg(dias_aprobacion), 2)                    as dias_aprobacion_promedio,
        round(avg(dias_handling_vendedor), 2)             as dias_handling_vendedor,
        round(avg(dias_transito_courier), 2)              as dias_transito_courier,
        round(safe_divide(avg(dias_transito_courier), avg(dias_entrega_total)), 4) as pct_tiempo_courier,
        count(*) >= 100                                   as es_significativo
    from pedidos
    group by 1
)

select * from final
