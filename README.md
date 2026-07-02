# Pipeline ELT con dbt Core y BigQuery — Olist Brazilian E-Commerce

Pipeline de datos end-to-end que transforma datos crudos del e-commerce brasileño Olist en tablas analíticas listas para dashboards. Construido con dbt Core y Google BigQuery.

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
│  stg_sellers                                │
│                                             │
│  · Renombrado de columnas                   │
│  · Cast de tipos (timestamps, ints)         │
│  · Deduplicación (reviews)                  │
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
│                MARTS (tables)               │
│  fct_ventas_por_ciudad                      │
│  fct_ticket_promedio                        │
│  fct_satisfaccion_por_categoria             │
│  fct_tiempo_entrega                         │
│  fct_metodos_pago                           │
│  fct_rendimiento_vendedores                 │
│  fct_entrega_puntualidad_satisfaccion       │
│  fct_rentabilidad_categoria_flete           │
└─────────────────────────────────────────────┘
      │
      ▼
  Looker Studio / BI
```

---

## Preguntas de negocio respondidas

| Mart | Pregunta |
|---|---|
| `fct_ventas_por_ciudad` | ¿Qué ciudades y estados generan más ingresos y pedidos? |
| `fct_ticket_promedio` | ¿Cuál es el valor promedio de compra por estado? ¿Cuántas cuotas usan? |
| `fct_satisfaccion_por_categoria` | ¿Qué categorías de productos tienen mejor y peor puntaje? |
| `fct_tiempo_entrega` | ¿Cuánto tarda la entrega por estado? ¿Dónde hay más demoras? |
| `fct_metodos_pago` | ¿Qué métodos de pago prefieren los clientes? ¿Cuánto mueven? |
| `fct_rendimiento_vendedores` | ¿Qué vendedores generan más ingresos, entregan más rápido/a tiempo y reciben mejores reseñas? |
| `fct_entrega_puntualidad_satisfaccion` | ¿Cuánto cae la satisfacción del cliente a medida que la entrega se atrasa respecto a lo estimado? |
| `fct_rentabilidad_categoria_flete` | ¿En qué categorías el costo de flete (según peso/volumen) erosiona más los ingresos? |

---

## Tests de calidad de datos

El proyecto cuenta con **67 tests** distribuidos en tres capas (staging, intermediate y marts):

- `unique` y `not_null` en todas las claves primarias, incluyendo el grano de cada mart
- `accepted_values` en columnas categóricas (`order_status`, `puntaje`, `tipo_pago`)
- `relationships` para validar integridad referencial entre modelos (FK checks)
- `not_null` en métricas críticas de los marts

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
dbt test     # ejecuta los 67 tests de calidad
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
│   │   ├── stg_*.sql            # 7 modelos de staging
│   │   └── stg_olist.yml        # Tests y docs de staging
│   ├── intermediate/
│   │   ├── int_*.sql            # Agregaciones reutilizables entre marts
│   │   └── intermediate.yml     # Tests y docs de intermediate
│   └── marts/
│       ├── fct_*.sql            # 8 tablas de hechos
│       └── marts.yml            # Tests y docs de marts
├── upload_to_bigquery.py        # Script de carga de CSVs
├── packages.yml                 # Dependencias dbt (dbt-utils)
├── profiles.example.yml         # Plantilla de configuración
└── dbt_project.yml              # Configuración del proyecto
```
