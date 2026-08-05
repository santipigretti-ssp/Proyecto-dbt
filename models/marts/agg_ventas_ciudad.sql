{{ config(materialized='table') }}

-- Rendimiento económico por ubicación del cliente. Agregado desde fct_pedidos.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

final as (
    select
        ciudad_cliente                        as ciudad,
        estado_cliente                        as estado,
        count(*)                              as total_pedidos,
        round(sum(ingresos_productos), 2)     as ingresos_productos,
        round(sum(gastos_envio), 2)           as gastos_envio_totales,
        round(sum(valor_pagado), 2)           as gmv_total,
        count(*) >= 100                       as es_significativo
    from pedidos
    group by 1, 2
)

select * from final
