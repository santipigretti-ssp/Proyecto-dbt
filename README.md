# 🚀 Pipeline de Ingeniería de Datos con dbt & BigQuery

Este proyecto demuestra un ciclo completo de **Ingeniería de Datos (ELT)** utilizando herramientas modernas y gratuitas. Transformamos datos crudos de un e-commerce brasileño (Olist) en tablas de hechos listas para análisis de negocio.

## 📊 Resumen del Proyecto
El objetivo principal fue construir un pipeline robusto que limpie, relacione y valide datos de ventas, permitiendo identificar ingresos y volumen de pedidos por ubicación geográfica.

## 🛠️ Stack Tecnológico
- **Almacenamiento:** [Google BigQuery](https://google.com) (Sandbox Gratuito).
- **Transformación:** [dbt Core](https://getdbt.com) (v1.11).
- **IDE:** VS Code con **dbt Power User**.
- **Control de Versiones:** Git & GitHub.
- **Dataset:** Olist Brazilian E-Commerce (Kaggle).

## 🏗️ Arquitectura de Modelado
El proyecto sigue las mejores prácticas de dbt organizando el código en capas:

1.  **Capa Staging:** 
    - Limpieza de datos crudos (`raw_`).
    - Renombrado de columnas a lenguaje de negocio.
    - Transformación de formatos (Fechas/Timestamps).
2.  **Capa Marts:**
    - Generación de tablas de hechos (`fct_ventas_por_ciudad`).
    - Uniones (JOINs) entre Órdenes, Clientes e Ítems de venta.
    - Agregaciones de métricas clave: *Ingresos Totales* y *Gastos de Envío*.

## 🧪 Calidad y Documentación
- **Tests de Integridad:** Se aplican pruebas de `unique` y `not_null` en IDs críticos para asegurar que no existan duplicados ni datos perdidos.
- **Documentación Automática:** Generada mediante `dbt docs`, incluyendo descripciones de columnas y el gráfico de **Linaje de Datos** para trazabilidad total.

## 🚀 Cómo ejecutar este proyecto
1. Clonar el repositorio.
2. Configurar un entorno virtual de Python: `python -m venv dbt-env`.
3. Instalar dependencias: `pip install dbt-bigquery`.
4. Configurar el archivo `profiles.yml` con tus credenciales de BigQuery.
5. Ejecutar los modelos: `dbt run`.
6. Validar datos: `dbt test`.
