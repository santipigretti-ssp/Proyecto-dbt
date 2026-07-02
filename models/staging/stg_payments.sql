with source as (
    select * from {{ source('olist_raw', 'raw_payments') }}
),

renamed as (
    select
        order_id,
        payment_sequential as secuencia_pago,
        payment_type as tipo_pago,
        cast(payment_installments as int64) as cuotas,
        cast(payment_value as float64) as valor_pago
    from source
)

select * from renamed
