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
        cast(order_approved_at as timestamp) as fecha_aprobacion_pago,
        -- momento en que el vendedor entrega el paquete al courier: es la frontera
        -- que separa la responsabilidad del vendedor (handling) de la del transportista
        cast(order_delivered_carrier_date as timestamp) as fecha_despacho_courier,
        cast(order_delivered_customer_date as timestamp) as fecha_entrega,
        cast(order_estimated_delivery_date as timestamp) as fecha_estimada_entrega
    from source
)

select * from renamed
