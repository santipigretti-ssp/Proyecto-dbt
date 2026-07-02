with source as (
    select * from {{ source('olist_raw', 'raw_orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        order_status,
        -- Convertimos strings a timestamp
        cast(order_purchase_timestamp as timestamp) as fecha_compra,
        cast(order_delivered_customer_date as timestamp) as fecha_entrega
    from source
)

select * from renamed
