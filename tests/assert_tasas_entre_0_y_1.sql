-- Toda métrica expresada como tasa/proporción debe estar entre 0 y 1.
-- Un valor > 1 delata un error de grano (típicamente numerador a nivel de ítem contra
-- denominador a nivel de orden, por el fan-out del join con order_items).

with tasas as (
    select 'rpt_resumen_ejecutivo.tasa_entrega_a_tiempo' as metrica, tasa_entrega_a_tiempo as valor from {{ ref('rpt_resumen_ejecutivo') }}
    union all select 'rpt_resumen_ejecutivo.tasa_entrega_a_tiempo_global', tasa_entrega_a_tiempo_global from {{ ref('rpt_resumen_ejecutivo') }}
    union all select 'rpt_resumen_ejecutivo.tasa_clientes_recurrentes', tasa_clientes_recurrentes from {{ ref('rpt_resumen_ejecutivo') }}
    union all select 'rpt_resumen_ejecutivo.tasa_cancelacion', tasa_cancelacion from {{ ref('rpt_resumen_ejecutivo') }}

    union all select 'agg_operacion_mensual.tasa_cancelacion', tasa_cancelacion from {{ ref('agg_operacion_mensual') }}
    union all select 'agg_operacion_mensual.tasa_atraso', tasa_atraso from {{ ref('agg_operacion_mensual') }}
    union all select 'agg_operacion_mensual.tasa_resenas_negativas', tasa_resenas_negativas from {{ ref('agg_operacion_mensual') }}

    union all select 'agg_metodos_pago.pct_pedidos_mes', pct_pedidos_mes from {{ ref('agg_metodos_pago') }}
    union all select 'agg_metodos_pago.pct_volumen_mes', pct_volumen_mes from {{ ref('agg_metodos_pago') }}

    union all select 'agg_estados_cliente.pct_gmv_nacional', pct_gmv_nacional from {{ ref('agg_estados_cliente') }}
    union all select 'agg_estados_cliente.pct_pedidos_mismo_estado', pct_pedidos_mismo_estado from {{ ref('agg_estados_cliente') }}
    union all select 'agg_estados_cliente.pct_tiempo_courier', pct_tiempo_courier from {{ ref('agg_estados_cliente') }}
    union all select 'agg_estados_cliente.tasa_atraso', tasa_atraso from {{ ref('agg_estados_cliente') }}
    union all select 'agg_estados_cliente.tasa_resenas_negativas', tasa_resenas_negativas from {{ ref('agg_estados_cliente') }}
    union all select 'agg_estados_cliente.tasa_cancelacion', tasa_cancelacion from {{ ref('agg_estados_cliente') }}

    union all select 'agg_rutas_logisticas.pct_pedidos', pct_pedidos from {{ ref('agg_rutas_logisticas') }}
    union all select 'agg_rutas_logisticas.tasa_atraso', tasa_atraso from {{ ref('agg_rutas_logisticas') }}

    union all select 'agg_puntualidad_satisfaccion.pct_pedidos', pct_pedidos from {{ ref('agg_puntualidad_satisfaccion') }}
    union all select 'agg_puntualidad_satisfaccion.tasa_resenas_negativas', tasa_resenas_negativas from {{ ref('agg_puntualidad_satisfaccion') }}
    union all select 'agg_puntualidad_satisfaccion.tasa_resenas_positivas', tasa_resenas_positivas from {{ ref('agg_puntualidad_satisfaccion') }}

    union all select 'agg_categorias.pct_ingresos', pct_ingresos from {{ ref('agg_categorias') }}
    union all select 'agg_categorias.pct_ingresos_acumulado', pct_ingresos_acumulado from {{ ref('agg_categorias') }}
    union all select 'agg_categorias.tasa_atraso', tasa_atraso from {{ ref('agg_categorias') }}
    union all select 'agg_categorias.tasa_resenas_negativas', tasa_resenas_negativas from {{ ref('agg_categorias') }}

    union all select 'agg_vendedores.pct_ingresos', pct_ingresos from {{ ref('agg_vendedores') }}
    union all select 'agg_vendedores.pct_ingresos_acumulado', pct_ingresos_acumulado from {{ ref('agg_vendedores') }}
    union all select 'agg_vendedores.pct_vendedores_acumulado', pct_vendedores_acumulado from {{ ref('agg_vendedores') }}
    union all select 'agg_vendedores.tasa_atraso', tasa_atraso from {{ ref('agg_vendedores') }}
    union all select 'agg_vendedores.tasa_resenas_negativas', tasa_resenas_negativas from {{ ref('agg_vendedores') }}
    union all select 'agg_vendedores.tasa_cancelacion', tasa_cancelacion from {{ ref('agg_vendedores') }}

    union all select 'agg_cohortes_retencion.tasa_retencion', tasa_retencion from {{ ref('agg_cohortes_retencion') }}
)

select * from tasas
where valor is not null and (valor < 0 or valor > 1)
