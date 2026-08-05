{{ config(materialized='table') }}

-- Satisfacción por categoría de producto, sobre órdenes entregadas.
--
-- Grano de cálculo: (orden, categoría) DISTINTO. Una orden con 3 ítems de la misma
-- categoría aporta su puntaje una sola vez; si tiene ítems de 2 categorías, aporta a
-- ambas (limitación real del dataset: la reseña es de la orden, no del producto).
-- Sin ese distinct el promedio quedaba ponderado por cantidad de ítems.

with items as (
    select distinct order_id, categoria
    from {{ ref('fct_order_items') }}
    where fue_entregado
),

pedidos as (
    select order_id, puntaje_promedio
    from {{ ref('fct_pedidos') }}
    where fue_entregado and puntaje_promedio is not null
),

orden_categoria as (
    select
        i.categoria,
        i.order_id,
        p.puntaje_promedio
    from items as i
    inner join pedidos as p on i.order_id = p.order_id
),

final as (
    select
        categoria,
        count(*)                            as total_resenas,
        round(avg(puntaje_promedio), 2)     as puntaje_promedio,
        countif(puntaje_promedio >= 4)      as resenas_positivas,
        countif(puntaje_promedio <= 2)      as resenas_negativas,
        count(*) >= 100                     as es_significativo
    from orden_categoria
    group by 1
)

select * from final
