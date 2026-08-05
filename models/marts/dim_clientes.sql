{{ config(materialized='table') }}

-- Dimensión de cliente: grano id_unico_cliente, con atributos derivados de su historia
-- de compra. Reemplaza al antiguo fct_clientes_rfm, que no era una tabla de hechos sino
-- exactamente esto: una dimensión con métricas de comportamiento.
--
-- Sobre el "RFM": no se calculan quintiles de frecuencia porque en este dataset serían
-- degenerados (90.549 clientes con 1 pedido, 2.573 con 2, 181 con 3, 47 con 4+). Con esa
-- distribución no existen 5 grupos posibles. Se exponen R y M como valores continuos y la
-- frecuencia como un flag binario, que es lo único que la data sostiene.

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

pagos as (
    select * from {{ ref('int_pagos_por_orden') }}
),

-- dataset histórico congelado (2016-2018): la recencia se mide contra la última fecha
-- observada, no contra current_date()
fecha_referencia as (
    select max(date(fecha_compra)) as fecha_max
    from orders
    where order_status = 'delivered'
),

pedidos_cliente as (
    select
        c.id_unico_cliente,
        o.order_id,
        date(o.fecha_compra)  as fecha_compra,
        p.valor_total_orden,
        c.ciudad,
        c.estado
    from orders as o
    inner join customers as c on o.customer_id = c.customer_id
    inner join pagos as p on o.order_id = p.order_id
    where o.order_status = 'delivered'
),

agregado as (
    select
        id_unico_cliente,
        -- ubicación de la compra más reciente del cliente
        array_agg(ciudad order by fecha_compra desc limit 1)[offset(0)] as ciudad,
        array_agg(estado order by fecha_compra desc limit 1)[offset(0)] as estado,
        count(distinct order_id)         as frecuencia_pedidos,
        round(sum(valor_total_orden), 2) as monetario_total_pagado,
        round(avg(valor_total_orden), 2) as ticket_promedio_pagado,
        min(fecha_compra)                as primera_compra,
        max(fecha_compra)                as ultima_compra
    from pedidos_cliente
    group by 1
),

final as (
    select
        a.*,
        date_diff((select fecha_max from fecha_referencia), a.ultima_compra, day) as recencia_dias,
        case
            when a.frecuencia_pedidos > 1 then 'Recurrente'
            else 'Único'
        end as segmento_cliente,
        -- cohorte de adquisición: mes de la primera compra. Es la clave que conecta
        -- esta dimensión con fct_cohortes_retencion.
        date_trunc(a.primera_compra, month) as cohorte_mes
    from agregado as a
)

select * from final
