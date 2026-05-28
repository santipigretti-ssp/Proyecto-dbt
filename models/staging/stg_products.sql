with source as (
    select * from {{ source('olist_raw', 'raw_products') }}
),

categories as (
    select * from {{ source('olist_raw', 'raw_category_translation') }}
),

renamed as (
    select
        p.product_id,
        p.product_category_name,
        c.product_category_name_english             as categoria_en,
        cast(p.product_weight_g as int64)           as peso_g,
        cast(p.product_length_cm as int64)          as largo_cm,
        cast(p.product_height_cm as int64)          as alto_cm,
        cast(p.product_width_cm as int64)           as ancho_cm
    from source p
    left join categories c using (product_category_name)
)

select * from renamed
