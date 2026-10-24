with payments as (
    select * from {{ ref('stg_payments') }}
),

-- una fila por orden: una orden puede pagarse con varios medios (ej. voucher + tarjeta)
final as (
    select
        order_id,
        sum(valor_pago) as valor_total_orden,
        max(cuotas) as max_cuotas
    from payments
    group by order_id
)

select * from final
