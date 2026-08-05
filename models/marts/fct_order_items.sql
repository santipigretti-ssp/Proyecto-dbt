{{ config(materialized='table') }}

-- HECHO a grano ÍTEM (una fila por order_id + order_item_id): el grano transaccional
-- más fino del negocio. Con FKs a las dimensiones (cliente, producto, vendedor, fecha),
-- esta tabla responde preguntas nuevas sin escribir un mart nuevo: "ventas por categoría
-- y mes", "atraso por vendedor y estado", etc. se resuelven en el BI con un group by.
--
-- Los agregados agg_* de esta capa salen de acá, y por eso ya no pueden discrepar entre
-- sí: hay una sola definición de ingresos, flete y distancia, calculada una sola vez.

with items as (
    select * from {{ ref('stg_order_items') }}
),

pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

productos as (
    select * from {{ ref('dim_productos') }}
),

vendedores as (
    select * from {{ ref('dim_vendedores') }}
),

geo as (
    select * from {{ ref('stg_geolocation') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        -- clave del grano
        i.order_id,
        i.order_item_id,

        -- FKs a dimensiones
        p.id_unico_cliente,
        i.product_id,
        i.seller_id,
        p.fecha_compra,
        p.mes_compra,

        -- atributos denormalizados de uso frecuente (evitan un join en el BI)
        pr.categoria,
        pr.bucket_peso,
        pr.peso_facturable_g,
        p.estado_cliente,
        v.estado                                    as estado_vendedor,
        p.order_status,
        p.fue_entregado,

        -- métricas aditivas del grano ítem
        i.monto                                     as ingresos_productos,
        i.costo_envio                               as gastos_envio,

        -- distancia comprador-vendedor de ESTE ítem (aproximada: centroide de prefijo
        -- postal, no dirección exacta)
        st_distance(
            st_geogpoint(gc.lng_promedio, gc.lat_promedio),
            st_geogpoint(gv.lng_promedio, gv.lat_promedio)
        ) / 1000                                    as distancia_km,

        -- atributos de la orden, NO aditivos a este grano: sirven para filtrar y
        -- segmentar, pero nunca para promediar sin colapsar antes a nivel orden
        p.dias_entrega_total,
        p.entregado_a_tiempo,
        p.puntaje_promedio                          as puntaje_orden
    from items as i
    inner join pedidos as p    on i.order_id = p.order_id
    inner join productos as pr on i.product_id = pr.product_id
    inner join vendedores as v on i.seller_id = v.seller_id
    inner join customers as c  on p.customer_id = c.customer_id
    left join geo as gc        on c.cp_cliente = gc.cp_prefix
    left join geo as gv        on v.cp_vendedor = gv.cp_prefix
)

select * from final
