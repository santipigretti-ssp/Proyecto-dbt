{{ config(materialized='table') }}

-- Dimensión de calendario cubriendo el rango del dataset. Permite que el BI agrupe por
-- mes/trimestre/día de semana sin recalcular date_trunc en cada gráfico, y sobre todo
-- permite detectar días SIN ventas (que un group by sobre los hechos nunca muestra).

with rango as (
    select
        min(date(fecha_compra)) as fecha_min,
        max(date(fecha_compra)) as fecha_max
    from {{ ref('stg_orders') }}
),

fechas as (
    select dia
    from rango,
    unnest(generate_date_array(fecha_min, fecha_max)) as dia
),

final as (
    select
        dia                                            as fecha,
        extract(year from dia)                         as anio,
        extract(month from dia)                        as mes_num,
        format_date('%Y-%m', dia)                      as anio_mes,
        date_trunc(dia, month)                         as primer_dia_mes,
        extract(quarter from dia)                      as trimestre,
        extract(dayofweek from dia)                    as dia_semana_num,
        format_date('%A', dia)                         as dia_semana,
        extract(dayofweek from dia) in (1, 7)          as es_fin_de_semana
    from fechas
)

select * from final
