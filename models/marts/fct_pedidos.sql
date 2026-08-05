{{ config(materialized='table') }}

-- HECHO a grano ORDEN (una fila por order_id, TODOS los estados).
-- Acá viven las métricas que son atributos de la orden y no del ítem: puntualidad,
-- tiempos de entrega, puntaje de reseña, valor pagado. Tenerlas en su propio grano es
-- lo que evita el error clásico de este dataset: promediar días de entrega sobre un
-- join con order_items, donde una orden de 5 ítems pesa 5 veces.

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

pagos as (
    select * from {{ ref('int_pagos_por_orden') }}
),

reviews as (
    select * from {{ ref('stg_reviews') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

-- una orden puede tener varias reseñas (547 casos): colapsamos antes de unir
puntaje_por_orden as (
    select
        order_id,
        avg(puntaje)                as puntaje_promedio,
        count(distinct review_id)   as cantidad_resenas
    from reviews
    group by order_id
),

-- métricas de ítems resumidas a nivel orden
items_por_orden as (
    select
        order_id,
        count(*)                      as cantidad_items,
        count(distinct seller_id)     as cantidad_vendedores,
        round(sum(monto), 2)          as ingresos_productos,
        round(sum(costo_envio), 2)    as gastos_envio
    from items
    group by order_id
),

final as (
    select
        o.order_id,
        c.customer_id,
        c.id_unico_cliente,
        c.estado                                    as estado_cliente,
        c.ciudad                                    as ciudad_cliente,
        o.order_status,
        date(o.fecha_compra)                        as fecha_compra,
        date_trunc(date(o.fecha_compra), month)     as mes_compra,
        o.fecha_aprobacion_pago,
        o.fecha_despacho_courier,
        o.fecha_entrega,
        o.fecha_estimada_entrega,

        i.cantidad_items,
        i.cantidad_vendedores,
        i.ingresos_productos,
        i.gastos_envio,
        -- Hay exactamente 1 orden entregada en todo el dataset sin registro de pago
        -- (bfbd0f9b..., 2016-09-15), y es la única orden de su mes, así que sin imputar
        -- deja el GMV de 2016-09 en null. Se imputa con mercadería + flete, que es una
        -- aproximación sólida: en las 96.477 órdenes restantes payment_value difiere de
        -- esa suma en apenas 0,02%. La columna valor_pagado_imputado lo deja explícito
        -- para que nadie tome el dato como observado.
        coalesce(
            p.valor_total_orden,
            i.ingresos_productos + i.gastos_envio
        )                                           as valor_pagado,
        p.valor_total_orden is null
            and i.ingresos_productos is not null    as valor_pagado_imputado,
        p.max_cuotas,

        -- tramos de tiempo, cada uno con su responsable
        timestamp_diff(o.fecha_aprobacion_pago, o.fecha_compra, hour) / 24.0            as dias_aprobacion,
        timestamp_diff(o.fecha_despacho_courier, o.fecha_aprobacion_pago, hour) / 24.0  as dias_handling_vendedor,
        timestamp_diff(o.fecha_entrega, o.fecha_despacho_courier, hour) / 24.0          as dias_transito_courier,
        date_diff(date(o.fecha_entrega), date(o.fecha_compra), day)                     as dias_entrega_total,

        date_diff(date(o.fecha_entrega), date(o.fecha_estimada_entrega), day)           as dias_vs_promesa,
        o.fecha_entrega <= o.fecha_estimada_entrega                                     as entregado_a_tiempo,
        o.order_status = 'delivered'                                                    as fue_entregado,
        o.order_status in ('canceled', 'unavailable')                                   as fue_cancelado,

        r.puntaje_promedio,
        r.cantidad_resenas
    from orders as o
    inner join customers as c        on o.customer_id = c.customer_id
    left join items_por_orden as i   on o.order_id = i.order_id
    left join pagos as p             on o.order_id = p.order_id
    left join puntaje_por_orden as r on o.order_id = r.order_id
)

select * from final
