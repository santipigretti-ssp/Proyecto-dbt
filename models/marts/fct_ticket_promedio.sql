{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

pagos_por_orden as (
    select * from {{ ref('int_pagos_por_orden') }}
),

final as (
    select
        c.estado,
        count(distinct o.order_id)          as total_pedidos,
        round(avg(p.valor_total_orden), 2)  as ticket_promedio,
        round(avg(p.max_cuotas), 1)         as promedio_cuotas
    from orders as o
    inner join customers as c on o.customer_id = c.customer_id
    inner join pagos_por_orden as p on o.order_id = p.order_id
    where o.order_status = 'delivered'
    group by 1
)

select * from final
