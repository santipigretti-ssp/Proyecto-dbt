{{ config(materialized='table') }}

-- ESTIMACIÓN del ingreso de la plataforma. NO es un dato observado.
-- Olist es un marketplace: su facturación no es el GMV que circula sino la comisión
-- sobre ese GMV. El dataset no expone la comisión, así que se modela con supuestos
-- declarados en dbt_project.yml (vars), recalculables sin tocar SQL:
--     dbt run --select agg_take_rate --vars '{take_rate_comision: 0.18}'

{% set comision = var('take_rate_comision') %}
{% set tarifa_pago = var('take_rate_tarifa_pago') %}

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

mensual as (
    select
        mes_compra                          as mes,
        count(*)                            as total_pedidos,
        round(sum(valor_pagado), 2)         as gmv_total,
        round(sum(ingresos_productos), 2)   as ingresos_productos
    from pedidos
    group by 1
),

final as (
    select
        mes,
        total_pedidos,
        gmv_total,
        ingresos_productos,
        {{ comision }}                                                      as supuesto_comision,
        {{ tarifa_pago }}                                                   as supuesto_tarifa_pago,
        -- la comisión se cobra sobre la mercadería, no sobre el flete
        round(ingresos_productos * {{ comision }}, 2)                       as ingreso_comision_estimado,
        round(gmv_total * {{ tarifa_pago }}, 2)                             as costo_procesamiento_pagos,
        round(ingresos_productos * {{ comision }}
              - gmv_total * {{ tarifa_pago }}, 2)                           as margen_plataforma_estimado,
        round(safe_divide(
            ingresos_productos * {{ comision }} - gmv_total * {{ tarifa_pago }},
            gmv_total
        ), 4)                                                               as take_rate_efectivo
    from mensual
)

select * from final
order by mes
