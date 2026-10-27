{{ config(materialized='table') }}

-- Evolución comercial mensual con variación MoM/YoY. El nivel solo no dice si el
-- negocio crece: la curva de ingresos sube hasta el final mientras la variación muestra
-- que el crecimiento se frenó desde 2018-03.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

clientes as (
    select
        id_unico_cliente,
        cohorte_mes
    from {{ ref('dim_clientes') }}
),

mensual as (
    select
        p.mes_compra                                                    as mes,
        count(*)                                                        as total_pedidos,
        count(distinct p.id_unico_cliente)                              as clientes_unicos,
        -- cliente nuevo = primera compra entregada en este mes
        count(distinct if(p.mes_compra = c.cohorte_mes, p.id_unico_cliente, null)) as clientes_nuevos,
        round(sum(p.ingresos_productos), 2)                             as ingresos_productos,
        round(sum(p.gastos_envio), 2)                                   as gastos_envio_totales,
        round(sum(p.valor_pagado), 2)                                   as gmv_total,
        round(avg(p.ingresos_productos), 2)                             as ticket_promedio_productos,
        round(avg(p.valor_pagado), 2)                                   as ticket_promedio_pagado
    from pedidos as p
    inner join clientes as c on p.id_unico_cliente = c.id_unico_cliente
    group by 1
),

-- Comparamos por FECHA CALENDARIO (self-join), no por "N filas atrás" (lag). El
-- dataset tiene un hueco real: no hay ni un pedido entregado en 2016-11, así que esa
-- fila no existe en `mensual`. Con lag(x, 12), 2017-11 terminaría comparado contra
-- 2016-10. El self-join no encuentra fila para un mes inexistente y da NULL, que es la
-- respuesta correcta.
con_comparacion as (
    select
        a.*,
        m1.total_pedidos        as pedidos_mes_anterior,
        m1.ingresos_productos   as ingresos_mes_anterior,
        m12.total_pedidos       as pedidos_mismo_mes_anio_anterior,
        m12.ingresos_productos  as ingresos_mismo_mes_anio_anterior
    from mensual as a
    left join mensual as m1  on m1.mes  = date_sub(a.mes, interval 1 month)
    left join mensual as m12 on m12.mes = date_sub(a.mes, interval 12 month)
),

final as (
    select
        mes,
        total_pedidos,
        clientes_unicos,
        clientes_nuevos,
        ingresos_productos,
        gastos_envio_totales,
        gmv_total,
        ticket_promedio_productos,
        ticket_promedio_pagado,

        -- MoM/YoY quedan en NULL cuando el mes actual o el de comparación tienen menos de
        -- 100 pedidos. Sep-dic 2016 es la fase piloto (1, 265, 0, 1 pedidos): dividir por
        -- esas bases produce variaciones de cientos de miles de % que son ruido. Un NULL no
        -- dibuja barra en el BI. Los NIVELES de esos meses sí se conservan.
        case
            when total_pedidos >= 100 and pedidos_mes_anterior >= 100
                then round(safe_divide(
                    ingresos_productos - ingresos_mes_anterior,
                    ingresos_mes_anterior
                ), 4)
        end as ingresos_mom_pct,

        case
            when total_pedidos >= 100 and pedidos_mes_anterior >= 100
                then round(safe_divide(
                    total_pedidos - pedidos_mes_anterior,
                    pedidos_mes_anterior
                ), 4)
        end as pedidos_mom_pct,

        case
            when total_pedidos >= 100 and pedidos_mismo_mes_anio_anterior >= 100
                then round(safe_divide(
                    ingresos_productos - ingresos_mismo_mes_anio_anterior,
                    ingresos_mismo_mes_anio_anterior
                ), 4)
        end as ingresos_yoy_pct,

        -- primer y último mes están truncados por corte del dataset: marcarlos evita
        -- mostrar una "caída" que es artefacto y no negocio
        mes in ((select min(m.mes) from mensual as m), (select max(m.mes) from mensual as m)) as es_mes_parcial
    from con_comparacion
)

select * from final
order by mes
