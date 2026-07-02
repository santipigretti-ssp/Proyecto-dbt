{{ config(materialized='table') }}

with sellers as (
    select * from {{ ref('stg_sellers') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

reviews as (
    select * from {{ ref('stg_reviews') }}
),

items_entregados as (
    select
        i.seller_id,
        i.order_id,
        i.monto,
        o.fecha_compra,
        o.fecha_entrega,
        o.fecha_estimada_entrega
    from items as i
    inner join orders as o on i.order_id = o.order_id
    where o.order_status = 'delivered'
      and o.fecha_entrega is not null
),

-- un mismo order_id puede tener mas de una reseña; promediamos a nivel de orden
-- antes de llevarlo a nivel de vendedor
puntaje_por_orden as (
    select
        order_id,
        avg(puntaje) as puntaje_promedio_orden
    from reviews
    group by order_id
),

final as (
    select
        s.seller_id,
        s.ciudad,
        s.estado,
        count(distinct io.order_id)                                                   as total_pedidos,
        round(sum(io.monto), 2)                                                       as ingresos_totales,
        round(avg(io.monto), 2)                                                       as ticket_promedio,
        round(avg(date_diff(date(io.fecha_entrega), date(io.fecha_compra), day)), 1)  as dias_entrega_promedio,
        round(safe_divide(
            countif(io.fecha_entrega > io.fecha_estimada_entrega),
            count(*)
        ), 4)                                                                         as tasa_atraso,
        round(avg(p.puntaje_promedio_orden), 2)                                       as puntaje_promedio
    from items_entregados as io
    inner join sellers as s on io.seller_id = s.seller_id
    left join puntaje_por_orden as p on io.order_id = p.order_id
    group by 1, 2, 3
)

select * from final
