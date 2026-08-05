{{ config(materialized='table') }}

-- Scorecard por vendedor. Combina el grano ítem (ingresos que le corresponden) con el
-- grano orden (puntualidad y satisfacción, que son atributos de la orden completa).

with items as (
    select * from {{ ref('fct_order_items') }}
),

vendedores as (
    select * from {{ ref('dim_vendedores') }}
),

-- ingresos: grano ítem, solo entregados
ingresos as (
    select
        seller_id,
        count(*)                            as total_items,
        count(distinct order_id)            as total_pedidos,
        round(sum(ingresos_productos), 2)   as ingresos_productos,
        round(avg(ingresos_productos), 2)   as precio_promedio_item
    from items
    where fue_entregado
    group by 1
),

-- puntualidad y satisfacción: una fila por (vendedor, orden) para no ponderar por ítems
vendedor_orden as (
    select distinct
        seller_id,
        order_id,
        entregado_a_tiempo,
        dias_entrega_total,
        puntaje_orden
    from items
    where fue_entregado
),

calidad as (
    select
        seller_id,
        round(avg(dias_entrega_total), 1)                                  as dias_entrega_promedio,
        round(safe_divide(countif(not entregado_a_tiempo), count(*)), 4)   as tasa_atraso,
        round(avg(puntaje_orden), 2)                                       as puntaje_promedio
    from vendedor_orden
    group by 1
),

-- sin filtrar por estado: sin esto, un vendedor que cancela la mitad de sus pedidos
-- luce idéntico a uno que no cancela
cancelaciones as (
    select
        seller_id,
        count(distinct order_id) as total_pedidos_todos,
        round(safe_divide(
            count(distinct if(order_status in ('canceled', 'unavailable'), order_id, null)),
            count(distinct order_id)
        ), 4) as tasa_cancelacion
    from items
    group by 1
),

final as (
    select
        v.seller_id,
        v.ciudad,
        v.estado,
        i.total_pedidos,
        i.ingresos_productos,
        i.precio_promedio_item,
        q.dias_entrega_promedio,
        q.tasa_atraso,
        q.puntaje_promedio,
        c.total_pedidos_todos,
        c.tasa_cancelacion,
        i.total_pedidos >= 20 as es_significativo
    from ingresos as i
    inner join vendedores as v   on i.seller_id = v.seller_id
    left join calidad as q       on i.seller_id = q.seller_id
    left join cancelaciones as c on i.seller_id = c.seller_id
)

select * from final
