{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

final as (
    select
        c.ciudad,
        c.estado,
        count(distinct o.order_id) as total_pedidos,
        sum(i.monto) as ingresos_totales,
        sum(i.costo_envio) as gastos_envio_totales
    from orders as o
    inner join customers as c on o.customer_id = c.customer_id
    inner join items as i on o.order_id = i.order_id
    group by 1, 2
)

select * from final

