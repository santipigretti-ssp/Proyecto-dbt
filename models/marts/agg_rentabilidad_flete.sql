{{ config(materialized='table') }}

-- Cuánto erosiona el flete a los ingresos según categoría y peso facturable.
-- El peso facturable ya viene calculado (y con las unidades correctas) en dim_productos.

with items as (
    select * from {{ ref('fct_order_items') }}
    where fue_entregado and peso_facturable_g is not null
),

final as (
    select
        categoria,
        bucket_peso,
        count(*)                                                            as total_items,
        round(sum(ingresos_productos), 2)                                   as ingresos_productos,
        round(sum(gastos_envio), 2)                                         as gastos_envio_totales,
        round(safe_divide(sum(gastos_envio), sum(ingresos_productos)), 4)   as ratio_flete_precio,
        round(avg(peso_facturable_g), 0)                                    as peso_facturable_promedio_g
    from items
    group by 1, 2
)

select * from final
