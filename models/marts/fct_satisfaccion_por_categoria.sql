{{ config(materialized='table') }}

with reviews as (
    select * from {{ ref('stg_reviews') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

final as (
    select
        coalesce(p.categoria_en, 'Uncategorized')   as categoria,
        count(distinct r.review_id)                 as total_resenas,
        round(avg(r.puntaje), 2)                    as puntaje_promedio,
        countif(r.puntaje >= 4)                     as resenas_positivas,
        countif(r.puntaje <= 2)                     as resenas_negativas
    from reviews as r
    inner join items as i      on r.order_id = i.order_id
    inner join products as p   on i.product_id = p.product_id
    group by 1
)

select * from final
