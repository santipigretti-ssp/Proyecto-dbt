{{ config(materialized='table') }}

-- Scorecard por vendedor + curva de concentración. Una fila por vendedor con al menos
-- una venta entregada.
--
-- Combina dos granos: ingresos a grano ítem (lo que le corresponde a cada vendedor) y
-- puntualidad/satisfacción a grano (vendedor, orden), para no ponderar la calidad por
-- cantidad de ítems. En órdenes con varios vendedores (~1%) los atributos de la orden se
-- atribuyen a todos ellos: el dataset tiene una sola fecha de despacho por orden.
--
-- Concentración: ranking + pct acumulado alimentan una curva de Lorenz. tramo_concentracion
-- son tramos EXCLUYENTES con el rango explícito en el nombre (Top 1%, Top 1-10%, ...), para
-- que nadie lea "Top 10%" como acumulado cuando no lo es.

with items as (
    select * from {{ ref('fct_order_items') }}
),

pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

vendedores as (
    select * from {{ ref('dim_vendedores') }}
),

ventas as (
    select
        seller_id,
        count(*)                                as total_items,
        count(distinct order_id)                as total_pedidos,
        sum(ingresos_productos)                 as ingresos_productos,
        round(avg(ingresos_productos), 2)       as precio_promedio_item,
        count(distinct mes_compra)              as meses_con_ventas,
        min(fecha_compra)                       as primera_venta,
        max(fecha_compra)                       as ultima_venta
    from items
    where fue_entregado
    group by 1
),

ingresos_por_categoria as (
    select
        seller_id,
        categoria,
        sum(ingresos_productos) as ingresos
    from items
    where fue_entregado
    group by 1, 2
),

categoria_principal as (
    select
        seller_id,
        array_agg(categoria order by ingresos desc, categoria asc limit 1)[offset(0)] as categoria_principal
    from ingresos_por_categoria
    group by 1
),

-- una fila por (vendedor, orden): la calidad se mide por orden, no por ítem
vendedor_orden as (
    select distinct
        i.seller_id,
        i.order_id
    from items as i
    where i.fue_entregado
),

calidad as (
    select
        vo.seller_id,
        round(avg(p.dias_entrega_total), 1)                                     as dias_entrega_promedio,
        round(avg(p.dias_handling_vendedor), 2)                                 as dias_handling_vendedor,
        round(safe_divide(
            countif(not p.entregado_a_tiempo),
            countif(p.entregado_a_tiempo is not null)
        ), 4)                                                                   as tasa_atraso,
        round(avg(p.puntaje_promedio), 2)                                       as puntaje_promedio,
        round(safe_divide(
            countif(p.puntaje_promedio <= 2),
            countif(p.puntaje_promedio is not null)
        ), 4)                                                                   as tasa_resenas_negativas
    from vendedor_orden as vo
    inner join pedidos as p on vo.order_id = p.order_id
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

rankeado as (
    select
        *,
        row_number() over (order by ingresos_productos desc, seller_id asc)    as ranking,
        count(*) over ()                                                        as total_vendedores,
        sum(ingresos_productos) over ()                                         as ingresos_globales,
        sum(ingresos_productos) over (
            order by ingresos_productos desc, seller_id asc
            rows between unbounded preceding and current row
        )                                                                       as ingresos_acumulados
    from ventas
),

final as (
    select
        r.seller_id,
        v.ciudad,
        v.estado,
        {{ region_brasil('v.estado') }}                                         as region,
        cp.categoria_principal,
        r.primera_venta,
        r.ultima_venta,
        r.meses_con_ventas,
        r.total_items,
        r.total_pedidos,
        round(r.ingresos_productos, 2)                                          as ingresos_productos,
        r.precio_promedio_item,

        r.ranking,
        round(safe_divide(r.ingresos_productos, r.ingresos_globales), 6)        as pct_ingresos,
        round(safe_divide(r.ingresos_acumulados, r.ingresos_globales), 4)       as pct_ingresos_acumulado,
        round(safe_divide(r.ranking, r.total_vendedores), 4)                    as pct_vendedores_acumulado,
        case
            when r.ranking <= ceil(r.total_vendedores * 0.01) then 'Top 1%'
            when r.ranking <= ceil(r.total_vendedores * 0.10) then 'Top 1-10%'
            when r.ranking <= ceil(r.total_vendedores * 0.50) then 'Top 10-50%'
            else 'Bottom 50%'
        end                                                                     as tramo_concentracion,

        q.dias_entrega_promedio,
        q.dias_handling_vendedor,
        q.tasa_atraso,
        q.puntaje_promedio,
        q.tasa_resenas_negativas,
        c.total_pedidos_todos,
        c.tasa_cancelacion,
        -- sin este filtro, los rankings de calidad los dominan vendedores con 1 venta
        r.total_pedidos >= 20                                                   as es_significativo
    from rankeado as r
    inner join vendedores as v           on r.seller_id = v.seller_id
    left join categoria_principal as cp  on r.seller_id = cp.seller_id
    left join calidad as q               on r.seller_id = q.seller_id
    left join cancelaciones as c         on r.seller_id = c.seller_id
)

select * from final
order by ranking
