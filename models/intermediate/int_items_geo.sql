-- Distancia comprador-vendedor de cada ítem. Vive en intermediate porque la usan dos
-- hechos de distinto grano: fct_order_items (por ítem) y fct_pedidos (máximo por orden),
-- y fct_order_items ya depende de fct_pedidos.
--
-- Es aproximada: centroide del prefijo postal, no dirección exacta. Los joins geo son
-- LEFT a propósito: el 0,49% de los ítems no tiene su prefijo en el padrón y queda con
-- distancia null en vez de desaparecer.

with items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

sellers as (
    select * from {{ ref('stg_sellers') }}
),

geo as (
    select * from {{ ref('stg_geolocation') }}
),

final as (
    select
        i.order_id,
        i.order_item_id,
        st_distance(
            st_geogpoint(gc.lng_promedio, gc.lat_promedio),
            st_geogpoint(gv.lng_promedio, gv.lat_promedio)
        ) / 1000 as distancia_km
    from items as i
    inner join orders as o    on i.order_id = o.order_id
    inner join customers as c on o.customer_id = c.customer_id
    inner join sellers as s   on i.seller_id = s.seller_id
    left join geo as gc       on c.cp_cliente = gc.cp_prefix
    left join geo as gv       on s.cp_vendedor = gv.cp_prefix
)

select * from final
