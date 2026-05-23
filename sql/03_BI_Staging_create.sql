/*******************************************************************************
   PROYECTO 3 - SISTEMAS DE INFORMACIÓN (SI3009)
   SCRIPT: Creación de Base de Datos de Staging
   Base de datos: BI_Staging
   Persona 2 — Staging, DW & ETL

   PROPÓSITO:
   Zona intermedia entre el OLTP (BI_OLTP) y el Data Warehouse (BI_DW).
   Recibe datos crudos de dos fuentes:
     1. El OLTP operacional (BI_OLTP)
     2. Archivos planos externos (CSV: metas_mensuales, inventario_ajustes)

   REGLAS DE DISEÑO DEL STAGING:
   - Sin FK entre tablas: el staging no garantiza integridad, la detecta.
   - Todos los campos son NULLABLE salvo las PKs de staging (STG_ID).
   - Tipos de dato amplios (NVARCHAR) para absorber datos sucios sin rechazar filas.
   - Campos de auditoría en cada tabla: STG_FuenteOrigen, STG_FechaCarga,
     STG_Estado ('PENDIENTE','VALIDO','RECHAZADO'), STG_MensajeError.
   - Se hace TRUNCATE antes de cada carga ETL (patrón full-refresh).
*******************************************************************************/

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BI_Staging')
    CREATE DATABASE BI_Staging;
GO

USE BI_Staging;
GO

-- ===========================================================================
-- STG_Ventas
-- Fuente: BI_OLTP.dbo.Ventas + BI_OLTP.dbo.DetalleVentas
-- Granularidad: una fila por línea de detalle de venta
-- Transformaciones esperadas:
--   - Validar que IdCliente, IdTienda, IdVendedor, IdProducto existan en OLTP
--   - Detectar fechas fuera de rango (futuras o anteriores a 2024-01-01)
--   - Verificar que Estado esté en ('Completa','Cancelada','Pendiente')
--   - Calcular Subtotal como campo derivado de validación
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Ventas', 'U') IS NOT NULL DROP TABLE dbo.STG_Ventas;
CREATE TABLE dbo.STG_Ventas (
    STG_ID                  INT             IDENTITY(1,1)   NOT NULL,

    -- Campos de la cabecera Ventas
    VentaID                 INT             NULL,
    Fecha                   NVARCHAR(50)    NULL,   -- Entra como texto para detectar formatos inválidos
    IdCliente               INT             NULL,
    IdTienda                INT             NULL,
    IdVendedor              INT             NULL,
    IdCanalVenta            INT             NULL,
    IdCampañaComercial      INT             NULL,
    EstadoVenta             NVARCHAR(50)    NULL,

    -- Campos del detalle DetalleVentas
    DetalleVentaID          INT             NULL,
    IdProducto              INT             NULL,
    Cantidad                INT             NULL,
    PrecioUnidad            DECIMAL(12,2)   NULL,
    Subtotal                DECIMAL(14,2)   NULL,   -- Calculado en ETL: Cantidad * PrecioUnidad

    -- Campos de auditoría staging
    STG_FuenteOrigen        NVARCHAR(100)   NOT NULL DEFAULT 'BI_OLTP',
    STG_FechaCarga          DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado              NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',  -- PENDIENTE | VALIDO | RECHAZADO
    STG_MensajeError        NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Ventas PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_Productos
-- Fuente: BI_OLTP.dbo.Productos JOIN dbo.Categorias
-- Granularidad: un producto por fila
-- Transformaciones esperadas:
--   - Verificar CodigoProducto único
--   - Validar que PrecioVenta >= PrecioCosto (margen positivo)
--   - Normalizar NombreCategoria contra el catálogo oficial del DW
--   - Detectar productos con StockMinimo negativo (no debería ocurrir por CK, pero se valida)
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Productos', 'U') IS NOT NULL DROP TABLE dbo.STG_Productos;
CREATE TABLE dbo.STG_Productos (
    STG_ID              INT             IDENTITY(1,1)   NOT NULL,

    ProductoID          INT             NULL,
    CodigoProducto      NVARCHAR(100)   NULL,
    NombreProducto      NVARCHAR(300)   NULL,
    Descripcion         NVARCHAR(1000)  NULL,
    CategoriaID         INT             NULL,
    NombreCategoria     NVARCHAR(200)   NULL,
    PrecioVenta         DECIMAL(12,2)   NULL,
    PrecioCosto         DECIMAL(12,2)   NULL,
    UnidadMedida        NVARCHAR(100)   NULL,
    StockMinimo         INT             NULL,

    STG_FuenteOrigen    NVARCHAR(100)   NOT NULL DEFAULT 'BI_OLTP',
    STG_FechaCarga      DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado          NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError    NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Productos PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_Clientes
-- Fuente: BI_OLTP.dbo.Clientes
-- Granularidad: un cliente por fila
-- Transformaciones esperadas:
--   - Estandarizar Ciudad y Region (trim, capitalización)
--   - Validar TipoDocumento contra lista permitida
--   - Detectar duplicados por (TipoDocumento, NumeroDocumento)
--   - Validar Segmento contra valores permitidos
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Clientes', 'U') IS NOT NULL DROP TABLE dbo.STG_Clientes;
CREATE TABLE dbo.STG_Clientes (
    STG_ID              INT             IDENTITY(1,1)   NOT NULL,

    ClienteID           INT             NULL,
    Nombre              NVARCHAR(200)   NULL,
    Apellido            NVARCHAR(200)   NULL,
    TipoDocumento       NVARCHAR(50)    NULL,
    NumeroDocumento     NVARCHAR(100)   NULL,
    Ciudad              NVARCHAR(200)   NULL,
    Region              NVARCHAR(200)   NULL,
    Segmento            NVARCHAR(100)   NULL,
    FechaRegistro       NVARCHAR(50)    NULL,   -- Texto para detectar formatos inválidos

    STG_FuenteOrigen    NVARCHAR(100)   NOT NULL DEFAULT 'BI_OLTP',
    STG_FechaCarga      DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado          NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError    NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Clientes PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_Inventario
-- Fuente: BI_OLTP.dbo.InventarioDiario
-- Granularidad: una fila por (Fecha, Producto, Tienda)
-- Transformaciones esperadas:
--   - Verificar consistencia matemática: StockFinal = StockInicial + Entrantes - Salientes
--   - Detectar stocks negativos
--   - Validar que Fecha esté dentro del rango del proyecto
--   - Verificar que IdProducto e IdTienda existan en OLTP
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Inventario', 'U') IS NOT NULL DROP TABLE dbo.STG_Inventario;
CREATE TABLE dbo.STG_Inventario (
    STG_ID                  INT             IDENTITY(1,1)   NOT NULL,

    InventarioID            INT             NULL,
    Fecha                   NVARCHAR(50)    NULL,
    IdProducto              INT             NULL,
    IdTienda                INT             NULL,
    StockInicial            INT             NULL,
    StockFinal              INT             NULL,
    UnidadesEntrantes       INT             NULL,
    UnidadesSalientes       INT             NULL,
    -- Campo derivado de validación
    ConsistenciaCalculada   INT             NULL,   -- StockInicial + Entrantes - Salientes (para comparar con StockFinal)

    STG_FuenteOrigen        NVARCHAR(100)   NOT NULL DEFAULT 'BI_OLTP',
    STG_FechaCarga          DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado              NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError        NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Inventario PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_Metas
-- Fuente EXTERNA: CSV metas_mensuales.csv
-- Granularidad: una fila por (Año, Mes, Tienda, Categoría)
-- Transformaciones esperadas:
--   - Mapear NombreCategoria del CSV al CategoriaID real del OLTP
--     (el CSV usa nombres distintos: "Electrónica" -> CategoriaID 1 "Tecnología")
--   - Validar que TiendaID del CSV corresponda a una tienda real en OLTP
--   - Verificar que Año/Mes sean valores válidos
--   - Detectar duplicados por (Año, Mes, TiendaID, CategoriaID mapeada)
--   - Rechazar ValorMeta <= 0
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Metas', 'U') IS NOT NULL DROP TABLE dbo.STG_Metas;
CREATE TABLE dbo.STG_Metas (
    STG_ID                  INT             IDENTITY(1,1)   NOT NULL,

    -- Columnas tal como vienen del CSV
    Año                     NVARCHAR(10)    NULL,
    Mes                     NVARCHAR(10)    NULL,
    TiendaID_CSV            INT             NULL,   -- ID del CSV (puede no coincidir con OLTP)
    NombreTienda_CSV        NVARCHAR(200)   NULL,
    CategoriaID_CSV         INT             NULL,   -- ID del CSV
    NombreCategoria_CSV     NVARCHAR(200)   NULL,   -- Nombre usado en el CSV (puede diferir del OLTP)
    ValorMeta               NVARCHAR(50)    NULL,   -- Texto para detectar no numéricos

    -- Campos resueltos por el ETL (después de la transformación)
    TiendaID_Resuelto       INT             NULL,   -- TiendaID validado contra BI_OLTP
    CategoriaID_Resuelto    INT             NULL,   -- CategoriaID mapeado contra BI_OLTP

    STG_FuenteOrigen        NVARCHAR(100)   NOT NULL DEFAULT 'CSV_Metas',
    STG_FechaCarga          DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado              NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError        NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Metas PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_Devoluciones
-- Fuente: BI_OLTP.dbo.Devoluciones
-- Granularidad: una devolución por fila
-- Transformaciones esperadas:
--   - Validar que IdVenta exista en Ventas OLTP
--   - Validar que IdProducto exista y haya estado en el detalle de esa venta
--   - Verificar que Fecha devolución >= Fecha venta (no puede devolver antes de comprar)
--   - Validar TipoDevolucion contra valores permitidos
--   - Detectar duplicados (misma venta, mismo producto)
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Devoluciones', 'U') IS NOT NULL DROP TABLE dbo.STG_Devoluciones;
CREATE TABLE dbo.STG_Devoluciones (
    STG_ID              INT             IDENTITY(1,1)   NOT NULL,

    DevolucionID        INT             NULL,
    Fecha               NVARCHAR(50)    NULL,
    IdVenta             INT             NULL,
    IdProducto          INT             NULL,
    Cantidad            INT             NULL,
    Motivo              NVARCHAR(500)   NULL,
    TipoDevolucion      NVARCHAR(50)    NULL,

    -- Campo derivado de validación cruzada
    FechaVentaOrigen    DATE            NULL,   -- Poblado por el ETL para comparar con Fecha devolución

    STG_FuenteOrigen    NVARCHAR(100)   NOT NULL DEFAULT 'BI_OLTP',
    STG_FechaCarga      DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado          NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError    NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Devoluciones PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_Compras
-- Fuente: BI_OLTP.dbo.Compras + BI_OLTP.dbo.DetalleCompras
-- Granularidad: una fila por línea de detalle de compra
-- Transformaciones esperadas:
--   - Validar que IdProveedor e IdTienda existan en OLTP
--   - Verificar que PrecioUnidad coincida con PrecioCosto del producto en OLTP
--   - Detectar fechas futuras o fuera del rango del proyecto
--   - Calcular Subtotal como campo derivado de validación
-- ===========================================================================
IF OBJECT_ID('dbo.STG_Compras', 'U') IS NOT NULL DROP TABLE dbo.STG_Compras;
CREATE TABLE dbo.STG_Compras (
    STG_ID                  INT             IDENTITY(1,1)   NOT NULL,

    -- Campos cabecera Compras
    CompraID                INT             NULL,
    FechaCompra             NVARCHAR(50)    NULL,
    IdProveedor             INT             NULL,
    NombreProveedor         NVARCHAR(300)   NULL,   -- Desnormalizado del OLTP para auditoría
    IdTienda                INT             NULL,
    EstadoCompra            NVARCHAR(50)    NULL,

    -- Campos detalle DetalleCompras
    DetalleCompraID         INT             NULL,
    IdProducto              INT             NULL,
    Cantidad                INT             NULL,
    PrecioUnidad            DECIMAL(12,2)   NULL,
    Subtotal                DECIMAL(14,2)   NULL,   -- Calculado en ETL

    STG_FuenteOrigen        NVARCHAR(100)   NOT NULL DEFAULT 'BI_OLTP',
    STG_FechaCarga          DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado              NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError        NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_Compras PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- STG_AjustesInventario
-- Fuente EXTERNA: CSV inventario_ajustes.csv
-- Granularidad: una fila por ajuste manual registrado
-- Transformaciones esperadas:
--   - Validar que TiendaID exista en OLTP
--   - Validar que ProductoID exista en OLTP
--   - Verificar que Ajuste != 0 (el CSV incluye ajustes de 0 que son ruido)
--   - Clasificar Ajuste como positivo (entrada/exceso) o negativo (merma/vencimiento)
--   - Normalizar campo Motivo para agrupar en categorías analíticas
-- ===========================================================================
IF OBJECT_ID('dbo.STG_AjustesInventario', 'U') IS NOT NULL DROP TABLE dbo.STG_AjustesInventario;
CREATE TABLE dbo.STG_AjustesInventario (
    STG_ID                  INT             IDENTITY(1,1)   NOT NULL,

    -- Columnas tal como vienen del CSV
    Año                     NVARCHAR(10)    NULL,
    Mes                     NVARCHAR(10)    NULL,
    TiendaID_CSV            INT             NULL,
    NombreTienda_CSV        NVARCHAR(200)   NULL,
    ProductoID_CSV          INT             NULL,
    StockFisico             INT             NULL,
    StockSistema            INT             NULL,
    Ajuste                  INT             NULL,
    Motivo                  NVARCHAR(500)   NULL,

    -- Campos derivados por el ETL
    TipoAjuste              NVARCHAR(20)    NULL,   -- 'POSITIVO' | 'NEGATIVO' | 'NEUTRO'
    MotivoCategorizado      NVARCHAR(100)   NULL,   -- 'Merma','Vencimiento','Transferencia','Error Sistema','Exceso'

    STG_FuenteOrigen        NVARCHAR(100)   NOT NULL DEFAULT 'CSV_AjustesInventario',
    STG_FechaCarga          DATETIME        NOT NULL DEFAULT GETDATE(),
    STG_Estado              NVARCHAR(20)    NOT NULL DEFAULT 'PENDIENTE',
    STG_MensajeError        NVARCHAR(500)   NULL,

    CONSTRAINT PK_STG_AjustesInventario PRIMARY KEY (STG_ID)
);
GO

-- ===========================================================================
-- ETL_Log
-- Registra la ejecución de cada procedimiento ETL
-- Una fila por ejecución de procedimiento
-- ===========================================================================
IF OBJECT_ID('dbo.ETL_Log', 'U') IS NOT NULL DROP TABLE dbo.ETL_Log;
CREATE TABLE dbo.ETL_Log (
    LogID               INT             IDENTITY(1,1)   NOT NULL,
    NombreProceso       NVARCHAR(200)   NOT NULL,
    FechaInicio         DATETIME        NOT NULL,
    FechaFin            DATETIME        NULL,
    Estado              NVARCHAR(20)    NOT NULL DEFAULT 'EN EJECUCION',  -- EN EJECUCION | EXITOSO | FALLIDO
    RegistrosLeidos     INT             NULL DEFAULT 0,
    RegistrosCargados   INT             NULL DEFAULT 0,
    RegistrosRechazados INT             NULL DEFAULT 0,
    MensajeError        NVARCHAR(1000)  NULL,

    CONSTRAINT PK_ETL_Log PRIMARY KEY (LogID),
    CONSTRAINT CK_ETL_Log_Estado CHECK (Estado IN ('EN EJECUCION', 'EXITOSO', 'FALLIDO'))
);
GO

PRINT '=========================================================';
PRINT '  BI_Staging creado exitosamente.';
PRINT '  Tablas staging : 7 (STG_Ventas, STG_Productos,';
PRINT '                      STG_Clientes, STG_Inventario,';
PRINT '                      STG_Metas, STG_Devoluciones,';
PRINT '                      STG_Compras, STG_AjustesInventario)';
PRINT '  Tabla de log   : 1 (ETL_Log)';
PRINT '=========================================================';
GO
