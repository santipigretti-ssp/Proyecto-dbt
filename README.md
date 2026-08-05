# Pipeline ELT con dbt Core y BigQuery — Olist Brazilian E-Commerce

Pipeline de datos end-to-end que transforma datos crudos del e-commerce brasileño Olist en tablas analíticas listas para dashboards. Construido con dbt Core y Google BigQuery.

---

## Hallazgos

Siete conclusiones que salieron de los datos, con su implicancia de negocio. Todas las cifras
son reproducibles corriendo `dbt build` y consultando los marts.

### 1. El cuello de botella logístico es el courier, no el vendedor

Descomponiendo el tiempo de entrega en sus tres tramos (`agg_tiempo_entrega`):

| Tramo | Responsable | Días | % del total |
|---|---|---|---|
| Compra → aprobación del pago | Plataforma | 0,41 | 3,3 % |
| Aprobación → despacho | **Vendedor** | 2,78 | 22,2 % |
| Despacho → entrega | **Courier** | 9,31 | **74,5 %** |

**Implicancia:** exigirle más a los vendedores tiene techo — aun eliminando por completo su
tiempo de handling, la entrega solo bajaría de 12,5 a 9,7 días. La palanca real es renegociar
con el transportista o descentralizar la distribución. Este análisis requiere dos columnas
(`order_approved_at`, `order_delivered_carrier_date`) que la mayoría de los proyectos sobre
este dataset descarta en staging.

### 2. El crecimiento se frenó en los últimos 6 meses

Variación mensual de ingresos (`agg_ventas_mensual.ingresos_mom_pct`):

```
2018-01  +27,4%     2018-04   +2,1%     2018-07   +1,4%
2018-02  -10,6%     2018-05   +0,4%
2018-03  +15,4%     2018-06  -12,4%
```

**Implicancia:** tras crecer con fuerza hasta marzo de 2018, el negocio se aplanó. Un dashboard
que muestre solo el nivel de ingresos (la curva acumulada sigue subiendo) oculta esto por
completo; por eso el mart expone la variación como columna y no como un cálculo del BI.

### 3. Como marketplace, el negocio real es ~10x más chico de lo que sugiere el GMV

| Concepto | Monto |
|---|---|
| GMV (circula por la plataforma) | R$ 15,42 M |
| Margen estimado de la plataforma | **R$ 1,52 M** |
| Take rate efectivo | **9,86 %** |

**Implicancia:** llamar "ingresos" al GMV sobreestima el negocio en un orden de magnitud. Olist
no factura R$ 15,4 M, cobra comisión sobre esos R$ 15,4 M. Como el dataset no expone la comisión,
`agg_take_rate` la modela con supuestos **declarados y parametrizados** (`vars` en
`dbt_project.yml`), recalculables sin tocar SQL: `dbt run --vars '{take_rate_comision: 0.18}'`.
El 9,86 % es `sum(margen_plataforma_estimado) / sum(gmv_total)` sobre los 23 meses del mart, no
el promedio simple de la columna mensual — esa cuenta da 9,75 % porque la pesa igual que un mes
de fase piloto con GMV casi cero. Ver detalle en `docs/diccionario_metricas.md`.

### 4. La distancia comprador-vendedor degrada todo de forma monótona

| Distancia | Pedidos | Flete | Días | Atraso | Reseña |
|---|---|---|---|---|---|
| Local (<100 km) | 17.803 | R$ 13,33 | 6,4 | 6,4 % | 4,28 |
| Regional (100-500 km) | 36.967 | R$ 20,96 | 11,4 | 7,2 % | 4,18 |
| Nacional (500-1500 km) | 32.440 | R$ 25,38 | 14,8 | 8,7 % | 4,10 |
| Larga distancia (1500 km+) | 8.792 | R$ 39,95 | 20,5 | 13,1 % | 4,00 |

**Implicancia:** el flete se triplica, el tiempo de entrega se triplica, el atraso se duplica y
la satisfacción cae 0,28 puntos. Es el argumento cuantitativo para abrir centros de distribución
regionales: hoy el 43 % de los pedidos viaja más de 500 km.

### 5. El 91,9 % de entregas a tiempo es menos bueno de lo que parece

- Colchón de la promesa: **11,9 días** — la fecha estimada le da al cliente casi el doble de lo
  que realmente se tarda (12,5 días reales contra ~24,4 prometidos).
- Sin sesgo de supervivencia (contando canceladas y las que nunca se entregaron): **89,7 %**.
- p90 de entrega: **23 días** — 1 de cada 10 pedidos tarda más que eso.

**Implicancia:** el on-time alto se consigue prometiendo de más, no entregando rápido. Hay
margen para acortar la promesa y competir, siempre que primero se ataque el punto 1.

### 6. La recompra del 3 % es real, no un artefacto del dataset truncado

Era la duda obvia: el dataset corta en 2018-08, así que un cliente de agosto no tuvo tiempo de
volver. `fct_cohortes_retencion` lo resuelve mirando solo cohortes con historia suficiente:

| Cohorte | Clientes | Retención mes 1 | Meses observables |
|---|---|---|---|
| 2017-02 | 1.628 | 0,18 % | 18 |
| 2017-04 | 2.256 | 0,62 % | 16 |
| 2017-06 | 3.037 | 0,49 % | 14 |
| 2017-07 | 3.752 | 0,53 % | 13 |

**Implicancia:** con 13 a 18 meses de ventana, la retención sigue en ~0,5 %. No es truncamiento:
es un negocio de compra única. El KPI que lo gobierna es **adquisición/CAC**, no retención — y
cualquier iniciativa de fidelización acá parte de una base casi nula.

### 7. La facturación está muy concentrada

- **Top 10 categorías = 62,4 %** de los ingresos; 18 de 72 explican el 80 %.
- **Top 10 % de vendedores (267 de 2.970) = 41,2 %** de los ingresos.

**Implicancia:** riesgo de dependencia. Perder un puñado de vendedores del decil superior mueve
la aguja de forma desproporcionada, y es la pregunta que un directorio hace primero.

---

## Stack

| Capa | Tecnología |
|---|---|
| Almacenamiento | Google BigQuery (Sandbox gratuito, región EU) |
| Transformación | dbt Core 1.11 + dbt-utils |
| Adapter | dbt-bigquery 1.10 |
| Lenguaje | Python 3.9 (venv) |
| IDE | VS Code + dbt Power User |
| Control de versiones | Git & GitHub |

---

## Dataset

[Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — 100k órdenes reales de 2016 a 2018 anonimizadas por Olist, el mayor marketplace de Brasil.

**Tablas cargadas en BigQuery (`dbt_staging`):**

| Tabla raw | Descripción |
|---|---|
| `raw_orders` | Cabeceras de órdenes con estado y fechas |
| `raw_customers` | Datos geográficos de clientes |
| `raw_order_items` | Productos, precios y fletes por orden |
| `raw_payments` | Métodos de pago, cuotas y montos |
| `raw_reviews` | Reseñas y puntajes de clientes |
| `raw_products` | Catálogo de productos con dimensiones |
| `raw_sellers` | Vendedores y su ubicación |
| `raw_category_translation` | Traducción de categorías al inglés |
| `raw_geolocation` | Coordenadas (lat/lng) por prefijo de código postal brasileño |

---

## Arquitectura

```
BigQuery (raw)
      │
      ▼
┌─────────────────────────────────────────────┐
│                STAGING (views)              │
│  stg_orders        stg_payments             │
│  stg_customers     stg_reviews              │
│  stg_order_items   stg_products             │
│  stg_sellers       stg_geolocation          │
│                                             │
│  · Renombrado de columnas                   │
│  · Cast de tipos (timestamps, ints)         │
│  · Grano (review_id, order_id)                │
│  · Join con tabla de traducción (products)  │
└─────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────┐
│             INTERMEDIATE (views)             │
│  int_pagos_por_orden                        │
│                                             │
│  · Agregaciones reutilizables entre marts   │
└─────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────┐
│              MARTS (tables)                 │
│                                             │
│  DIMENSIONES                                │
│    dim_clientes      dim_productos          │
│    dim_vendedores    dim_fecha              │
│                                             │
│  HECHOS  (grano transaccional + FKs)        │
│    fct_pedidos          → grano orden       │
│    fct_order_items      → grano ítem        │
│    fct_cohortes_retencion                   │
│                                             │
│  AGREGADOS  (salen de los hechos)           │
│    agg_ventas_ciudad     agg_ventas_mensual │
│    agg_ventas_categoria  agg_ticket_estado  │
│    agg_tiempo_entrega    agg_metodos_pago   │
│    agg_distancia_entrega agg_concentracion  │
│    agg_satisfaccion_categoria               │
│    agg_puntualidad_satisfaccion             │
│    agg_rendimiento_vendedores               │
│    agg_rentabilidad_flete                   │
│    agg_estados_pedido    agg_take_rate      │
│                                             │
│  REPORTE                                    │
│    rpt_resumen_ejecutivo  → 1 fila de KPIs  │
└─────────────────────────────────────────────┘
      │
      ▼
  Looker Studio / BI
```

### Por qué esta separación

Los `agg_*` **salen todos de los hechos**, no de staging por separado. Eso significa que hay
una sola definición de ingresos, flete y distancia, calculada una sola vez: los agregados ya
no pueden discrepar entre sí, y un test de reconciliación lo verifica en cada build.

`fct_order_items` (grano ítem, con FKs a las dimensiones) permite además responder preguntas
nuevas **sin escribir un mart nuevo**: "ventas por categoría y mes" o "atraso por vendedor y
estado" se resuelven con un `group by` en el BI.

El prefijo dice el rol: `dim_` entidad, `fct_` grano transaccional, `agg_` pre-agregado para
el BI, `rpt_` tablero servido sin grano.

---

## Documentación

| Documento | Contenido |
|---|---|
| [docs/diccionario_metricas.md](docs/diccionario_metricas.md) | **Qué significa cada métrica**: definición, cómo se construye, a quién se presenta, con qué periodicidad y qué acciones habilita |
| [docs/dashboard_looker_studio.md](docs/dashboard_looker_studio.md) | Cómo armar el dashboard: conexión a BigQuery y qué gráfico usar con cada tabla |

---

## Preguntas de negocio respondidas

| Mart | Pregunta |
|---|---|
| `agg_ventas_ciudad` | ¿Qué ciudades y estados generan más ingresos y pedidos? |
| `agg_ticket_estado` | ¿Cuál es el valor promedio de compra por estado? ¿Cuántas cuotas usan? |
| `agg_satisfaccion_categoria` | ¿Qué categorías de productos tienen mejor y peor puntaje? |
| `agg_tiempo_entrega` | ¿Cuánto tarda la entrega por estado? ¿Dónde hay más demoras? |
| `agg_metodos_pago` | ¿Qué métodos de pago prefieren los clientes? ¿Cuánto mueven? |
| `agg_rendimiento_vendedores` | ¿Qué vendedores generan más ingresos, entregan más rápido/a tiempo y reciben mejores reseñas? |
| `agg_puntualidad_satisfaccion` | ¿Cuánto cae la satisfacción del cliente a medida que la entrega se atrasa respecto a lo estimado? |
| `agg_rentabilidad_flete` | ¿En qué categorías el costo de flete (según peso/volumen) erosiona más los ingresos? |
| `agg_ventas_mensual` | ¿Cómo evolucionan ingresos, pedidos y clientes mes a mes? |
| `agg_estados_pedido` | ¿Qué porcentaje de las órdenes se cancelan o no llegan a entregarse? |
| `dim_clientes` | ¿Qué proporción de clientes vuelve a comprar? ¿Cuánto hace que no compran? |
| `rpt_resumen_ejecutivo` | ¿Cuáles son los KPIs de cabecera del negocio en una sola fila (ingresos, AOV, on-time, reseñas, recompra, cancelación)? |
| `agg_distancia_entrega` | ¿La distancia entre cliente y vendedor afecta el costo de flete, el tiempo de entrega y la satisfacción? |
| `agg_take_rate` | Como marketplace, ¿cuánto factura realmente la plataforma sobre el GMV que circula? |
| `agg_tiempo_entrega` | ¿Qué parte de la demora es responsabilidad del vendedor y qué parte del courier? |

---

## Tests de calidad de datos

El proyecto cuenta con **194 tests** distribuidos en tres capas (staging, intermediate y marts):

- `unique` y `not_null` en todas las claves primarias, incluyendo el grano de cada mart
- `accepted_values` en columnas categóricas (`order_status`, `puntaje`, `tipo_pago`)
- `relationships` para validar integridad referencial entre modelos (FK checks)
- `not_null` en métricas críticas de los marts
- Tests singulares en `tests/`: `assert_rpt_resumen_ejecutivo_una_fila` (la tabla de KPIs debe
  tener exactamente una fila) y `assert_tasas_entre_0_y_1` (toda tasa/proporción debe estar entre
  0 y 1 — detecta errores de grano por el fan-out del join con `order_items`)

---

## Cómo ejecutar este proyecto

### 1. Prerrequisitos

- Python 3.9+
- Cuenta de Google Cloud con BigQuery habilitado
- gcloud CLI autenticado (Application Default Credentials) o, alternativamente, un archivo de credenciales de service account (`.json`)

### 2. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/mi_proyecto_datos.git
cd mi_proyecto_datos
```

### 3. Crear y activar el entorno virtual

```bash
python3 -m venv venv
source venv/bin/activate
```

### 4. Instalar dependencias

```bash
pip install dbt-bigquery==1.10.2
dbt deps
```

### 5. Configurar el perfil de dbt

Copiar el archivo de ejemplo y completar con tus credenciales:

```bash
cp profiles.example.yml ~/.dbt/profiles.yml
```

Editar `~/.dbt/profiles.yml` con tu `project` y `dataset`. Por defecto usa `method: oauth`
(Application Default Credentials), así que no requiere un `keyfile`; alcanza con haber
corrido `gcloud auth application-default login`. El archivo incluye, comentada, la
alternativa con `service-account` + `keyfile` por si la preferís.

### 6. Cargar los datos crudos

Descargá el dataset desde [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) y colocá los CSV en `datasets_kaggle/`.

Copiá el archivo de ejemplo y completá tus valores:

```bash
cp .env.example .env
```

El script soporta dos métodos de autenticación con GCP:

**Opción A — Service account key file** (completá `GCP_KEYFILE` en `.env`):
```
GCP_PROJECT=your-gcp-project-id
GCP_DATASET=dbt_staging
GCP_KEYFILE=keys/your-service-account.json
```

**Opción B — Application Default Credentials** (recomendado, no requiere key file):
```bash
gcloud auth application-default login
```
Dejá `GCP_KEYFILE` sin definir en `.env` y el script usa tus credenciales de `gcloud` automáticamente.

Luego ejecutá:
```bash
python upload_to_bigquery.py
```

### 7. Ejecutar el pipeline

```bash
dbt run      # construye todos los modelos
dbt test     # ejecuta los 194 tests de calidad
```

### 8. Explorar la documentación

```bash
dbt docs generate
dbt docs serve
```

Abre `http://localhost:8080` para ver el lineage graph completo.

---

## Estructura del proyecto

```
mi_proyecto_datos/
├── models/
│   ├── sources.yml              # Definición de fuentes raw
│   ├── staging/
│   │   ├── stg_*.sql            # 8 modelos de staging
│   │   └── stg_olist.yml        # Tests y docs de staging
│   ├── intermediate/
│   │   ├── int_*.sql            # Agregaciones reutilizables entre marts
│   │   └── intermediate.yml     # Tests y docs de intermediate
│   └── marts/
│       ├── fct_*.sql            # 14 tablas de hechos
│       └── marts.yml            # Tests y docs de marts
├── upload_to_bigquery.py        # Script de carga de CSVs
├── packages.yml                 # Dependencias dbt (dbt-utils)
├── profiles.example.yml         # Plantilla de configuración
└── dbt_project.yml              # Configuración del proyecto
```
