{{ config(materialized='table') }}

-- Cuánto cae la satisfacción a medida que la entrega se atrasa respecto de lo prometido.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
      and fecha_entrega is not null
      and fecha_estimada_entrega is not null
),

bucketizado as (
    select
        estado_cliente as estado,
        case
            when dias_vs_promesa < 0 then 'Adelantado'
            when dias_vs_promesa = 0 then 'A tiempo'
            when dias_vs_promesa between 1 and 3 then 'Tarde (1-3 dias)'
            else 'Muy tarde (4+ dias)'
        end as bucket_puntualidad,
        puntaje_promedio
    from pedidos
),

final as (
    select
        estado,
        bucket_puntualidad,
        count(*)                                                            as total_pedidos,
        round(avg(puntaje_promedio), 2)                                     as puntaje_promedio,
        round(safe_divide(countif(puntaje_promedio <= 2), countif(puntaje_promedio is not null)), 4) as tasa_resenas_negativas
    from bucketizado
    group by 1, 2
)

select * from final
