{{ config(materialized='table') }}

-- Evolución mensual con variación MoM/YoY. El nivel solo no dice si el negocio crece.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

mensual as (
    select
        mes_compra                              as mes,
        count(*)                                as total_pedidos,
        count(distinct id_unico_cliente)        as clientes_unicos,
        round(sum(ingresos_productos), 2)       as ingresos_productos,
        round(sum(gastos_envio), 2)             as gastos_envio_totales,
        round(sum(valor_pagado), 2)             as gmv_total,
        round(avg(ingresos_productos), 2)       as ticket_promedio_productos
    from pedidos
    group by 1
),

-- Comparamos por FECHA CALENDARIO (self-join), no por "N filas atrás" (lag). El
-- dataset tiene un hueco real: no hay ni un pedido en 2016-11, así que esa fila no
-- existe en `mensual`. Con lag(x, 12) esto corre el punto de comparación un mes
-- entero sin avisar (ej. 2017-11 terminaba comparado contra 2016-10, no 2016-11).
-- El self-join simplemente no encuentra fila para un mes inexistente y da NULL,
-- que es la respuesta correcta.
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

con_variacion as (
    select
        mes,
        total_pedidos,
        clientes_unicos,
        ingresos_productos,
        gastos_envio_totales,
        gmv_total,
        ticket_promedio_productos,

        -- MoM/YoY quedan en NULL (no en un número gigante) cuando el mes actual o el
        -- de comparación tienen menos de 100 pedidos. Sep-dic 2016 son la fase piloto
        -- de la plataforma (1, 265, 0, 1 pedidos): dividir por esas bases produce
        -- variaciones de cientos de miles de % que no describen nada del negocio, solo
        -- ruido de una base casi cero. Un NULL no dibuja barra en el BI, así que el
        -- gráfico de tendencia queda limpio sin depender de que alguien recuerde
        -- filtrar. Los NIVELES (total_pedidos, ingresos_productos) de esos meses SÍ se
        -- conservan sin tocar: muestran el arranque real de la plataforma desde cero.
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
        mes in ((select min(mes) from mensual), (select max(mes) from mensual)) as es_mes_parcial
    from con_comparacion
)

select * from con_variacion
order by mes
