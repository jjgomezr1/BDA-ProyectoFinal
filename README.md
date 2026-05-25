# Proyecto 3 - Bases de Datos Avanzadas
**Proceso de Ejecución del ETL y Data Warehouse**

**Integrantes del grupo:**
- Samuel Herrera Hoyos
- Juan José Gómez Ramirez
- Mateo Villada Higuita

Este repositorio contiene los scripts necesarios para crear y poblar el Data Warehouse a partir de la base de datos transaccional (OLTP) y archivos CSV externos.

Para que el proyecto se ejecute correctamente en una nueva máquina, sigue **estrictamente** estos pasos en el orden indicado:

## Requisitos Previos

1. **Ubicación de los CSV:**
   Antes de ejecutar cualquier script, debes copiar los archivos CSV (`metas_mensuales.csv` e `inventario_ajustes.csv`) que se encuentran en la carpeta `csv/` del repositorio, y pegarlos **exactamente** en la ruta `C:\DatosBI\`.
   > **Nota:** Si la carpeta `C:\DatosBI\` no existe en tu computadora, debes crearla. Esto evita errores de permisos que SQL Server suele tener con otras carpetas (como Descargas o Escritorio).

---

## Pasos de Ejecución (En SSMS)

Abre SQL Server Management Studio (SSMS) y ejecuta los siguientes scripts ubicados en la carpeta `sql/` **en este orden exacto**:

### Paso 1: Creación de la Base de Datos Transaccional (OLTP)
- **Abre y ejecuta:** `01_OLTP_create.sql`
- **¿Qué hace?** Crea la base de datos `BI_OLTP` y todas las tablas del sistema transaccional de origen.

### Paso 2: Generación de Datos Sintéticos
- **Abre y ejecuta:** `02_datos_sinteticos.sql`
- **¿Qué hace?** Puebla el sistema transaccional con datos históricos simulados (compras, ventas, inventarios, etc.).

### Paso 3: Creación del Staging Area
- **Abre y ejecuta:** `03_BI_Staging_create.sql`
- **¿Qué hace?** Crea la base de datos `BI_Staging` vacía con las tablas y la estructura de logs necesarias para la extracción.

### Paso 4: Creación del Data Warehouse
- **Abre y ejecuta:** `04_BI_DW_create.sql`
- **¿Qué hace?** Crea la base de datos `BI_DW` vacía, con su modelo de estrella (tablas de Dimensiones y Hechos) y todas las llaves foráneas.
- *Nota: Si ya tenías la BD creada con errores previos, el script arrojará error. En ese caso, ejecuta en la base de datos `master`: `ALTER DATABASE BI_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE BI_DW;` y vuelve a correr el script 04.*

### Paso 5: Carga de Staging y Dimensiones
- **Abre y ejecuta:** `05_ETL_Parte1_Staging_y_Dimensiones.sql`
- **¿Qué hace?** Crea los procedimientos almacenados (Stored Procedures) que extraen la información del OLTP hacia Staging. En este script está programado el `BULK INSERT` automático que lee los CSV desde `C:\DatosBI\`. También crea la lógica para llenar las tablas de Dimensiones (aplicando SCD Tipo 2 donde corresponde).

### Paso 6: Carga de Hechos y Orquestador
- **Abre y ejecuta:** `06_ETL_Parte2_Hechos_Orquestacion.sql`
- **¿Qué hace?** Crea los procedimientos para llenar las tablas de Hechos a partir de la data que ya esté en Staging. Finalmente, crea el SP maestro llamado `sp_OrquestadorPipeline`.

### Paso 7: Ejecución del Pipeline (¡El paso final!)
- Abre una nueva ventana de query, asegúrate de estar parado en la base de datos `BI_DW` y ejecuta:
  ```sql
  USE BI_DW;
  EXEC dbo.sp_OrquestadorPipeline;
  ```
- **¿Qué hace?** Este comando dispara automáticamente en cadena todo el flujo: Carga Staging > Valida Calidad > Carga Dimensiones > Carga Hechos.

---

## Verificación

Una vez finalizado el pipeline, puedes verificar el reporte de logs para confirmar que todo fue exitoso:

```sql
SELECT * FROM BI_Staging.dbo.ETL_Log ORDER BY LogID DESC;
```
Y revisar el total de registros en las tablas de hechos:
```sql
SELECT 'FactVentas' AS Tabla, COUNT(*) AS Total FROM BI_DW.dbo.FactVentas
UNION ALL SELECT 'FactCompras', COUNT(*) FROM BI_DW.dbo.FactCompras;
```
