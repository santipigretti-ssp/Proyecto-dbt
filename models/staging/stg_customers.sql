with source as (
    select * from {{ source('olist_raw', 'raw_customers') }}
),

renamed as (
    select
        customer_id,
        customer_unique_id as id_unico_cliente,
        customer_city as ciudad,
        customer_state as estado,
        cast(customer_zip_code_prefix as int64) as cp_cliente
    from source
)

select * from renamed
