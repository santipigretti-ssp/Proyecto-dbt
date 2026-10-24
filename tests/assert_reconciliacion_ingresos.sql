-- RECONCILIACIÓN: todos los agregados tienen que sumar lo mismo que los hechos de los
-- que salen.
--
-- Un not_null sobre una columna agregada casi nunca falla (un sum() no es null si hay
-- filas). Este test detecta el error caro: que un mart quede desalineado del resto por
-- un join que duplica filas o por un filtro cambiado en un solo lugar.
--
-- Tolerancia: 1 centavo por mart en montos (redondeo acumulado de los round(..., 2)).

with verdad as (
    select
        round(sum(ingresos_productos), 2)                               as ingresos,
        count(*)                                                        as pedidos,
        round(sum(if(not valor_pagado_imputado, valor_pagado, 0)), 2)   as pagos_observados
    from {{ ref('fct_pedidos') }}
    where fue_entregado
),

comparaciones as (

    -- ingresos de mercadería
    select 'agg_ventas_mensual.ingresos' as mart,
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_ventas_mensual') }}) as valor,
        (select ingresos from verdad) as esperado
    union all
    select 'agg_take_rate.ingresos',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_take_rate') }}),
        (select ingresos from verdad)
    union all
    select 'agg_estados_cliente.ingresos',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_estados_cliente') }}),
        (select ingresos from verdad)
    union all
    select 'agg_rutas_logisticas.ingresos',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_rutas_logisticas') }}),
        (select ingresos from verdad)
    union all
    select 'agg_categorias.ingresos',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_categorias') }}),
        (select ingresos from verdad)
    union all
    select 'agg_vendedores.ingresos',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_vendedores') }}),
        (select ingresos from verdad)
    union all
    select 'fct_order_items.ingresos',
        (select round(sum(ingresos_productos), 2) from {{ ref('fct_order_items') }} where fue_entregado),
        (select ingresos from verdad)
    union all
    select 'rpt_resumen_ejecutivo.ingresos',
        (select ingresos_productos from {{ ref('rpt_resumen_ejecutivo') }}),
        (select ingresos from verdad)

    -- conteo de órdenes entregadas: solo en marts donde cada orden cae en una sola fila
    union all
    select 'agg_ventas_mensual.pedidos',
        (select sum(total_pedidos) from {{ ref('agg_ventas_mensual') }}),
        (select pedidos from verdad)
    union all
    select 'agg_operacion_mensual.pedidos_entregados',
        (select sum(pedidos_entregados) from {{ ref('agg_operacion_mensual') }}),
        (select pedidos from verdad)
    union all
    select 'agg_estados_cliente.pedidos',
        (select sum(total_pedidos) from {{ ref('agg_estados_cliente') }}),
        (select pedidos from verdad)
    union all
    select 'agg_rutas_logisticas.pedidos',
        (select sum(total_pedidos) from {{ ref('agg_rutas_logisticas') }}),
        (select pedidos from verdad)
    union all
    select 'rpt_resumen_ejecutivo.pedidos',
        (select total_pedidos_entregados from {{ ref('rpt_resumen_ejecutivo') }}),
        (select pedidos from verdad)

    -- volumen de pagos: agg_metodos_pago sale de stg_payments, así que se compara contra
    -- valor_pagado excluyendo la única orden imputada (que no tiene filas de pago)
    union all
    select 'agg_metodos_pago.volumen',
        (select round(sum(volumen_pagado), 2) from {{ ref('agg_metodos_pago') }}),
        (select pagos_observados from verdad)
)

select
    mart,
    valor,
    esperado,
    round(valor - esperado, 2) as diferencia
from comparaciones
where valor is null or abs(valor - esperado) > 0.01
