{{ config(materialized='table') }}

-- Dimensión de producto. Centraliza el cálculo del peso facturable para que no se
-- repita (ni se rompa) en cada mart que lo necesite.

with products as (
    select * from {{ ref('stg_products') }}
),

final as (
    select
        product_id,
        product_category_name                     as categoria_pt,
        coalesce(categoria_en, 'Uncategorized')   as categoria,
        peso_g,
        largo_cm,
        alto_cm,
        ancho_cm,
        largo_cm * alto_cm * ancho_cm             as volumen_cm3,
        -- OJO CON LAS UNIDADES: la fórmula estándar de couriers largo*alto*ancho/6000
        -- devuelve KILOS y acá comparamos contra peso_g, que está en GRAMOS. Por eso el
        -- divisor es 6.0 y no 6000 (cm³/6000 = kg → cm³/6 = g).
        greatest(
            peso_g,
            safe_divide(largo_cm * alto_cm * ancho_cm, 6.0)
        )                                         as peso_facturable_g,
        case
            when greatest(peso_g, safe_divide(largo_cm * alto_cm * ancho_cm, 6.0)) < 500 then 'Liviano (<500g)'
            when greatest(peso_g, safe_divide(largo_cm * alto_cm * ancho_cm, 6.0)) < 2000 then 'Medio (500g-2kg)'
            when greatest(peso_g, safe_divide(largo_cm * alto_cm * ancho_cm, 6.0)) < 5000 then 'Pesado (2kg-5kg)'
            else 'Muy pesado (5kg+)'
        end                                       as bucket_peso
    from products
)

select * from final
