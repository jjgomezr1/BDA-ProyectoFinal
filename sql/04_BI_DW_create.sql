/*******************************************************************************
   PROYECTO 3 - SISTEMAS DE INFORMACIÓN (SI3009)
   SCRIPT: Creación del Data Warehouse dimensional
   Base de datos: BI_DW
   Persona 2 — Staging, DW & ETL

   MODELO: Esquema estrella (Star Schema)
   - 9 Dimensiones: DimFecha, DimCliente, DimProducto, DimTienda,
                    DimVendedor, DimProveedor, DimCanalVenta,
                    DimPromocion, DimGeografia
   - 6 Tablas de Hechos: FactVentas, FactInventarioDiario,
                          FactMetasComerciales, FactDevoluciones,
                          FactCompras, FactRentabilidad

   DECISIONES DE DISEÑO:
   - Surrogate Keys (SK) como PK de cada dimensión, independientes del OLTP.
   - SCD Tipo 2 en DimCliente y DimProducto (FechaInicioVigencia,
     FechaFinVigencia, EsRegistroActual).
   - DimFecha poblada por procedimiento (sin depender del OLTP).
   - Medidas aditivas en hechos de ventas/compras.
   - Medidas semi-aditivas en hechos de inventario (no se suman entre tiendas).
   - FactRentabilidad como tabla de hechos derivada (calculada en ETL).
*******************************************************************************/

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BI_DW')
    CREATE DATABASE BI_DW;
GO

USE BI_DW;
GO

-- ===========================================================================
-- DIMENSIONES
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- DimFecha
-- Granularidad: un día por fila, rango 2024-01-01 a 2026-12-31
-- Tipo: dimensión estática — no cambia, se puebla una sola vez
-- Justificación: separar la fecha en atributos (Año, Trimestre, Mes, Semana,
--   DíaSemana) permite time intelligence en Power BI sin DAX adicional.
-- No tiene SCD porque el calendario no cambia.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimFecha', 'U') IS NOT NULL DROP TABLE dbo.DimFecha;
CREATE TABLE dbo.DimFecha (
    FechaKey            INT             NOT NULL,   -- YYYYMMDD como entero: clave natural y surrogate a la vez
    Fecha               DATE            NOT NULL,
    Año                 SMALLINT        NOT NULL,
    Trimestre           TINYINT         NOT NULL,   -- 1 a 4
    NombreTrimestre     NVARCHAR(10)    NOT NULL,   -- 'Q1','Q2','Q3','Q4'
    Mes                 TINYINT         NOT NULL,   -- 1 a 12
    NombreMes           NVARCHAR(20)    NOT NULL,   -- 'Enero', 'Febrero'...
    NombreMesCorto      NVARCHAR(5)     NOT NULL,   -- 'Ene', 'Feb'...
    AñoMes              INT             NOT NULL,   -- YYYYMM — útil para agrupar por mes
    Semana              TINYINT         NOT NULL,   -- Semana ISO del año (1 a 53)
    DiaSemana           TINYINT         NOT NULL,   -- 1=Lunes ... 7=Domingo
    NombreDiaSemana     NVARCHAR(15)    NOT NULL,   -- 'Lunes', 'Martes'...
    EsFinDeSemana       BIT             NOT NULL,   -- 1 si Sábado o Domingo
    EsFestivoColombia   BIT             NOT NULL DEFAULT 0,  -- Marcado manualmente o por lista

    CONSTRAINT PK_DimFecha PRIMARY KEY (FechaKey)
);
GO

-- ---------------------------------------------------------------------------
-- DimGeografia
-- Granularidad: una fila por combinación única (Ciudad, Region, País)
-- Tipo: dimensión de referencia — no tiene SCD
-- Justificación: centralizar la geografía evita duplicar Ciudad/Region
--   en DimCliente y DimTienda. Ambas referencian esta dimensión.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimGeografia', 'U') IS NOT NULL DROP TABLE dbo.DimGeografia;
CREATE TABLE dbo.DimGeografia (
    GeografiaKey        INT             IDENTITY(1,1)   NOT NULL,
    Ciudad              NVARCHAR(100)   NOT NULL,
    Region              NVARCHAR(100)   NOT NULL,
    Pais                NVARCHAR(100)   NOT NULL DEFAULT 'Colombia',

    CONSTRAINT PK_DimGeografia PRIMARY KEY (GeografiaKey),
    CONSTRAINT UQ_DimGeografia UNIQUE (Ciudad, Region, Pais)
);
GO

-- ---------------------------------------------------------------------------
-- DimCliente
-- Granularidad: un registro por versión de cliente (SCD Tipo 2)
-- SCD Tipo 2 en: Ciudad, Region, Segmento
--   Si el cliente cambia de segmento o ciudad, se cierra el registro actual
--   (FechaFinVigencia = hoy - 1, EsRegistroActual = 0) y se inserta uno nuevo.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimCliente', 'U') IS NOT NULL DROP TABLE dbo.DimCliente;
CREATE TABLE dbo.DimCliente (
    ClienteKey              INT             IDENTITY(1,1)   NOT NULL,   -- Surrogate Key
    ClienteID_OLTP          INT             NOT NULL,                   -- NK: ID en el OLTP para el ETL
    Nombre                  NVARCHAR(100)   NOT NULL,
    Apellido                NVARCHAR(100)   NOT NULL,
    NombreCompleto          NVARCHAR(220)   NOT NULL,   -- Calculado en ETL: Nombre + ' ' + Apellido
    TipoDocumento           VARCHAR(20)     NOT NULL,
    NumeroDocumento         VARCHAR(30)     NOT NULL,
    Ciudad                  NVARCHAR(100)   NOT NULL,
    Region                  NVARCHAR(100)   NOT NULL,
    Segmento                NVARCHAR(50)    NOT NULL,
    GeografiaKey            INT             NOT NULL,   -- FK a DimGeografia

    -- Control SCD Tipo 2
    FechaInicioVigencia     DATE            NOT NULL,
    FechaFinVigencia        DATE            NULL,       -- NULL = registro activo
    EsRegistroActual        BIT             NOT NULL DEFAULT 1,

    CONSTRAINT PK_DimCliente PRIMARY KEY (ClienteKey),
    CONSTRAINT FK_DimCliente_Geo FOREIGN KEY (GeografiaKey)
        REFERENCES dbo.DimGeografia(GeografiaKey)
);
GO

-- ---------------------------------------------------------------------------
-- DimProducto
-- Granularidad: un registro por versión de producto (SCD Tipo 2)
-- SCD Tipo 2 en: PrecioVenta, PrecioCosto, NombreCategoria
--   Un cambio de precio genera una nueva versión del producto.
--   Las ventas históricas quedan vinculadas al precio que tenía en ese momento.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimProducto', 'U') IS NOT NULL DROP TABLE dbo.DimProducto;
CREATE TABLE dbo.DimProducto (
    ProductoKey             INT             IDENTITY(1,1)   NOT NULL,
    ProductoID_OLTP         INT             NOT NULL,
    CodigoProducto          VARCHAR(50)     NOT NULL,
    NombreProducto          NVARCHAR(150)   NOT NULL,
    Descripcion             NVARCHAR(500)   NULL,
    CategoriaID_OLTP        INT             NOT NULL,
    NombreCategoria         NVARCHAR(100)   NOT NULL,
    PrecioVenta             DECIMAL(12,2)   NOT NULL,
    PrecioCosto             DECIMAL(12,2)   NOT NULL,
    MargenBruto             DECIMAL(12,2)   NOT NULL,   -- PrecioVenta - PrecioCosto, calculado en ETL
    MargenPorcentaje        DECIMAL(6,2)    NOT NULL,   -- (Margen / PrecioVenta) * 100
    UnidadMedida            NVARCHAR(50)    NOT NULL,
    StockMinimo             INT             NOT NULL,

    -- Control SCD Tipo 2
    FechaInicioVigencia     DATE            NOT NULL,
    FechaFinVigencia        DATE            NULL,
    EsRegistroActual        BIT             NOT NULL DEFAULT 1,

    CONSTRAINT PK_DimProducto PRIMARY KEY (ProductoKey)
);
GO

-- ---------------------------------------------------------------------------
-- DimTienda
-- Granularidad: una tienda por fila — SCD Tipo 1 (sobreescritura simple)
-- No aplica SCD Tipo 2 porque los cambios en tiendas son correcciones
-- administrativas, no historia de negocio relevante para el análisis.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimTienda', 'U') IS NOT NULL DROP TABLE dbo.DimTienda;
CREATE TABLE dbo.DimTienda (
    TiendaKey               INT             IDENTITY(1,1)   NOT NULL,
    TiendaID_OLTP           INT             NOT NULL,
    NombreTienda            NVARCHAR(150)   NOT NULL,
    Ciudad                  NVARCHAR(100)   NOT NULL,
    Region                  NVARCHAR(100)   NOT NULL,
    Direccion               NVARCHAR(255)   NOT NULL,
    Telefono                VARCHAR(20)     NOT NULL,
    FechaInicioOperaciones  DATE            NOT NULL,
    GeografiaKey            INT             NOT NULL,

    CONSTRAINT PK_DimTienda PRIMARY KEY (TiendaKey),
    CONSTRAINT UQ_DimTienda_OLTP UNIQUE (TiendaID_OLTP),
    CONSTRAINT FK_DimTienda_Geo FOREIGN KEY (GeografiaKey)
        REFERENCES dbo.DimGeografia(GeografiaKey)
);
GO

-- ---------------------------------------------------------------------------
-- DimVendedor
-- Granularidad: un vendedor por fila — SCD Tipo 1
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimVendedor', 'U') IS NOT NULL DROP TABLE dbo.DimVendedor;
CREATE TABLE dbo.DimVendedor (
    VendedorKey             INT             IDENTITY(1,1)   NOT NULL,
    VendedorID_OLTP         INT             NOT NULL,
    Nombre                  NVARCHAR(100)   NOT NULL,
    Apellido                NVARCHAR(100)   NOT NULL,
    NombreCompleto          NVARCHAR(220)   NOT NULL,
    TiendaAsignadaKey       INT             NOT NULL,   -- FK a DimTienda
    FechaIngreso            DATE            NOT NULL,

    CONSTRAINT PK_DimVendedor PRIMARY KEY (VendedorKey),
    CONSTRAINT UQ_DimVendedor_OLTP UNIQUE (VendedorID_OLTP),
    CONSTRAINT FK_DimVendedor_Tienda FOREIGN KEY (TiendaAsignadaKey)
        REFERENCES dbo.DimTienda(TiendaKey)
);
GO

-- ---------------------------------------------------------------------------
-- DimProveedor
-- Granularidad: un proveedor por fila — SCD Tipo 1
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimProveedor', 'U') IS NOT NULL DROP TABLE dbo.DimProveedor;
CREATE TABLE dbo.DimProveedor (
    ProveedorKey            INT             IDENTITY(1,1)   NOT NULL,
    ProveedorID_OLTP        INT             NOT NULL,
    NombreProveedor         NVARCHAR(150)   NOT NULL,
    NIT                     VARCHAR(20)     NOT NULL,
    Ciudad                  NVARCHAR(100)   NOT NULL,
    NombreContacto          NVARCHAR(150)   NOT NULL,
    Telefono                VARCHAR(20)     NOT NULL,
    GeografiaKey            INT             NOT NULL,

    CONSTRAINT PK_DimProveedor PRIMARY KEY (ProveedorKey),
    CONSTRAINT UQ_DimProveedor_OLTP UNIQUE (ProveedorID_OLTP),
    CONSTRAINT FK_DimProveedor_Geo FOREIGN KEY (GeografiaKey)
        REFERENCES dbo.DimGeografia(GeografiaKey)
);
GO

-- ---------------------------------------------------------------------------
-- DimCanalVenta
-- Granularidad: un canal por fila — dimensión pequeña (4 registros)
-- SCD Tipo 1 — los canales no cambian históricamente
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimCanalVenta', 'U') IS NOT NULL DROP TABLE dbo.DimCanalVenta;
CREATE TABLE dbo.DimCanalVenta (
    CanalVentaKey           INT             IDENTITY(1,1)   NOT NULL,
    CanalVentaID_OLTP       INT             NOT NULL,
    NombreCanal             NVARCHAR(100)   NOT NULL,
    Descripcion             NVARCHAR(255)   NULL,

    CONSTRAINT PK_DimCanalVenta PRIMARY KEY (CanalVentaKey),
    CONSTRAINT UQ_DimCanalVenta_OLTP UNIQUE (CanalVentaID_OLTP)
);
GO

-- ---------------------------------------------------------------------------
-- DimPromocion
-- Fuente: BI_OLTP.dbo.CampañasComerciales
-- Granularidad: una campaña por fila — SCD Tipo 1
-- Incluye un registro especial "Sin Promoción" (PromocionID_OLTP = -1)
-- para ventas sin campaña asociada (patrón de fila desconocida).
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.DimPromocion', 'U') IS NOT NULL DROP TABLE dbo.DimPromocion;
CREATE TABLE dbo.DimPromocion (
    PromocionKey            INT             IDENTITY(1,1)   NOT NULL,
    PromocionID_OLTP        INT             NOT NULL,   -- -1 para "Sin Promoción"
    NombrePromocion         NVARCHAR(150)   NOT NULL,
    TipoPromocion           NVARCHAR(100)   NOT NULL,
    FechaInicio             DATE            NULL,
    FechaFin                DATE            NULL,

    CONSTRAINT PK_DimPromocion PRIMARY KEY (PromocionKey),
    CONSTRAINT UQ_DimPromocion_OLTP UNIQUE (PromocionID_OLTP)
);
GO

-- Insertar la fila de "Sin Promoción" (surrogate para NULLs)
-- Se inserta directamente porque no depende del OLTP
SET IDENTITY_INSERT dbo.DimPromocion ON;
INSERT INTO dbo.DimPromocion (PromocionKey, PromocionID_OLTP, NombrePromocion, TipoPromocion, FechaInicio, FechaFin)
VALUES (-1, -1, 'Sin Promoción', 'N/A', NULL, NULL);
SET IDENTITY_INSERT dbo.DimPromocion OFF;
GO


-- ===========================================================================
-- TABLAS DE HECHOS
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- FactVentas
-- Granularidad: una fila por línea de detalle de venta (DetalleVentaID)
-- Medidas:
--   - Aditivas: Cantidad, MontoVenta, MontoCosto, MargenBruto
--     (se pueden sumar por cualquier dimensión)
--   - No aditiva: PrecioUnitario
--     (no tiene sentido sumar precios entre líneas distintas)
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.FactVentas', 'U') IS NOT NULL DROP TABLE dbo.FactVentas;
CREATE TABLE dbo.FactVentas (
    FactVentaKey            INT             IDENTITY(1,1)   NOT NULL,

    -- Claves foráneas a dimensiones
    FechaKey                INT             NOT NULL,
    ClienteKey              INT             NOT NULL,
    ProductoKey             INT             NOT NULL,
    TiendaKey               INT             NOT NULL,
    VendedorKey             INT             NOT NULL,
    CanalVentaKey           INT             NOT NULL,
    PromocionKey            INT             NOT NULL,

    -- Claves de trazabilidad al OLTP (no son FKs, son referencias de auditoría)
    VentaID_OLTP            INT             NOT NULL,
    DetalleVentaID_OLTP     INT             NOT NULL,

    -- Medidas
    Cantidad                INT             NOT NULL,
    PrecioUnitario          DECIMAL(12,2)   NOT NULL,   -- No aditiva
    MontoVenta              DECIMAL(14,2)   NOT NULL,   -- Cantidad * PrecioUnitario — aditiva
    MontoCosto              DECIMAL(14,2)   NOT NULL,   -- Cantidad * PrecioCosto del producto — aditiva
    MargenBruto             DECIMAL(14,2)   NOT NULL,   -- MontoVenta - MontoCosto — aditiva

    CONSTRAINT PK_FactVentas PRIMARY KEY (FactVentaKey),
    CONSTRAINT FK_FV_Fecha      FOREIGN KEY (FechaKey)       REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FV_Cliente    FOREIGN KEY (ClienteKey)     REFERENCES dbo.DimCliente(ClienteKey),
    CONSTRAINT FK_FV_Producto   FOREIGN KEY (ProductoKey)    REFERENCES dbo.DimProducto(ProductoKey),
    CONSTRAINT FK_FV_Tienda     FOREIGN KEY (TiendaKey)      REFERENCES dbo.DimTienda(TiendaKey),
    CONSTRAINT FK_FV_Vendedor   FOREIGN KEY (VendedorKey)    REFERENCES dbo.DimVendedor(VendedorKey),
    CONSTRAINT FK_FV_Canal      FOREIGN KEY (CanalVentaKey)  REFERENCES dbo.DimCanalVenta(CanalVentaKey),
    CONSTRAINT FK_FV_Promo      FOREIGN KEY (PromocionKey)   REFERENCES dbo.DimPromocion(PromocionKey)
);
GO

-- ---------------------------------------------------------------------------
-- FactInventarioDiario
-- Granularidad: una fila por (Fecha, Producto, Tienda)
-- Medidas:
--   - Semi-aditivas: StockInicial, StockFinal, StockPromedio
--     Se pueden sumar por fecha y producto, pero NO entre tiendas
--     (sumar el stock de 10 tiendas en un día no es significativo si el
--      inventario no es fungible entre ellas — se analiza por tienda)
--   - Aditivas: UnidadesEntrantes, UnidadesSalientes, AjusteManual
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.FactInventarioDiario', 'U') IS NOT NULL DROP TABLE dbo.FactInventarioDiario;
CREATE TABLE dbo.FactInventarioDiario (
    FactInventarioKey       INT             IDENTITY(1,1)   NOT NULL,

    FechaKey                INT             NOT NULL,
    ProductoKey             INT             NOT NULL,
    TiendaKey               INT             NOT NULL,

    InventarioID_OLTP       INT             NULL,   -- NULL si el registro viene del CSV de ajustes

    -- Medidas semi-aditivas
    StockInicial            INT             NOT NULL,
    StockFinal              INT             NOT NULL,
    StockPromedio           DECIMAL(10,2)   NOT NULL,   -- (StockInicial + StockFinal) / 2

    -- Medidas aditivas
    UnidadesEntrantes       INT             NOT NULL DEFAULT 0,
    UnidadesSalientes       INT             NOT NULL DEFAULT 0,
    AjusteManual            INT             NOT NULL DEFAULT 0,   -- Viene del CSV inventario_ajustes

    CONSTRAINT PK_FactInventario PRIMARY KEY (FactInventarioKey),
    CONSTRAINT FK_FI_Fecha      FOREIGN KEY (FechaKey)    REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FI_Producto   FOREIGN KEY (ProductoKey) REFERENCES dbo.DimProducto(ProductoKey),
    CONSTRAINT FK_FI_Tienda     FOREIGN KEY (TiendaKey)   REFERENCES dbo.DimTienda(TiendaKey)
);
GO

-- ---------------------------------------------------------------------------
-- FactMetasComerciales
-- Granularidad: una fila por (Año, Mes, Tienda, Categoría)
-- Medidas:
--   - Aditiva: ValorMeta (se puede sumar entre tiendas, categorías y meses)
-- Esta tabla se une con FactVentas en Power BI para calcular cumplimiento:
--   Cumplimiento% = SUM(MontoVenta) / SUM(ValorMeta) * 100
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.FactMetasComerciales', 'U') IS NOT NULL DROP TABLE dbo.FactMetasComerciales;
CREATE TABLE dbo.FactMetasComerciales (
    FactMetaKey             INT             IDENTITY(1,1)   NOT NULL,

    -- DimFecha a nivel de mes: se usa el FechaKey del primer día del mes
    FechaKey                INT             NOT NULL,   -- Primer día del mes: YYYYMM01
    TiendaKey               INT             NOT NULL,
    ProductoKey             INT             NOT NULL,   -- Usamos surrogate de un producto representativo de la categoría
                                                        -- En la práctica, el filtro por categoría se hace vía DimProducto.NombreCategoria
    -- Atributos de mes/año desnormalizados para facilidad de filtro
    Año                     SMALLINT        NOT NULL,
    Mes                     TINYINT         NOT NULL,
    CategoriaID_OLTP        INT             NOT NULL,
    NombreCategoria         NVARCHAR(100)   NOT NULL,

    -- Medida
    ValorMeta               DECIMAL(15,2)   NOT NULL,

    CONSTRAINT PK_FactMetas PRIMARY KEY (FactMetaKey),
    CONSTRAINT FK_FM_Fecha   FOREIGN KEY (FechaKey)  REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FM_Tienda  FOREIGN KEY (TiendaKey) REFERENCES dbo.DimTienda(TiendaKey)
);
GO

-- ---------------------------------------------------------------------------
-- FactDevoluciones
-- Granularidad: una fila por devolución registrada
-- Medidas:
--   - Aditivas: CantidadDevuelta, MontoDevuelto
-- Se vincula con FactVentas via VentaID_OLTP para análisis de tasas
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.FactDevoluciones', 'U') IS NOT NULL DROP TABLE dbo.FactDevoluciones;
CREATE TABLE dbo.FactDevoluciones (
    FactDevolucionKey       INT             IDENTITY(1,1)   NOT NULL,

    FechaKey                INT             NOT NULL,   -- Fecha de la devolución
    FechaVentaKey           INT             NOT NULL,   -- Fecha de la venta original
    ProductoKey             INT             NOT NULL,
    TiendaKey               INT             NOT NULL,
    ClienteKey              INT             NOT NULL,

    DevolucionID_OLTP       INT             NOT NULL,
    VentaID_OLTP            INT             NOT NULL,

    TipoDevolucion          NVARCHAR(20)    NOT NULL,
    Motivo                  NVARCHAR(255)   NOT NULL,

    -- Medidas aditivas
    CantidadDevuelta        INT             NOT NULL,
    MontoDevuelto           DECIMAL(14,2)   NOT NULL,   -- CantidadDevuelta * PrecioUnitario de la venta

    CONSTRAINT PK_FactDevoluciones PRIMARY KEY (FactDevolucionKey),
    CONSTRAINT FK_FD_Fecha      FOREIGN KEY (FechaKey)      REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FD_FechaVenta FOREIGN KEY (FechaVentaKey) REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FD_Producto   FOREIGN KEY (ProductoKey)   REFERENCES dbo.DimProducto(ProductoKey),
    CONSTRAINT FK_FD_Tienda     FOREIGN KEY (TiendaKey)     REFERENCES dbo.DimTienda(TiendaKey),
    CONSTRAINT FK_FD_Cliente    FOREIGN KEY (ClienteKey)    REFERENCES dbo.DimCliente(ClienteKey)
);
GO

-- ---------------------------------------------------------------------------
-- FactCompras
-- Granularidad: una fila por línea de detalle de compra
-- Medidas:
--   - Aditivas: Cantidad, MontoCompra
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.FactCompras', 'U') IS NOT NULL DROP TABLE dbo.FactCompras;
CREATE TABLE dbo.FactCompras (
    FactCompraKey           INT             IDENTITY(1,1)   NOT NULL,

    FechaKey                INT             NOT NULL,
    ProductoKey             INT             NOT NULL,
    TiendaKey               INT             NOT NULL,
    ProveedorKey            INT             NOT NULL,

    CompraID_OLTP           INT             NOT NULL,
    DetalleCompraID_OLTP    INT             NOT NULL,

    -- Medidas aditivas
    Cantidad                INT             NOT NULL,
    PrecioUnitario          DECIMAL(12,2)   NOT NULL,   -- No aditiva
    MontoCompra             DECIMAL(14,2)   NOT NULL,   -- Cantidad * PrecioUnitario — aditiva

    CONSTRAINT PK_FactCompras PRIMARY KEY (FactCompraKey),
    CONSTRAINT FK_FC_Fecha      FOREIGN KEY (FechaKey)      REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FC_Producto   FOREIGN KEY (ProductoKey)   REFERENCES dbo.DimProducto(ProductoKey),
    CONSTRAINT FK_FC_Tienda     FOREIGN KEY (TiendaKey)     REFERENCES dbo.DimTienda(TiendaKey),
    CONSTRAINT FK_FC_Proveedor  FOREIGN KEY (ProveedorKey)  REFERENCES dbo.DimProveedor(ProveedorKey)
);
GO

-- ---------------------------------------------------------------------------
-- FactRentabilidad
-- Granularidad: una fila por (Mes, Producto, Tienda)
-- Tabla de hechos DERIVADA — calculada en el ETL a partir de FactVentas
-- y FactCompras. No viene directamente del OLTP.
-- Medidas:
--   - Aditivas: TotalVentas, TotalCosto, MargenBruto
--   - No aditiva: MargenPorcentaje (promedio ponderado, no suma simple)
-- Justificación de granularidad mensual: el análisis de rentabilidad
--   por día es ruidoso; por mes es accionable para decisiones comerciales.
-- ---------------------------------------------------------------------------
IF OBJECT_ID('dbo.FactRentabilidad', 'U') IS NOT NULL DROP TABLE dbo.FactRentabilidad;
CREATE TABLE dbo.FactRentabilidad (
    FactRentabilidadKey     INT             IDENTITY(1,1)   NOT NULL,

    -- FechaKey apunta al primer día del mes (granularidad mensual)
    FechaKey                INT             NOT NULL,
    ProductoKey             INT             NOT NULL,
    TiendaKey               INT             NOT NULL,

    Año                     SMALLINT        NOT NULL,
    Mes                     TINYINT         NOT NULL,

    -- Medidas aditivas
    TotalVentas             DECIMAL(16,2)   NOT NULL DEFAULT 0,
    TotalCosto              DECIMAL(16,2)   NOT NULL DEFAULT 0,
    MargenBruto             DECIMAL(16,2)   NOT NULL DEFAULT 0,   -- TotalVentas - TotalCosto

    -- Medida no aditiva
    MargenPorcentaje        DECIMAL(6,2)    NOT NULL DEFAULT 0,   -- (MargenBruto / TotalVentas) * 100

    -- Contadores de apoyo
    UnidadesVendidas        INT             NOT NULL DEFAULT 0,
    NumeroTransacciones     INT             NOT NULL DEFAULT 0,

    CONSTRAINT PK_FactRentabilidad PRIMARY KEY (FactRentabilidadKey),
    CONSTRAINT FK_FR_Fecha    FOREIGN KEY (FechaKey)    REFERENCES dbo.DimFecha(FechaKey),
    CONSTRAINT FK_FR_Producto FOREIGN KEY (ProductoKey) REFERENCES dbo.DimProducto(ProductoKey),
    CONSTRAINT FK_FR_Tienda   FOREIGN KEY (TiendaKey)   REFERENCES dbo.DimTienda(TiendaKey)
);
GO

-- ===========================================================================
-- ÍNDICES DE APOYO EN TABLAS DE HECHOS
-- Los hechos se consultan siempre filtrando por dimensión y fecha.
-- ===========================================================================
CREATE NONCLUSTERED INDEX IX_FactVentas_Fecha
    ON dbo.FactVentas(FechaKey) INCLUDE (MontoVenta, MargenBruto, Cantidad);
GO
CREATE NONCLUSTERED INDEX IX_FactVentas_Producto
    ON dbo.FactVentas(ProductoKey) INCLUDE (MontoVenta, Cantidad);
GO
CREATE NONCLUSTERED INDEX IX_FactVentas_Tienda
    ON dbo.FactVentas(TiendaKey) INCLUDE (MontoVenta, FechaKey);
GO
CREATE NONCLUSTERED INDEX IX_FactInventario_Fecha_Tienda
    ON dbo.FactInventarioDiario(FechaKey, TiendaKey) INCLUDE (StockFinal, ProductoKey);
GO
CREATE NONCLUSTERED INDEX IX_FactMetas_Fecha_Tienda
    ON dbo.FactMetasComerciales(FechaKey, TiendaKey) INCLUDE (ValorMeta, CategoriaID_OLTP);
GO

PRINT '=========================================================';
PRINT '  BI_DW creado exitosamente.';
PRINT '  Dimensiones : 9';
PRINT '  Hechos      : 6';
PRINT '  Índices     : 5';
PRINT '=========================================================';
GO
