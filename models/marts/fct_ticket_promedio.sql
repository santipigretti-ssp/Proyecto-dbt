{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

payments as (
    select * from {{ ref('stg_payments') }}
),

-- one row per order: sum all payments (an order can have multiple payment methods)
pagos_por_orden as (
    select
        order_id,
        sum(valor_pago)  as valor_total_orden,
        max(cuotas)      as max_cuotas
    from payments
    group by order_id
),

final as (
    select
        c.estado,
        count(distinct o.order_id)          as total_pedidos,
        round(avg(p.valor_total_orden), 2)  as ticket_promedio,
        round(avg(p.max_cuotas), 1)         as promedio_cuotas
    from orders o
    join customers c  on o.customer_id = c.customer_id
    join pagos_por_orden p on o.order_id = p.order_id
    where o.order_status = 'delivered'
    group by 1
)

select * from final
