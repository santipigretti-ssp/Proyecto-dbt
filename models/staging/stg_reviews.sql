with source as (
    select * from {{ source('olist_raw', 'raw_reviews') }}
),

renamed as (
    select
        review_id,
        order_id,
        cast(review_score as int64)                    as puntaje,
        review_comment_title                           as titulo_comentario,
        review_comment_message                         as comentario,
        cast(review_creation_date as timestamp)        as creado_en,
        cast(review_answer_timestamp as timestamp)     as respondido_en
    from source
),

-- some customers submitted multiple reviews for the same order;
-- keep only the most recent one per review_id
deduped as (
    select *,
        row_number() over (
            partition by review_id
            order by respondido_en desc
        ) as rn
    from renamed
)

select * except (rn) from deduped where rn = 1
