-- rpt_resumen_ejecutivo debe tener exactamente una fila (KPIs de cabecera).
select count(*) as filas
from {{ ref('rpt_resumen_ejecutivo') }}
having count(*) != 1
