{{ config(materialized='table') }}

-- Scorecard por categoría de producto: cuánto vende, cuánto pesa el flete, qué tan bien
-- se entrega, qué tan satisfecho queda el cliente y si está creciendo. Una fila por
-- categoría, pensada para un scatter (ingresos vs. puntaje) y un pareto
-- (pct_ingresos_acumulado).
--
-- Ventas y flete se calculan a grano ítem. Entrega y satisfacción son atributos de la
-- orden, así que se calculan sobre pares (orden, categoría) DISTINTOS: una orden con 3
-- ítems de la misma categoría aporta su puntaje una vez; una con 2 categorías aporta a
-- ambas (la reseña es de la orden, no del producto).

with items as (
    select * from {{ ref('fct_order_items') }}
    where fue_entregado
),

pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

-- ventana de crecimiento: últimos 6 meses completos vs. los 6 anteriores. Se excluye el
-- último mes del dataset porque está truncado por el corte.
ventana as (
    select date_sub(max(mes_compra), interval 1 month) as ultimo_mes_completo
    from pedidos
),

ventas as (
    select
        i.categoria,
        count(*)                                                                as total_items,
        count(distinct i.order_id)                                              as total_pedidos,
        count(distinct i.product_id)                                            as productos_distintos,
        count(distinct i.seller_id)                                             as vendedores_distintos,
        round(sum(i.ingresos_productos), 2)                                     as ingresos_productos,
        round(sum(i.gastos_envio), 2)                                           as gastos_envio_totales,
        round(avg(i.ingresos_productos), 2)                                     as precio_promedio_item,
        round(safe_divide(sum(i.gastos_envio), sum(i.ingresos_productos)), 4)   as ratio_flete_precio,
        round(avg(i.peso_facturable_g), 0)                                      as peso_facturable_promedio_g,
        round(sum(if(
            i.mes_compra between date_sub(v.ultimo_mes_completo, interval 5 month) and v.ultimo_mes_completo,
            i.ingresos_productos, 0
        )), 2)                                                                  as ingresos_ultimos_6m,
        round(sum(if(
            i.mes_compra between date_sub(v.ultimo_mes_completo, interval 11 month)
            and date_sub(v.ultimo_mes_completo, interval 6 month),
            i.ingresos_productos, 0
        )), 2)                                                                  as ingresos_6m_previos
    from items as i
    cross join ventana as v
    group by 1
),

orden_categoria as (
    select distinct
        order_id,
        categoria
    from items
),

calidad as (
    select
        oc.categoria,
        round(avg(p.dias_entrega_total), 1)                                     as dias_entrega_promedio,
        round(safe_divide(
            countif(not p.entregado_a_tiempo),
            countif(p.entregado_a_tiempo is not null)
        ), 4)                                                                   as tasa_atraso,
        countif(p.puntaje_promedio is not null)                                 as pedidos_con_resena,
        round(avg(p.puntaje_promedio), 2)                                       as puntaje_promedio,
        round(safe_divide(
            countif(p.puntaje_promedio <= 2),
            countif(p.puntaje_promedio is not null)
        ), 4)                                                                   as tasa_resenas_negativas
    from orden_categoria as oc
    inner join pedidos as p on oc.order_id = p.order_id
    group by 1
),

final as (
    select
        row_number() over (order by v.ingresos_productos desc)                  as ranking,
        v.categoria,
        v.total_items,
        v.total_pedidos,
        v.productos_distintos,
        v.vendedores_distintos,
        v.ingresos_productos,
        round(safe_divide(v.ingresos_productos, sum(v.ingresos_productos) over ()), 4) as pct_ingresos,
        -- acumulado de mayor a menor: "las N categorías que explican el 80%"
        round(safe_divide(
            sum(v.ingresos_productos) over (
                order by v.ingresos_productos desc
                rows between unbounded preceding and current row
            ),
            sum(v.ingresos_productos) over ()
        ), 4)                                                                   as pct_ingresos_acumulado,
        v.precio_promedio_item,
        v.gastos_envio_totales,
        v.ratio_flete_precio,
        v.peso_facturable_promedio_g,
        q.dias_entrega_promedio,
        q.tasa_atraso,
        q.pedidos_con_resena,
        q.puntaje_promedio,
        q.tasa_resenas_negativas,
        v.ingresos_ultimos_6m,
        v.ingresos_6m_previos,
        -- null si la base anterior es chica: una categoría que pasa de R$ 50 a R$ 500 no
        -- está "creciendo 900%" en ningún sentido útil
        case
            when v.ingresos_6m_previos >= 10000
                then round(safe_divide(v.ingresos_ultimos_6m - v.ingresos_6m_previos, v.ingresos_6m_previos), 4)
        end                                                                     as crecimiento_6m_pct,
        v.total_pedidos >= 100                                                  as es_significativo
    from ventas as v
    left join calidad as q on v.categoria = q.categoria
)

select * from final
order by ranking
