# Proyecto de Ingeniería de Datos: E-commerce Olist con dbt

Este proyecto implementa un pipeline de transformación de datos (ELT) utilizando **dbt Core** y **Google BigQuery** sobre el dataset público de Olist (Brasil).

## 🛠️ Herramientas utilizadas
*   **Data Warehouse:** Google BigQuery (Sandbox gratuito).
*   **Transformación:** dbt Core (v1.x).
*   **IDE:** VS Code con extensión dbt Power User.
*   **Lenguaje:** SQL + Jinja.

## 🏗️ Arquitectura de Capas
1.  **Staging:** Limpieza inicial, renombrado de columnas y casteo de tipos de datos.
2.  **Marts:** Generación de tablas de hechos (`fct_ventas_por_ciudad`) listas para visualización.

## 🧪 Calidad de Datos
Se implementaron tests de integridad (unique, not_null) para asegurar que los IDs de órdenes y clientes no tengan duplicados ni vacíos.