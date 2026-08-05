{{ config(materialized='table') }}

-- Distribución de TODAS las órdenes por estado terminal.
--
-- Antes se llamaba fct_embudo_pedidos, pero NO es un embudo: no hay drop-off secuencial
-- sino la foto final de órdenes históricas ya resueltas. Graficarlo como funnel invita a
-- leer una conversión que no existe. El nombre ahora dice lo que la tabla es.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

totales as (
    select count(*) as total_global from pedidos
),

final as (
    select
        p.order_status,
        count(*)                                            as total_pedidos,
        round(safe_divide(count(*), t.total_global), 4)     as pct_del_total
    from pedidos as p
    cross join totales as t
    group by 1, t.total_global
)

select * from final
