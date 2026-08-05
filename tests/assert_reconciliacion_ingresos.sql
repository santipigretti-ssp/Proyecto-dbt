-- RECONCILIACIÓN: todos los agregados tienen que sumar lo mismo que el hecho del que salen.
--
-- Este es el test que faltaba en el proyecto. Los `not_null` sobre columnas agregadas casi
-- nunca fallan (un sum() no es null si hay filas), así que daban una sensación de cobertura
-- que no era real. Esto sí detecta el error caro: que un mart quede desalineado del resto
-- por un join que duplica filas o un filtro que alguien cambió en un solo lugar.
--
-- Tolerancia de 1 centavo por redondeo acumulado en los round(...,2) de cada agregado.

with verdad as (
    select
        round(sum(ingresos_productos), 2) as ingresos,
        count(distinct order_id)          as pedidos
    from {{ ref('fct_order_items') }}
    where fue_entregado
),

comparaciones as (

    select
        'agg_ventas_ciudad' as mart,
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_ventas_ciudad') }}) as valor,
        (select ingresos from verdad) as esperado

    union all
    select
        'agg_ventas_mensual',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_ventas_mensual') }}),
        (select ingresos from verdad)

    union all
    select
        'agg_ventas_categoria',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_ventas_categoria') }}),
        (select ingresos from verdad)

    union all
    select
        'rpt_resumen_ejecutivo',
        (select ingresos_productos from {{ ref('rpt_resumen_ejecutivo') }}),
        (select ingresos from verdad)

    union all
    select
        'agg_take_rate',
        (select round(sum(ingresos_productos), 2) from {{ ref('agg_take_rate') }}),
        (select ingresos from verdad)

    -- conteo de pedidos: agg_ventas_ciudad y agg_ventas_mensual están a grano orden,
    -- así que sus total_pedidos deben sumar al total de órdenes entregadas
    union all
    select
        'agg_ventas_ciudad.total_pedidos',
        (select sum(total_pedidos) from {{ ref('agg_ventas_ciudad') }}),
        (select pedidos from verdad)

    union all
    select
        'agg_ventas_mensual.total_pedidos',
        (select sum(total_pedidos) from {{ ref('agg_ventas_mensual') }}),
        (select pedidos from verdad)

    union all
    select
        'rpt_resumen_ejecutivo.total_pedidos',
        (select total_pedidos_entregados from {{ ref('rpt_resumen_ejecutivo') }}),
        (select pedidos from verdad)
)

select
    mart,
    valor,
    esperado,
    round(valor - esperado, 2) as diferencia
from comparaciones
where abs(valor - esperado) > 0.01
