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
    from rango as r
    cross join unnest(generate_date_array(r.fecha_min, r.fecha_max)) as dia
),

nombres_dia as (
    -- format_date('%A') devuelve el nombre en inglés y BigQuery no tiene locale
    select ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'] as nombres
),

final as (
    select
        f.dia                                            as fecha,
        extract(year from f.dia)                         as anio,
        extract(month from f.dia)                        as mes_num,
        format_date('%Y-%m', f.dia)                      as anio_mes,
        date_trunc(f.dia, month)                         as primer_dia_mes,
        extract(quarter from f.dia)                      as trimestre,
        extract(dayofweek from f.dia)                    as dia_semana_num,
        n.nombres[offset(extract(dayofweek from f.dia) - 1)] as dia_semana,
        extract(dayofweek from f.dia) in (1, 7)          as es_fin_de_semana
    from fechas as f
    cross join nombres_dia as n
)

select * from final
