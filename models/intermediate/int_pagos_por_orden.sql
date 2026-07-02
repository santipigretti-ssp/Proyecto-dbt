with payments as (
    select * from {{ ref('stg_payments') }}
),

-- one row per order: sum all payments (an order can have multiple payment methods)
final as (
    select
        order_id,
        sum(valor_pago) as valor_total_orden,
        max(cuotas) as max_cuotas
    from payments
    group by order_id
)

select * from final
