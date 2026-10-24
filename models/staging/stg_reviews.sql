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
)

-- GRANO: (review_id, order_id), no review_id solo.
-- El raw trae 99.224 filas y 99.224 pares (review_id, order_id) distintos: no hay
-- duplicados exactos que limpiar. Lo que sí hay son 789 review_id que cubren más de
-- una orden (un cliente evalúa junto lo que compró junto) y 547 órdenes con más de
-- una reseña. Ambas cosas son legítimas del negocio, no suciedad.
--
-- Por eso NO se deduplica acá: un ROW_NUMBER() por review_id haría pasar un test
-- `unique` pero descartaría 814 vínculos reseña-orden válidos, y además no resolvería
-- el fan-out por orden, que es el que rompe los agregados. El fan-out se maneja donde
-- corresponde: colapsando a nivel orden en fct_pedidos.
select * from renamed
