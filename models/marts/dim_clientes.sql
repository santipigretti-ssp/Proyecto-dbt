{{ config(materialized='table') }}

-- Dimensión de cliente: grano id_unico_cliente, TODOS los clientes (también los que nunca
-- recibieron una orden), para que fct_pedidos.id_unico_cliente tenga siempre a dónde
-- apuntar. Los atributos de comportamiento se calculan solo sobre órdenes entregadas y
-- salen de fct_pedidos, así que valor_pagado tiene la misma definición que en el resto.
--
-- Sobre el "RFM": no se calculan quintiles de frecuencia porque en este dataset serían
-- degenerados (90.549 clientes con 1 pedido, 2.573 con 2, 181 con 3, 47 con 4+). Se
-- exponen R y M como valores continuos y la frecuencia como segmento, que es lo único
-- que la data sostiene.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

-- dataset histórico congelado (2016-2018): la recencia se mide contra la última fecha
-- observada, no contra current_date()
fecha_referencia as (
    select max(fecha_compra) as fecha_max
    from pedidos
    where fue_entregado
),

agregado as (
    select
        id_unico_cliente,
        -- ubicación de la compra más reciente del cliente
        array_agg(ciudad_cliente order by fecha_compra desc, order_id asc limit 1)[offset(0)] as ciudad,
        array_agg(estado_cliente order by fecha_compra desc, order_id asc limit 1)[offset(0)] as estado,
        count(*)                                                   as pedidos_totales,
        countif(fue_entregado)                                     as frecuencia_pedidos,
        round(coalesce(sum(if(fue_entregado, valor_pagado, null)), 0), 2) as monetario_total_pagado,
        round(avg(if(fue_entregado, valor_pagado, null)), 2)       as ticket_promedio_pagado,
        min(if(fue_entregado, fecha_compra, null))                 as primera_compra,
        max(if(fue_entregado, fecha_compra, null))                 as ultima_compra
    from pedidos
    group by 1
),

final as (
    select
        a.*,
        a.frecuencia_pedidos > 0 as tiene_compra_entregada,
        date_diff((select fr.fecha_max from fecha_referencia as fr), a.ultima_compra, day) as recencia_dias,
        case
            when a.frecuencia_pedidos > 1 then 'Recurrente'
            when a.frecuencia_pedidos = 1 then 'Único'
            else 'Sin entregas'
        end as segmento_cliente,
        -- cohorte de adquisición: mes de la primera compra entregada. Es la clave que
        -- conecta esta dimensión con agg_cohortes_retencion.
        date_trunc(a.primera_compra, month) as cohorte_mes
    from agregado as a
)

select * from final
