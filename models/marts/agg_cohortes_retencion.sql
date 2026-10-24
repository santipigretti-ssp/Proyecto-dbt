{{ config(materialized='table') }}

-- Retención por cohorte de adquisición. Grano: (cohorte_mes, meses_desde_primera_compra).
--
-- Por qué existe: el proyecto reporta una tasa de recompra del 3% y la explica como
-- "característica del marketplace". Es cierto, pero incompleto: la ventana de observación
-- está TRUNCADA (2016-09 a 2018-08). Un cliente que compró en agosto 2018 tuvo cero días
-- para volver, y sin embargo cuenta como "no recurrente" en el 3%. Sin curva de cohortes
-- no se puede distinguir "no vuelven" de "todavía no tuvieron tiempo de volver".
--
-- La columna meses_observables es la clave para leer esta tabla honestamente: si vale 0,
-- la celda no tiene información, no es un 0% de retención.

with pedidos as (
    select * from {{ ref('fct_pedidos') }}
    where fue_entregado
),

clientes as (
    select * from {{ ref('dim_clientes') }}
),

fin_dataset as (
    select date_trunc(max(fecha_compra), month) as ultimo_mes from pedidos
),

-- cada compra ubicada respecto de la cohorte de su cliente
compras as (
    select
        c.cohorte_mes,
        p.id_unico_cliente,
        date_diff(p.mes_compra, c.cohorte_mes, month) as meses_desde_primera_compra,
        p.valor_pagado
    from pedidos as p
    inner join clientes as c on p.id_unico_cliente = c.id_unico_cliente
),

tamano_cohorte as (
    select
        cohorte_mes,
        count(distinct id_unico_cliente) as clientes_cohorte
    from compras
    where meses_desde_primera_compra = 0
    group by 1
),

actividad as (
    select
        cohorte_mes,
        meses_desde_primera_compra,
        count(distinct id_unico_cliente)  as clientes_activos,
        round(sum(valor_pagado), 2)       as ingresos_periodo
    from compras
    group by 1, 2
),

final as (
    select
        a.cohorte_mes,
        a.meses_desde_primera_compra,
        t.clientes_cohorte,
        a.clientes_activos,
        round(safe_divide(a.clientes_activos, t.clientes_cohorte), 4) as tasa_retencion,
        a.ingresos_periodo,
        round(safe_divide(a.ingresos_periodo, t.clientes_cohorte), 2) as ingreso_por_cliente_cohorte,
        -- cuántos meses de historia posterior alcanzó a tener esta cohorte dentro del
        -- dataset: si meses_desde_primera_compra se acerca a este número, la celda está
        -- censurada por corte de datos y no por comportamiento del cliente
        date_diff((select ultimo_mes from fin_dataset), a.cohorte_mes, month) as meses_observables
    from actividad as a
    inner join tamano_cohorte as t on a.cohorte_mes = t.cohorte_mes
)

select * from final
order by cohorte_mes, meses_desde_primera_compra
