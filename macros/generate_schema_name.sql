-- Usa el +schema de cada capa tal cual (olist_staging, olist_marts, ...) en vez del
-- comportamiento por defecto de dbt, que lo concatena al dataset del profile
-- (dbt_staging_olist_marts).
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
