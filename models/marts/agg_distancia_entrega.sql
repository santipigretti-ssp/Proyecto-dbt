{{ config(materialized='table') }}

-- Distancia comprador-vendedor vs. flete, tiempo de entrega y satisfacción.
-- La distancia es aproximada: centroide del prefijo de código postal, no dirección exacta.

with items as (
    select * from {{ ref('fct_order_items') }}
    where fue_entregado and distancia_km is not null
),

-- COLAPSAMOS A GRANO ORDEN antes de agregar: días de entrega y puntaje son atributos de
-- la orden, no del ítem. Sin esto una orden de 5 ítems pesaría 5 veces, y una orden con
-- vendedores lejanos entre sí caería en más de un bucket inflando el total de pedidos.
-- Criterio: la distancia de la orden es la del ítem más lejano (el que manda el plazo).
pedidos as (
    select
        order_id,
        max(distancia_km)                as distancia_km,
        sum(gastos_envio)                as gastos_envio,
        any_value(dias_entrega_total)    as dias_entrega_total,
        any_value(entregado_a_tiempo)    as entregado_a_tiempo,
        any_value(puntaje_orden)         as puntaje
    from items
    group by order_id
),

bucketizado as (
    select
        *,
        case
            when distancia_km < 100 then 'Local (<100km)'
            when distancia_km < 500 then 'Regional (100-500km)'
            when distancia_km < 1500 then 'Nacional (500-1500km)'
            else 'Larga distancia (1500km+)'
        end as bucket_distancia
    from pedidos
),

final as (
    select
        bucket_distancia,
        count(*)                                        as total_pedidos,
        round(avg(distancia_km), 1)                     as distancia_promedio_km,
        round(avg(gastos_envio), 2)                     as costo_envio_promedio,
        round(avg(dias_entrega_total), 1)               as dias_entrega_promedio,
        round(safe_divide(countif(not entregado_a_tiempo), count(*)), 4) as tasa_atraso,
        round(avg(puntaje), 2)                          as puntaje_promedio
    from bucketizado
    group by 1
)

select * from final
