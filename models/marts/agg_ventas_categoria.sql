{{ config(materialized='table') }}

-- Ranking de categorías por ingresos: la pregunta más básica de comercial, que hasta
-- ahora el proyecto no respondía (había satisfacción por categoría y flete por categoría,
-- pero no ventas por categoría). Sale directo de fct_order_items.

with items as (
    select * from {{ ref('fct_order_items') }}
    where fue_entregado
),

total as (
    select sum(ingresos_productos) as ingresos_globales from items
),

por_categoria as (
    select
        i.categoria,
        count(*)                                              as total_items,
        count(distinct i.order_id)                            as total_pedidos,
        count(distinct i.product_id)                          as productos_distintos,
        count(distinct i.seller_id)                           as vendedores_distintos,
        round(sum(i.ingresos_productos), 2)                   as ingresos_productos,
        round(sum(i.gastos_envio), 2)                         as gastos_envio_totales,
        round(avg(i.ingresos_productos), 2)                   as precio_promedio_item,
        round(safe_divide(sum(i.gastos_envio), sum(i.ingresos_productos)), 4) as ratio_flete_precio
    from items as i
    group by 1
),

final as (
    select
        c.*,
        round(safe_divide(c.ingresos_productos, t.ingresos_globales), 4) as pct_ingresos,
        -- participación acumulada ordenando de mayor a menor: sirve para leer
        -- directamente "las N categorías que explican el 80% de la facturación"
        round(sum(c.ingresos_productos) over (
            order by c.ingresos_productos desc
            rows between unbounded preceding and current row
        ) / t.ingresos_globales, 4)                                      as pct_ingresos_acumulado,
        row_number() over (order by c.ingresos_productos desc)           as ranking
    from por_categoria as c
    cross join total as t
)

select * from final
order by ranking
