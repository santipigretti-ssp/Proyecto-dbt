-- Región macroeconómica oficial (IBGE) a partir de la sigla del estado. Agrupa los 27
-- estados en 5 regiones, que es el corte con el que se lee la logística en Brasil.
{% macro region_brasil(columna_estado) -%}
    case
        when {{ columna_estado }} in ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') then 'Norte'
        when {{ columna_estado }} in ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') then 'Nordeste'
        when {{ columna_estado }} in ('DF', 'GO', 'MS', 'MT') then 'Centro-Oeste'
        when {{ columna_estado }} in ('ES', 'MG', 'RJ', 'SP') then 'Sudeste'
        when {{ columna_estado }} in ('PR', 'RS', 'SC') then 'Sur'
    end
{%- endmacro %}
