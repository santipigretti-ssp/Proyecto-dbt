{{ config(materialized='table') }}

-- Ticket promedio y financiación por estado del cliente.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

final as (
    select
        estado_cliente                        as estado,
        count(*)                              as total_pedidos,
        round(avg(valor_pagado), 2)           as ticket_promedio_pagado,
        round(avg(ingresos_productos), 2)     as ticket_promedio_productos,
        round(avg(max_cuotas), 1)             as promedio_cuotas,
        count(*) >= 100                       as es_significativo
    from pedidos
    group by 1
)

select * from final
