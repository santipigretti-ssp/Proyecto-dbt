{{ config(materialized='table') }}

with payments as (
    select * from {{ ref('stg_payments') }}
),

pedidos as (
    select order_id from {{ ref('fct_pedidos') }} where fue_entregado
),

pagos_entregados as (
    select p.*
    from payments as p
    inner join pedidos as o on p.order_id = o.order_id
),

-- OJO: sum(total_pedidos) NO da el total de órdenes, porque 2.181 órdenes se pagan con
-- más de un medio y cuentan en varias filas. pct_ordenes se calcula contra este total.
total_ordenes as (
    select count(distinct order_id) as ordenes_totales from pagos_entregados
),

final as (
    select
        p.tipo_pago,
        count(distinct p.order_id)                                            as total_pedidos,
        round(safe_divide(count(distinct p.order_id), t.ordenes_totales), 4)  as pct_ordenes,
        round(sum(p.valor_pago), 2)                                           as volumen_pagado,
        round(avg(p.valor_pago), 2)                                           as valor_promedio_transaccion,
        -- las cuotas solo tienen sentido en tarjeta: boleto, débito y voucher son
        -- siempre 1 cuota, así que promediarlos medía mix de medios, no financiación
        case when p.tipo_pago = 'credit_card' then round(avg(p.cuotas), 1) end as promedio_cuotas,
        countif(p.cuotas > 1)                                                 as pedidos_en_cuotas
    from pagos_entregados as p
    cross join total_ordenes as t
    group by p.tipo_pago, t.ordenes_totales
)

select * from final
