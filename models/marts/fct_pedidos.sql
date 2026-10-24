{{ config(materialized='table') }}

-- HECHO a grano ORDEN (una fila por order_id, TODOS los estados).
-- Acá viven las métricas que son atributos de la orden y no del ítem: puntualidad,
-- tiempos de entrega, puntaje de reseña, valor pagado, distancia. Tenerlas en su propio
-- grano evita el error clásico de este dataset: promediar días de entrega sobre un join
-- con order_items, donde una orden de 5 ítems pesa 5 veces.

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

sellers as (
    select * from {{ ref('stg_sellers') }}
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

items_geo as (
    select * from {{ ref('int_items_geo') }}
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
        i.order_id,
        count(*)                      as cantidad_items,
        count(distinct i.seller_id)   as cantidad_vendedores,
        round(sum(i.monto), 2)        as ingresos_productos,
        round(sum(i.costo_envio), 2)  as gastos_envio,
        -- la distancia de la orden es la del ítem más lejano: es el que manda el plazo
        max(g.distancia_km)           as distancia_km,
        -- vendedor principal: el del ítem de mayor precio (el 98,7% de las órdenes tiene
        -- un solo vendedor, así que el desempate casi nunca importa)
        array_agg(i.seller_id order by i.monto desc, i.order_item_id asc limit 1)[offset(0)]
            as seller_id_principal
    from items as i
    left join items_geo as g
        on i.order_id = g.order_id and i.order_item_id = g.order_item_id
    group by i.order_id
),

base as (
    select
        o.order_id,
        c.customer_id,
        c.id_unico_cliente,
        c.estado                                    as estado_cliente,
        c.ciudad                                    as ciudad_cliente,
        i.seller_id_principal,
        s.estado                                    as estado_vendedor,
        c.estado = s.estado                         as es_mismo_estado,
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
        -- Hay exactamente 1 orden entregada sin registro de pago (bfbd0f9b..., 2016-09-15),
        -- y es la única orden de su mes: sin imputar, el GMV de 2016-09 queda en null. Se
        -- imputa con mercadería + flete, que en las 96.477 órdenes restantes difiere de
        -- payment_value en apenas 0,02%. valor_pagado_imputado lo deja explícito.
        coalesce(
            p.valor_total_orden,
            i.ingresos_productos + i.gastos_envio
        )                                           as valor_pagado,
        (
            p.valor_total_orden is null
            and i.ingresos_productos is not null
        )                                           as valor_pagado_imputado,
        p.max_cuotas,
        i.distancia_km,

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
    left join sellers as s           on i.seller_id_principal = s.seller_id
    left join pagos as p             on o.order_id = p.order_id
    left join puntaje_por_orden as r on o.order_id = r.order_id
),

-- segmentos precalculados: los usan varios agregados y el BI agrupa por ellos sin
-- tener que repetir los cortes
final as (
    select
        *,
        case
            when distancia_km is null then null
            when distancia_km < 100 then 'Local (<100km)'
            when distancia_km < 500 then 'Regional (100-500km)'
            when distancia_km < 1500 then 'Nacional (500-1500km)'
            else 'Larga distancia (1500km+)'
        end as bucket_distancia,
        case
            when dias_vs_promesa is null then null
            when dias_vs_promesa < 0 then 'Adelantado'
            when dias_vs_promesa = 0 then 'A tiempo'
            when dias_vs_promesa <= 3 then 'Tarde (1-3 dias)'
            else 'Muy tarde (4+ dias)'
        end as bucket_puntualidad
    from base
)

select * from final
