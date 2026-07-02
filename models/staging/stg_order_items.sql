with source as (
    select * from {{ source('olist_raw', 'raw_order_items') }}
),

renamed as (
    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        price as monto,
        freight_value as costo_envio
    from source
)

select * from renamed