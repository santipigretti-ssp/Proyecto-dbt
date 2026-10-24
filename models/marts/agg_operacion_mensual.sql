{{ config(materialized='table') }}

-- Salud operativa mes a mes: tiempos de entrega por tramo, puntualidad, colchón de la
-- promesa, satisfacción y desenlace de las órdenes. Es la serie que muestra los dos
-- episodios de deterioro del dataset (2017-11 y 2018-02/03), donde el atraso se
-- triplica y el puntaje cae, y la recuperación posterior.
--
-- Grano: mes de COMPRA. Incluye todas las órdenes para medir cancelación; las métricas
-- de entrega se calculan solo sobre las entregadas.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
),

final as (
    select
        mes_compra                                                              as mes,

        -- desenlace de todas las órdenes del mes
        count(*)                                                                as total_pedidos,
        countif(fue_entregado)                                                  as pedidos_entregados,
        countif(fue_cancelado)                                                  as pedidos_cancelados,
        countif(not fue_entregado and not fue_cancelado)                        as pedidos_sin_entregar,
        round(safe_divide(countif(fue_cancelado), count(*)), 4)                 as tasa_cancelacion,

        -- tiempos (solo entregadas)
        round(avg(if(fue_entregado, dias_entrega_total, null)), 1)              as dias_entrega_promedio,
        approx_quantiles(if(fue_entregado, dias_entrega_total, null), 100)[offset(50)] as dias_entrega_p50,
        approx_quantiles(if(fue_entregado, dias_entrega_total, null), 100)[offset(90)] as dias_entrega_p90,
        round(avg(if(fue_entregado, dias_aprobacion, null)), 2)                 as dias_aprobacion,
        round(avg(if(fue_entregado, dias_handling_vendedor, null)), 2)          as dias_handling_vendedor,
        round(avg(if(fue_entregado, dias_transito_courier, null)), 2)           as dias_transito_courier,

        -- puntualidad contra la promesa (solo entregadas con ambas fechas)
        countif(fue_entregado and entregado_a_tiempo is not null)               as pedidos_con_promesa,
        round(safe_divide(
            countif(fue_entregado and not entregado_a_tiempo),
            countif(fue_entregado and entregado_a_tiempo is not null)
        ), 4)                                                                   as tasa_atraso,
        -- días que la promesa le dio de más al cliente: positivo = llegó antes
        round(avg(if(fue_entregado, -dias_vs_promesa, null)), 1)                as colchon_promesa_dias,

        -- satisfacción (solo entregadas con reseña)
        countif(fue_entregado and puntaje_promedio is not null)                 as pedidos_con_resena,
        round(avg(if(fue_entregado, puntaje_promedio, null)), 2)                as puntaje_promedio,
        round(safe_divide(
            countif(fue_entregado and puntaje_promedio <= 2),
            countif(fue_entregado and puntaje_promedio is not null)
        ), 4)                                                                   as tasa_resenas_negativas,

        countif(fue_entregado) >= 100                                           as es_significativo
    from pedidos
    group by 1
)

select * from final
order by mes
