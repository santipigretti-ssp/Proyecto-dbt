with source as (
    select * from {{ source('olist_raw', 'raw_customers') }}
),

renamed as (
    select
        customer_id,
        customer_unique_id as id_unico_cliente,
        customer_city as ciudad,
        customer_state as estado
    from source
)

select * from renamed
