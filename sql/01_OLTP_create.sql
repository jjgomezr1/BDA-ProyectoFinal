-- Crear y seleccionar la base de datos
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BI_OLTP')
    CREATE DATABASE BI_OLTP;
GO

USE BI_OLTP;
GO
-- TABLAS MAESTRAS (sin dependencias externas)
-- Categorias
IF OBJECT_ID('dbo.Categorias', 'U') IS NULL
CREATE TABLE dbo.Categorias (
    CategoriaID   INT           IDENTITY(1,1)  NOT NULL,
    Nombre        NVARCHAR(100) NOT NULL,
    Descripcion   NVARCHAR(255) NULL,
    CONSTRAINT PK_Categorias PRIMARY KEY (CategoriaID),
    CONSTRAINT UQ_Categorias_Nombre UNIQUE (Nombre)
);
GO
-- Proveedores
IF OBJECT_ID('dbo.Proveedores', 'U') IS NULL
CREATE TABLE dbo.Proveedores (
    ProveedorID                  INT           IDENTITY(1,1)  NOT NULL,
    Nombre                       NVARCHAR(150) NOT NULL,
    NumeroIdentificacionTributaria VARCHAR(20)  NOT NULL,
    Ciudad                       NVARCHAR(100) NOT NULL,
    NombreContacto               NVARCHAR(150) NOT NULL,
    Telefono                     VARCHAR(20)   NOT NULL,
    CONSTRAINT PK_Proveedores PRIMARY KEY (ProveedorID),
    CONSTRAINT UQ_Proveedores_NIT UNIQUE (NumeroIdentificacionTributaria)
);
GO
-- Tiendas
IF OBJECT_ID('dbo.Tiendas', 'U') IS NULL
CREATE TABLE dbo.Tiendas (
    TiendaID               INT           IDENTITY(1,1)  NOT NULL,
    Nombre                 NVARCHAR(150) NOT NULL,
    Ciudad                 NVARCHAR(100) NOT NULL,
    Region                 NVARCHAR(100) NOT NULL,
    Direccion              NVARCHAR(255) NOT NULL,
    Telefono               VARCHAR(20)   NOT NULL,
    FechaInicioOperaciones DATE          NOT NULL,
    CONSTRAINT PK_Tiendas PRIMARY KEY (TiendaID),
    CONSTRAINT CK_Tiendas_FechaInicio CHECK (FechaInicioOperaciones <= CAST(GETDATE() AS DATE))
);
GO
-- CanalVenta
IF OBJECT_ID('dbo.CanalVenta', 'U') IS NULL
CREATE TABLE dbo.CanalVenta (
    CanalVentaID  INT           IDENTITY(1,1)  NOT NULL,
    Nombre        NVARCHAR(100) NOT NULL,
    Descripcion   NVARCHAR(255) NULL,
    CONSTRAINT PK_CanalVenta PRIMARY KEY (CanalVentaID),
    CONSTRAINT UQ_CanalVenta_Nombre UNIQUE (Nombre)
);
GO
-- CampañasComerciales
IF OBJECT_ID('dbo.CampañasComerciales', 'U') IS NULL
CREATE TABLE dbo.CampañasComerciales (
    CampañaID    INT           IDENTITY(1,1)  NOT NULL,
    Nombre       NVARCHAR(150) NOT NULL,
    FechaInicio  DATE          NOT NULL,
    FechaFin     DATE          NOT NULL,
    TipoCampaña  NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_CampañasComerciales PRIMARY KEY (CampañaID),
    CONSTRAINT CK_Campañas_Fechas CHECK (FechaFin >= FechaInicio)
);
GO
-- TABLAS CON DEPENDENCIAS DE PRIMER NIVEL
-- Clientes
IF OBJECT_ID('dbo.Clientes', 'U') IS NULL
CREATE TABLE dbo.Clientes (
    ClienteID        INT           IDENTITY(1,1)  NOT NULL,
    Nombre           NVARCHAR(100) NOT NULL,
    Apellido         NVARCHAR(100) NOT NULL,
    TipoDocumento    VARCHAR(20)   NOT NULL,
    NumeroDocumento  VARCHAR(30)   NOT NULL,
    Ciudad           NVARCHAR(100) NOT NULL,
    Region           NVARCHAR(100) NOT NULL,
    Segmento         NVARCHAR(50)  NOT NULL,
    FechaRegistro    DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT PK_Clientes PRIMARY KEY (ClienteID),
    CONSTRAINT UQ_Clientes_Documento UNIQUE (TipoDocumento, NumeroDocumento),
    CONSTRAINT CK_Clientes_TipoDoc CHECK (TipoDocumento IN ('CC', 'NIT', 'CE', 'Pasaporte', 'TI')),
    CONSTRAINT CK_Clientes_Segmento CHECK (Segmento IN ('Minorista', 'Mayorista', 'Corporativo', 'VIP', 'Regular'))
);
GO
-- Productos  (depende de Categorias)
IF OBJECT_ID('dbo.Productos', 'U') IS NULL
CREATE TABLE dbo.Productos (
    ProductoID      INT            IDENTITY(1,1)  NOT NULL,
    Nombre          NVARCHAR(150)  NOT NULL,
    Descripcion     NVARCHAR(500)  NULL,
    CategoriaID     INT            NOT NULL,
    PrecioVenta     DECIMAL(12,2)  NOT NULL,
    PrecioCosto     DECIMAL(12,2)  NOT NULL,
    CodigoProducto  VARCHAR(50)    NOT NULL,
    UnidadMedida    NVARCHAR(50)   NOT NULL,
    StockMinimo     INT            NOT NULL DEFAULT 0,
    CONSTRAINT PK_Productos PRIMARY KEY (ProductoID),
    CONSTRAINT UQ_Productos_Codigo UNIQUE (CodigoProducto),
    CONSTRAINT FK_Productos_Categoria FOREIGN KEY (CategoriaID)
        REFERENCES dbo.Categorias(CategoriaID),
    CONSTRAINT CK_Productos_PrecioVenta CHECK (PrecioVenta > 0),
    CONSTRAINT CK_Productos_PrecioCosto CHECK (PrecioCosto > 0),
    CONSTRAINT CK_Productos_StockMinimo CHECK (StockMinimo >= 0),
    CONSTRAINT CK_Productos_Margen     CHECK (PrecioVenta >= PrecioCosto)
);
GO
-- Vendedores  (depende de Tiendas)
IF OBJECT_ID('dbo.Vendedores', 'U') IS NULL
CREATE TABLE dbo.Vendedores (
    VendedorID       INT           IDENTITY(1,1)  NOT NULL,
    Nombre           NVARCHAR(100) NOT NULL,
    Apellido         NVARCHAR(100) NOT NULL,
    IdTiendaAsignada INT           NOT NULL,
    FechaIngreso     DATE          NOT NULL,
    CONSTRAINT PK_Vendedores PRIMARY KEY (VendedorID),
    CONSTRAINT FK_Vendedores_Tienda FOREIGN KEY (IdTiendaAsignada)
        REFERENCES dbo.Tiendas(TiendaID),
    CONSTRAINT CK_Vendedores_FechaIngreso CHECK (FechaIngreso <= CAST(GETDATE() AS DATE))
);
GO
-- TABLAS TRANSACCIONALES
-- Ventas  (depende de Clientes, Tiendas, Vendedores, CanalVenta, Campañas)
IF OBJECT_ID('dbo.Ventas', 'U') IS NULL
CREATE TABLE dbo.Ventas (
    VentaID              INT          IDENTITY(1,1)  NOT NULL,
    Fecha                DATE         NOT NULL,
    IdCliente            INT          NOT NULL,
    IdTienda             INT          NOT NULL,
    IdVendedor           INT          NOT NULL,
    IdCanalVenta         INT          NOT NULL,
    IdCampañaComercial   INT          NULL,
    Estado               VARCHAR(20)  NOT NULL DEFAULT 'Completa',
    CONSTRAINT PK_Ventas PRIMARY KEY (VentaID),
    CONSTRAINT FK_Ventas_Cliente   FOREIGN KEY (IdCliente)
        REFERENCES dbo.Clientes(ClienteID),
    CONSTRAINT FK_Ventas_Tienda    FOREIGN KEY (IdTienda)
        REFERENCES dbo.Tiendas(TiendaID),
    CONSTRAINT FK_Ventas_Vendedor  FOREIGN KEY (IdVendedor)
        REFERENCES dbo.Vendedores(VendedorID),
    CONSTRAINT FK_Ventas_Canal     FOREIGN KEY (IdCanalVenta)
        REFERENCES dbo.CanalVenta(CanalVentaID),
    CONSTRAINT FK_Ventas_Campaña   FOREIGN KEY (IdCampañaComercial)
        REFERENCES dbo.CampañasComerciales(CampañaID),
    CONSTRAINT CK_Ventas_Estado    CHECK (Estado IN ('Cancelada', 'Pendiente', 'Completa')),
    CONSTRAINT CK_Ventas_Fecha     CHECK (Fecha <= CAST(GETDATE() AS DATE))
);
GO
-- DetalleVentas  (depende de Ventas, Productos)
IF OBJECT_ID('dbo.DetalleVentas', 'U') IS NULL
CREATE TABLE dbo.DetalleVentas (
    DetalleVentaID       INT            IDENTITY(1,1)  NOT NULL,
    IdVenta              INT            NOT NULL,
    IdProducto           INT            NOT NULL,
    Cantidad             INT            NOT NULL,
    PrecioUnidadProducto DECIMAL(12,2)  NOT NULL,
    Subtotal             AS (Cantidad * PrecioUnidadProducto) PERSISTED,
    CONSTRAINT PK_DetalleVentas PRIMARY KEY (DetalleVentaID),
    CONSTRAINT FK_DetalleVentas_Venta    FOREIGN KEY (IdVenta)
        REFERENCES dbo.Ventas(VentaID),
    CONSTRAINT FK_DetalleVentas_Producto FOREIGN KEY (IdProducto)
        REFERENCES dbo.Productos(ProductoID),
    CONSTRAINT CK_DetalleVentas_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetalleVentas_Precio   CHECK (PrecioUnidadProducto > 0)
);
GO
-- Compras  (depende de Proveedores, Tiendas)
IF OBJECT_ID('dbo.Compras', 'U') IS NULL
CREATE TABLE dbo.Compras (
    CompraID     INT          IDENTITY(1,1)  NOT NULL,
    Fecha        DATE         NOT NULL,
    IdProveedor  INT          NOT NULL,
    IdTienda     INT          NOT NULL,
    Estado       VARCHAR(20)  NOT NULL DEFAULT 'Completa',
    CONSTRAINT PK_Compras PRIMARY KEY (CompraID),
    CONSTRAINT FK_Compras_Proveedor FOREIGN KEY (IdProveedor)
        REFERENCES dbo.Proveedores(ProveedorID),
    CONSTRAINT FK_Compras_Tienda    FOREIGN KEY (IdTienda)
        REFERENCES dbo.Tiendas(TiendaID),
    CONSTRAINT CK_Compras_Estado    CHECK (Estado IN ('Cancelada', 'Pendiente', 'Completa')),
    CONSTRAINT CK_Compras_Fecha     CHECK (Fecha <= CAST(GETDATE() AS DATE))
);
GO
-- DetalleCompras  (depende de Compras, Productos)
IF OBJECT_ID('dbo.DetalleCompras', 'U') IS NULL
CREATE TABLE dbo.DetalleCompras (
    DetalleCompraID      INT            IDENTITY(1,1)  NOT NULL,
    IdCompra             INT            NOT NULL,
    IdProducto           INT            NOT NULL,
    Cantidad             INT            NOT NULL,
    PrecioUnidadProducto DECIMAL(12,2)  NOT NULL,
    Subtotal             AS (Cantidad * PrecioUnidadProducto) PERSISTED,
    CONSTRAINT PK_DetalleCompras PRIMARY KEY (DetalleCompraID),
    CONSTRAINT FK_DetalleCompras_Compra   FOREIGN KEY (IdCompra)
        REFERENCES dbo.Compras(CompraID),
    CONSTRAINT FK_DetalleCompras_Producto FOREIGN KEY (IdProducto)
        REFERENCES dbo.Productos(ProductoID),
    CONSTRAINT CK_DetalleCompras_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetalleCompras_Precio   CHECK (PrecioUnidadProducto > 0)
);
GO
-- InventarioDiario  (depende de Productos, Tiendas)
IF OBJECT_ID('dbo.InventarioDiario', 'U') IS NULL
CREATE TABLE dbo.InventarioDiario (
    InventarioID      INT   IDENTITY(1,1)  NOT NULL,
    Fecha             DATE  NOT NULL,
    IdProducto        INT   NOT NULL,
    IdTienda          INT   NOT NULL,
    StockInicial      INT   NOT NULL,
    StockFinal        INT   NOT NULL,
    UnidadesEntrantes INT   NOT NULL DEFAULT 0,
    UnidadesSalientes INT   NOT NULL DEFAULT 0,
    CONSTRAINT PK_InventarioDiario PRIMARY KEY (InventarioID),
    CONSTRAINT UQ_Inventario_FechaProdTienda UNIQUE (Fecha, IdProducto, IdTienda),
    CONSTRAINT FK_Inventario_Producto FOREIGN KEY (IdProducto)
        REFERENCES dbo.Productos(ProductoID),
    CONSTRAINT FK_Inventario_Tienda   FOREIGN KEY (IdTienda)
        REFERENCES dbo.Tiendas(TiendaID),
    CONSTRAINT CK_Inventario_StockInicial      CHECK (StockInicial >= 0),
    CONSTRAINT CK_Inventario_StockFinal        CHECK (StockFinal >= 0),
    CONSTRAINT CK_Inventario_Entrantes         CHECK (UnidadesEntrantes >= 0),
    CONSTRAINT CK_Inventario_Salientes         CHECK (UnidadesSalientes >= 0),
    CONSTRAINT CK_Inventario_Fecha             CHECK (Fecha <= CAST(GETDATE() AS DATE)),
    -- El stock final debe ser consistente con los movimientos del día
    CONSTRAINT CK_Inventario_Consistencia
        CHECK (StockFinal = StockInicial + UnidadesEntrantes - UnidadesSalientes)
);
GO
-- Devoluciones  (depende de Ventas, Productos)
IF OBJECT_ID('dbo.Devoluciones', 'U') IS NULL
CREATE TABLE dbo.Devoluciones (
    DevolucionID    INT            IDENTITY(1,1)  NOT NULL,
    Fecha           DATE           NOT NULL,
    IdVenta         INT            NOT NULL,
    IdProducto      INT            NOT NULL,
    Cantidad        INT            NOT NULL,
    Motivo          NVARCHAR(255)  NOT NULL,
    TipoDevolucion  VARCHAR(20)    NOT NULL,
    CONSTRAINT PK_Devoluciones PRIMARY KEY (DevolucionID),
    CONSTRAINT FK_Devoluciones_Venta    FOREIGN KEY (IdVenta)
        REFERENCES dbo.Ventas(VentaID),
    CONSTRAINT FK_Devoluciones_Producto FOREIGN KEY (IdProducto)
        REFERENCES dbo.Productos(ProductoID),
    CONSTRAINT CK_Devoluciones_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Devoluciones_Tipo     CHECK (TipoDevolucion IN ('Cliente', 'Proveedor')),
    CONSTRAINT CK_Devoluciones_Fecha    CHECK (Fecha <= CAST(GETDATE() AS DATE))
);
GO
-- MetasComerciales  (depende de Tiendas, Categorias)
IF OBJECT_ID('dbo.MetasComerciales', 'U') IS NULL
CREATE TABLE dbo.MetasComerciales (
    MetaID       INT            IDENTITY(1,1)  NOT NULL,
    Año          SMALLINT       NOT NULL,
    Mes          TINYINT        NOT NULL,
    IdTienda     INT            NOT NULL,
    IdCategoria  INT            NOT NULL,
    ValorMeta    DECIMAL(15,2)  NOT NULL,
    CONSTRAINT PK_MetasComerciales PRIMARY KEY (MetaID),
    CONSTRAINT UQ_Metas_AnioMesTiendaCat UNIQUE (Año, Mes, IdTienda, IdCategoria),
    CONSTRAINT FK_Metas_Tienda    FOREIGN KEY (IdTienda)
        REFERENCES dbo.Tiendas(TiendaID),
    CONSTRAINT FK_Metas_Categoria FOREIGN KEY (IdCategoria)
        REFERENCES dbo.Categorias(CategoriaID),
    CONSTRAINT CK_Metas_Año   CHECK (Año BETWEEN 2020 AND 2100),
    CONSTRAINT CK_Metas_Mes   CHECK (Mes BETWEEN 1 AND 12),
    CONSTRAINT CK_Metas_Valor CHECK (ValorMeta > 0)
);
GO
-- ÍNDICES DE APOYO PARA CONSULTAS ANALÍTICAS
-- Ventas por fecha (crítico para time intelligence en DW)
CREATE NONCLUSTERED INDEX IX_Ventas_Fecha
    ON dbo.Ventas(Fecha)
    INCLUDE (IdCliente, IdTienda, IdVendedor, IdCanalVenta, Estado);
GO
-- DetalleVentas por venta y producto
CREATE NONCLUSTERED INDEX IX_DetalleVentas_Venta
    ON dbo.DetalleVentas(IdVenta)
    INCLUDE (IdProducto, Cantidad, PrecioUnidadProducto);
GO

CREATE NONCLUSTERED INDEX IX_DetalleVentas_Producto
    ON dbo.DetalleVentas(IdProducto);
GO
-- InventarioDiario por fecha y tienda
CREATE NONCLUSTERED INDEX IX_Inventario_Fecha_Tienda
    ON dbo.InventarioDiario(Fecha, IdTienda)
    INCLUDE (IdProducto, StockFinal);
GO
-- Compras por fecha
CREATE NONCLUSTERED INDEX IX_Compras_Fecha
    ON dbo.Compras(Fecha)
    INCLUDE (IdProveedor, IdTienda, Estado);
GO
-- Devoluciones por venta
CREATE NONCLUSTERED INDEX IX_Devoluciones_Venta
    ON dbo.Devoluciones(IdVenta)
    INCLUDE (IdProducto, Cantidad, TipoDevolucion);
GO
-- FIN DEL SCRIPT
PRINT 'OLTP BI_OLTP creado exitosamente. Tablas: 15. Índices: 6.';
GO