-- Toda métrica expresada como tasa/proporción debe estar entre 0 y 1.
-- Un valor > 1 delata un error de grano (típicamente numerador a nivel de ítem contra
-- denominador a nivel de orden, por el fan-out del join con order_items).

with tasas as (
    select 'rpt_resumen_ejecutivo.tasa_entrega_a_tiempo'        as metrica, tasa_entrega_a_tiempo        as valor from {{ ref('rpt_resumen_ejecutivo') }}
    union all
    select 'rpt_resumen_ejecutivo.tasa_entrega_a_tiempo_global' as metrica, tasa_entrega_a_tiempo_global as valor from {{ ref('rpt_resumen_ejecutivo') }}
    union all
    select 'rpt_resumen_ejecutivo.tasa_clientes_recurrentes'    as metrica, tasa_clientes_recurrentes    as valor from {{ ref('rpt_resumen_ejecutivo') }}
    union all
    select 'rpt_resumen_ejecutivo.tasa_cancelacion'             as metrica, tasa_cancelacion             as valor from {{ ref('rpt_resumen_ejecutivo') }}
    union all
    select 'agg_estados_pedido.pct_del_total'                   as metrica, pct_del_total                as valor from {{ ref('agg_estados_pedido') }}
    union all
    select 'agg_distancia_entrega.tasa_atraso'                  as metrica, tasa_atraso                  as valor from {{ ref('agg_distancia_entrega') }}
    union all
    select 'agg_rendimiento_vendedores.tasa_atraso'             as metrica, tasa_atraso                  as valor from {{ ref('agg_rendimiento_vendedores') }}
    union all
    select 'agg_rendimiento_vendedores.tasa_cancelacion'        as metrica, tasa_cancelacion             as valor from {{ ref('agg_rendimiento_vendedores') }}
    union all
    select 'agg_puntualidad_satisfaccion.tasa_resenas_negativas' as metrica, tasa_resenas_negativas      as valor from {{ ref('agg_puntualidad_satisfaccion') }}
    union all
    select 'agg_ventas_categoria.pct_ingresos'                  as metrica, pct_ingresos                 as valor from {{ ref('agg_ventas_categoria') }}
    union all
    select 'agg_concentracion.pct_ingresos'                     as metrica, pct_ingresos                 as valor from {{ ref('agg_concentracion') }}
    union all
    select 'fct_cohortes_retencion.tasa_retencion'              as metrica, tasa_retencion               as valor from {{ ref('fct_cohortes_retencion') }}
)

select * from tasas
where valor is not null and (valor < 0 or valor > 1)
