{{ config(materialized='table') }}

-- Curva de satisfacción según los días de diferencia entre la entrega real y la
-- prometida. Grano: un día de diferencia, de -20 a +20 (los extremos acumulan la cola:
-- -20 = "20 o más días antes", +20 = "20 o más días tarde").
--
-- Muestra la forma de la relación, no solo un promedio por bucket: el puntaje es plano
-- mientras el pedido llega antes de lo prometido y se desploma apenas pasa la fecha.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado and dias_vs_promesa is not null
),

recortado as (
    select
        greatest(least(dias_vs_promesa, 20), -20) as dias_vs_promesa,
        bucket_puntualidad,
        puntaje_promedio
    from pedidos
),

total as (
    select count(*) as pedidos_globales from recortado
),

final as (
    select
        r.dias_vs_promesa,
        case
            when r.dias_vs_promesa = -20 then '20+ días antes'
            when r.dias_vs_promesa = 20 then '20+ días tarde'
            when r.dias_vs_promesa = -1 then '1 día antes'
            when r.dias_vs_promesa = 1 then '1 día tarde'
            when r.dias_vs_promesa < 0 then concat(cast(-r.dias_vs_promesa as string), ' días antes')
            when r.dias_vs_promesa = 0 then 'En la fecha'
            else concat(cast(r.dias_vs_promesa as string), ' días tarde')
        end                                                                     as etiqueta,
        any_value(r.bucket_puntualidad)                                         as bucket_puntualidad,
        count(*)                                                                as total_pedidos,
        round(safe_divide(count(*), any_value(t.pedidos_globales)), 4)          as pct_pedidos,
        countif(r.puntaje_promedio is not null)                                 as pedidos_con_resena,
        round(avg(r.puntaje_promedio), 2)                                       as puntaje_promedio,
        round(safe_divide(
            countif(r.puntaje_promedio <= 2),
            countif(r.puntaje_promedio is not null)
        ), 4)                                                                   as tasa_resenas_negativas,
        round(safe_divide(
            countif(r.puntaje_promedio >= 4),
            countif(r.puntaje_promedio is not null)
        ), 4)                                                                   as tasa_resenas_positivas
    from recortado as r
    cross join total as t
    group by 1, 2
)

select * from final
order by dias_vs_promesa
