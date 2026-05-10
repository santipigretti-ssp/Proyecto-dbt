with source as (
    select * from {{ source('olist_raw', 'raw_customers') }}
),

renamed as (
    select
        customer_id,
        customer_unique_id,
        customer_city as ciudad,
        customer_state as estado
    from source
)

select * from renamed
