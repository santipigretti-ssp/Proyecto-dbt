{{ config(materialized='table') }}

-- Riesgo de concentración: qué porcentaje de la facturación depende de los pocos de
-- arriba. Es pregunta directa de directorio ("¿qué pasa si se nos va el top 10?") y
-- ninguna tabla del proyecto la respondía.
-- Grano: (dimension, tramo) — una fila por corte analizado.

with items as (
    select * from {{ ref('fct_order_items') }}
    where fue_entregado
),

-- ingresos por vendedor, rankeados
vendedores as (
    select
        seller_id                                                as entidad,
        sum(ingresos_productos)                                  as ingresos,
        row_number() over (order by sum(ingresos_productos) desc) as ranking,
        count(*) over ()                                         as total_entidades,
        sum(sum(ingresos_productos)) over ()                     as ingresos_globales
    from items
    group by 1
),

categorias as (
    select
        categoria                                                as entidad,
        sum(ingresos_productos)                                  as ingresos,
        row_number() over (order by sum(ingresos_productos) desc) as ranking,
        count(*) over ()                                         as total_entidades,
        sum(sum(ingresos_productos)) over ()                     as ingresos_globales
    from items
    group by 1
),

unificado as (
    select 'vendedores' as dimension, * from vendedores
    union all
    select 'categorias' as dimension, * from categorias
),

tramos as (
    select
        dimension,
        total_entidades,
        ingresos_globales,
        case
            when ranking <= 10 then 'Top 10'
            when ranking <= ceil(total_entidades * 0.01) then 'Top 1%'
            when ranking <= ceil(total_entidades * 0.10) then 'Top 10%'
            else 'Resto'
        end as tramo,
        ingresos
    from unificado
),

final as (
    select
        dimension,
        tramo,
        any_value(total_entidades)                                  as total_entidades,
        count(*)                                                    as entidades_en_tramo,
        round(sum(ingresos), 2)                                     as ingresos,
        round(safe_divide(sum(ingresos), any_value(ingresos_globales)), 4) as pct_ingresos
    from tramos
    group by dimension, tramo
)

select * from final
order by dimension, pct_ingresos desc
