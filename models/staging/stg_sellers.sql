with source as (
    select * from {{ source('olist_raw', 'raw_sellers') }}
),

renamed as (
    select
        seller_id,
        seller_city     as ciudad,
        seller_state    as estado
    from source
)

select * from renamed
