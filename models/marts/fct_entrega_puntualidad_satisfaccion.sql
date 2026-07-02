{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

reviews as (
    select * from {{ ref('stg_reviews') }}
),

pedidos_con_diferencia as (
    select
        o.order_id,
        c.estado,
        date_diff(date(o.fecha_entrega), date(o.fecha_estimada_entrega), day) as dias_diferencia
    from orders as o
    inner join customers as c on o.customer_id = c.customer_id
    where o.order_status = 'delivered'
      and o.fecha_entrega is not null
      and o.fecha_estimada_entrega is not null
),

bucketizado as (
    select
        p.estado,
        case
            when p.dias_diferencia < 0 then 'Adelantado'
            when p.dias_diferencia = 0 then 'A tiempo'
            when p.dias_diferencia between 1 and 3 then 'Tarde (1-3 dias)'
            else 'Muy tarde (4+ dias)'
        end as bucket_puntualidad,
        p.order_id,
        r.puntaje
    from pedidos_con_diferencia as p
    left join reviews as r on p.order_id = r.order_id
),

final as (
    select
        estado,
        bucket_puntualidad,
        count(distinct order_id)                                       as total_pedidos,
        round(avg(puntaje), 2)                                         as puntaje_promedio,
        round(safe_divide(countif(puntaje <= 2), count(puntaje)), 4)   as tasa_resenas_negativas
    from bucketizado
    group by 1, 2
)

select * from final
