{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        c.estado,
        count(distinct o.order_id)                                          as pedidos_entregados,
        round(avg(
            date_diff(date(o.fecha_entrega), date(o.fecha_compra), day)
        ), 1)                                                               as dias_entrega_promedio,
        min(
            date_diff(date(o.fecha_entrega), date(o.fecha_compra), day)
        )                                                                   as entrega_mas_rapida,
        max(
            date_diff(date(o.fecha_entrega), date(o.fecha_compra), day)
        )                                                                   as entrega_mas_lenta
    from orders as o
    inner join customers as c on o.customer_id = c.customer_id
    where o.order_status = 'delivered'
      and o.fecha_entrega is not null
    group by 1
)

select * from final
