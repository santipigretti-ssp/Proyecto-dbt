with source as (
    select * from {{ source('olist_raw', 'raw_sellers') }}
),

renamed as (
    select
        seller_id,
        seller_city as ciudad,
        seller_state as estado,
        cast(seller_zip_code_prefix as int64) as cp_vendedor
    from source
)

select * from renamed
