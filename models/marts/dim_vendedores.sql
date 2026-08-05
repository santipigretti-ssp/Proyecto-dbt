{{ config(materialized='table') }}

-- Dimensión de vendedor con su ubicación geocodificada.

with sellers as (
    select * from {{ ref('stg_sellers') }}
),

geo as (
    select * from {{ ref('stg_geolocation') }}
),

final as (
    select
        s.seller_id,
        s.ciudad,
        s.estado,
        s.cp_vendedor,
        g.lat_promedio  as lat,
        g.lng_promedio  as lng
    from sellers as s
    left join geo as g on s.cp_vendedor = g.cp_prefix
)

select * from final
