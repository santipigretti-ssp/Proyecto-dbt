{{ config(materialized='table') }}

with payments as (
    select * from {{ ref('stg_payments') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

final as (
    select
        p.tipo_pago,
        count(distinct p.order_id)          as total_pedidos,
        round(sum(p.valor_pago), 2)         as volumen_total,
        round(avg(p.valor_pago), 2)         as ticket_promedio,
        round(avg(p.cuotas), 1)             as promedio_cuotas,
        countif(p.cuotas > 1)               as pedidos_en_cuotas
    from payments as p
    inner join orders as o on p.order_id = o.order_id
    where o.order_status = 'delivered'
    group by 1
)

select * from final
