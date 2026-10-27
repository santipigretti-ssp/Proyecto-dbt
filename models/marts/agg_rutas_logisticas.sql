{{ config(materialized='table') }}

-- Matriz origen → destino: estado del vendedor × estado del cliente, sobre órdenes
-- entregadas. Pensada para un heatmap: muestra qué rutas concentran el volumen y en
-- cuáles se disparan el flete, la demora y el atraso. Es la versión accionable del
-- hallazgo "la distancia degrada todo": dice exactamente qué corredores atacar.
--
-- El origen de una orden es el estado de su vendedor principal (ver fct_pedidos).

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado and estado_vendedor is not null
),

total as (
    select count(*) as pedidos_globales from pedidos
),

final as (
    select
        p.estado_vendedor                                                       as estado_origen,
        p.estado_cliente                                                        as estado_destino,
        {{ region_brasil('p.estado_vendedor') }}                                as region_origen,
        {{ region_brasil('p.estado_cliente') }}                                 as region_destino,
        p.estado_vendedor = p.estado_cliente                                    as es_mismo_estado,
        count(*)                                                                as total_pedidos,
        round(safe_divide(count(*), any_value(t.pedidos_globales)), 4)          as pct_pedidos,
        round(sum(p.ingresos_productos), 2)                                     as ingresos_productos,
        round(sum(p.gastos_envio), 2)                                           as gastos_envio_totales,
        round(avg(p.gastos_envio), 2)                                           as costo_envio_promedio,
        round(safe_divide(sum(p.gastos_envio), sum(p.ingresos_productos)), 4)   as ratio_flete_precio,
        round(avg(p.distancia_km), 0)                                           as distancia_promedio_km,
        round(avg(p.dias_entrega_total), 1)                                     as dias_entrega_promedio,
        round(avg(p.dias_handling_vendedor), 2)                                 as dias_handling_vendedor,
        round(avg(p.dias_transito_courier), 2)                                  as dias_transito_courier,
        round(safe_divide(
            countif(not p.entregado_a_tiempo),
            countif(p.entregado_a_tiempo is not null)
        ), 4)                                                                   as tasa_atraso,
        round(avg(p.puntaje_promedio), 2)                                       as puntaje_promedio,
        count(*) >= 50                                                          as es_significativo
    from pedidos as p
    cross join total as t
    group by 1, 2
)

select * from final
order by total_pedidos desc
