{{ config(materialized='table') }}

-- Mix de medios de pago por mes, sobre órdenes entregadas. Grano: (mes, tipo_pago).
-- Sumando las filas de un tipo_pago a través de los meses se obtiene el total histórico
-- de ese medio, porque cada orden pertenece a un solo mes.

with payments as (
    select * from {{ ref('stg_payments') }}
),

pedidos as (
    select
        order_id,
        mes_compra
    from {{ ref('fct_pedidos') }}
    where fue_entregado
),

pagos_entregados as (
    select
        o.mes_compra,
        p.*
    from payments as p
    inner join pedidos as o on p.order_id = o.order_id
),

-- OJO: sumar `pedidos` entre medios NO da el total de órdenes del mes, porque ~2.200
-- órdenes se pagan con más de un medio. Las participaciones se calculan contra este total.
totales_mes as (
    select
        mes_compra,
        count(distinct order_id)    as pedidos_mes,
        sum(valor_pago)             as volumen_mes
    from pagos_entregados
    group by 1
),

final as (
    select
        p.mes_compra                                                          as mes,
        p.tipo_pago,
        count(distinct p.order_id)                                            as pedidos,
        round(safe_divide(count(distinct p.order_id), any_value(t.pedidos_mes)), 4) as pct_pedidos_mes,
        count(*)                                                              as transacciones,
        round(sum(p.valor_pago), 2)                                           as volumen_pagado,
        round(safe_divide(sum(p.valor_pago), any_value(t.volumen_mes)), 4)    as pct_volumen_mes,
        round(avg(p.valor_pago), 2)                                           as valor_promedio_transaccion,
        -- las cuotas solo tienen sentido en tarjeta: boleto, débito y voucher son
        -- siempre 1 cuota, así que promediarlos mediría mix de medios, no financiación
        case when p.tipo_pago = 'credit_card' then round(avg(p.cuotas), 1) end as promedio_cuotas,
        countif(p.cuotas > 1)                                                 as transacciones_en_cuotas
    from pagos_entregados as p
    inner join totales_mes as t on p.mes_compra = t.mes_compra
    group by 1, 2
)

select * from final
order by mes, tipo_pago
