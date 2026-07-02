{{ config(materialized='table') }}

with items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

-- el peso facturable por los couriers es el mayor entre el peso real
-- y el peso volumétrico (formula estandar: largo*alto*ancho / 6000)
items_con_peso as (
    select
        i.monto,
        i.costo_envio,
        coalesce(p.categoria_en, 'Uncategorized') as categoria,
        greatest(
            p.peso_g,
            safe_divide(p.largo_cm * p.alto_cm * p.ancho_cm, 6000)
        ) as peso_facturable_g
    from items as i
    inner join products as p on i.product_id = p.product_id
    inner join orders as o on i.order_id = o.order_id
    where o.order_status = 'delivered'
),

bucketizado as (
    select
        categoria,
        case
            when peso_facturable_g < 500 then 'Liviano (<500g)'
            when peso_facturable_g < 2000 then 'Medio (500g-2kg)'
            when peso_facturable_g < 5000 then 'Pesado (2kg-5kg)'
            else 'Muy pesado (5kg+)'
        end as bucket_peso,
        monto,
        costo_envio
    from items_con_peso
    where peso_facturable_g is not null
),

final as (
    select
        categoria,
        bucket_peso,
        count(*)                                            as total_items,
        round(sum(monto), 2)                                as ingresos_totales,
        round(sum(costo_envio), 2)                          as gastos_envio_totales,
        round(safe_divide(sum(costo_envio), sum(monto)), 4) as ratio_flete_precio
    from bucketizado
    group by 1, 2
)

select * from final
