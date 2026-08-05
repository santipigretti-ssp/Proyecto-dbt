{{ config(materialized='table') }}

with source as (
    select * from {{ source('olist_raw', 'raw_geolocation') }}
),

renamed as (
    select
        cast(geolocation_zip_code_prefix as int64) as cp_prefix,
        geolocation_lat as lat,
        geolocation_lng as lng
    from source
),

-- el mismo cp_prefix aparece muchas veces con lat/lng ligeramente distintos;
-- promediamos para tener un punto representativo por prefijo de código postal
promedio as (
    select
        cp_prefix,
        avg(lat) as lat_promedio,
        avg(lng) as lng_promedio
    from renamed
    group by 1
)

select * from promedio
