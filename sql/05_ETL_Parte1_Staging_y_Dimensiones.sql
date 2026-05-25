/*******************************************************************************
   PROYECTO 3 - BASES DE DATOS AVANZADAS
   SCRIPT: ETL Parte 1 — Carga de Staging y Dimensiones
   Persona 2 — Staging, DW & ETL

   CONTENIDO:
   1. sp_CargarStaging          — Extrae del OLTP y llena BI_Staging
   2. sp_ValidarStaging         — Aplica reglas de calidad, marca VALIDO/RECHAZADO
   3. sp_CargarDimFecha         — Genera el calendario completo en DimFecha
   4. sp_CargarDimGeografia     — Carga ciudades/regiones únicas
   5. sp_CargarDimPromocion     — Carga campañas comerciales
   6. sp_CargarDimCanalVenta    — Carga canales de venta
   7. sp_CargarDimProveedor     — Carga proveedores
   8. sp_CargarDimTienda        — Carga tiendas
   9. sp_CargarDimVendedor      — Carga vendedores
   10. sp_CargarDimCliente      — Carga clientes con SCD Tipo 2
   11. sp_CargarDimProducto     — Carga productos con SCD Tipo 2

   PATRÓN ETL_Log:
   Cada SP abre un registro al inicio (EN EJECUCION) y lo cierra al final
   (EXITOSO o FALLIDO) con conteos de registros leídos, cargados y rechazados.
*******************************************************************************/

USE BI_Staging;
GO

-- ===========================================================================
-- 1. sp_CargarStaging
-- Extrae datos del OLTP y los inserta en las tablas STG_*
-- Hace TRUNCATE antes de insertar (patrón full-refresh)
-- No aplica validaciones aquí — solo copia los datos tal como están
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarStaging
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;
    DECLARE @Rechazados INT = 0;
    DECLARE @Error      NVARCHAR(1000);

    -- Abrir registro en ETL_Log
    INSERT INTO dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarStaging', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- ---------------------------------------------------------------
        -- Truncar todas las tablas staging (full-refresh)
        -- ---------------------------------------------------------------
        TRUNCATE TABLE dbo.STG_Ventas;
        TRUNCATE TABLE dbo.STG_Productos;
        TRUNCATE TABLE dbo.STG_Clientes;
        TRUNCATE TABLE dbo.STG_Inventario;
        TRUNCATE TABLE dbo.STG_Devoluciones;
        TRUNCATE TABLE dbo.STG_Compras;
        TRUNCATE TABLE dbo.STG_Metas;
        TRUNCATE TABLE dbo.STG_AjustesInventario;

        -- ---------------------------------------------------------------
        -- Carga de archivos CSV externos (C:\DatosBI\) vía #temp tables
        -- (Evita errores de sintaxis de BULK INSERT en SQL Server)
        -- ---------------------------------------------------------------
        
        -- 1. Temp para Metas
        CREATE TABLE #TmpMetas (
            Año NVARCHAR(10), Mes NVARCHAR(10), TiendaID_CSV INT, NombreTienda_CSV NVARCHAR(200),
            CategoriaID_CSV INT, NombreCategoria_CSV NVARCHAR(200), ValorMeta NVARCHAR(50)
        );

        BULK INSERT #TmpMetas
        FROM 'C:\DatosBI\metas_mensuales.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', CODEPAGE = '65001');

        INSERT INTO dbo.STG_Metas (Año, Mes, TiendaID_CSV, NombreTienda_CSV, CategoriaID_CSV, NombreCategoria_CSV, ValorMeta)
        SELECT * FROM #TmpMetas;
        
        DECLARE @CountMetas INT = @@ROWCOUNT;
        DROP TABLE #TmpMetas;

        -- 2. Temp para Ajustes
        CREATE TABLE #TmpAjustes (
            Año NVARCHAR(10), Mes NVARCHAR(10), TiendaID_CSV INT, NombreTienda_CSV NVARCHAR(200),
            ProductoID_CSV INT, StockFisico INT, StockSistema INT, Ajuste INT, Motivo NVARCHAR(500)
        );

        BULK INSERT #TmpAjustes
        FROM 'C:\DatosBI\inventario_ajustes.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', CODEPAGE = '65001');

        INSERT INTO dbo.STG_AjustesInventario (Año, Mes, TiendaID_CSV, NombreTienda_CSV, ProductoID_CSV, StockFisico, StockSistema, Ajuste, Motivo)
        SELECT * FROM #TmpAjustes;

        DECLARE @CountAjustes INT = @@ROWCOUNT;
        DROP TABLE #TmpAjustes;

        SET @Leidos = @Leidos + @CountMetas + @CountAjustes;
        SET @Cargados = @Cargados + @CountMetas + @CountAjustes;

        -- ---------------------------------------------------------------
        -- STG_Ventas: JOIN Ventas + DetalleVentas
        -- Una fila por línea de detalle
        -- ---------------------------------------------------------------
        INSERT INTO dbo.STG_Ventas (
            VentaID, Fecha, IdCliente, IdTienda, IdVendedor,
            IdCanalVenta, IdCampañaComercial, EstadoVenta,
            DetalleVentaID, IdProducto, Cantidad, PrecioUnidad, Subtotal,
            STG_FuenteOrigen
        )
        SELECT
            V.VentaID,
            CAST(V.Fecha AS NVARCHAR(50)),
            V.IdCliente,
            V.IdTienda,
            V.IdVendedor,
            V.IdCanalVenta,
            V.IdCampañaComercial,
            V.Estado,
            D.DetalleVentaID,
            D.IdProducto,
            D.Cantidad,
            D.PrecioUnidadProducto,
            D.Cantidad * D.PrecioUnidadProducto,   -- Subtotal calculado
            'BI_OLTP.Ventas+DetalleVentas'
        FROM BI_OLTP.dbo.Ventas V
        JOIN BI_OLTP.dbo.DetalleVentas D ON V.VentaID = D.IdVenta;

        SET @Leidos = @Leidos + @@ROWCOUNT;
        SET @Cargados = @Cargados + @@ROWCOUNT;

        -- ---------------------------------------------------------------
        -- STG_Productos: JOIN Productos + Categorias
        -- ---------------------------------------------------------------
        INSERT INTO dbo.STG_Productos (
            ProductoID, CodigoProducto, NombreProducto, Descripcion,
            CategoriaID, NombreCategoria, PrecioVenta, PrecioCosto,
            UnidadMedida, StockMinimo, STG_FuenteOrigen
        )
        SELECT
            P.ProductoID,
            P.CodigoProducto,
            P.Nombre,
            P.Descripcion,
            P.CategoriaID,
            C.Nombre,
            P.PrecioVenta,
            P.PrecioCosto,
            P.UnidadMedida,
            P.StockMinimo,
            'BI_OLTP.Productos+Categorias'
        FROM BI_OLTP.dbo.Productos P
        JOIN BI_OLTP.dbo.Categorias C ON P.CategoriaID = C.CategoriaID;

        SET @Leidos = @Leidos + @@ROWCOUNT;
        SET @Cargados = @Cargados + @@ROWCOUNT;

        -- ---------------------------------------------------------------
        -- STG_Clientes
        -- ---------------------------------------------------------------
        INSERT INTO dbo.STG_Clientes (
            ClienteID, Nombre, Apellido, TipoDocumento,
            NumeroDocumento, Ciudad, Region, Segmento, FechaRegistro,
            STG_FuenteOrigen
        )
        SELECT
            ClienteID,
            Nombre,
            Apellido,
            TipoDocumento,
            NumeroDocumento,
            Ciudad,
            Region,
            Segmento,
            CAST(FechaRegistro AS NVARCHAR(50)),
            'BI_OLTP.Clientes'
        FROM BI_OLTP.dbo.Clientes;

        SET @Leidos = @Leidos + @@ROWCOUNT;
        SET @Cargados = @Cargados + @@ROWCOUNT;

        -- ---------------------------------------------------------------
        -- STG_Inventario
        -- ---------------------------------------------------------------
        INSERT INTO dbo.STG_Inventario (
            InventarioID, Fecha, IdProducto, IdTienda,
            StockInicial, StockFinal, UnidadesEntrantes, UnidadesSalientes,
            ConsistenciaCalculada, STG_FuenteOrigen
        )
        SELECT
            InventarioID,
            CAST(Fecha AS NVARCHAR(50)),
            IdProducto,
            IdTienda,
            StockInicial,
            StockFinal,
            UnidadesEntrantes,
            UnidadesSalientes,
            StockInicial + UnidadesEntrantes - UnidadesSalientes,  -- Campo derivado de validación
            'BI_OLTP.InventarioDiario'
        FROM BI_OLTP.dbo.InventarioDiario;

        SET @Leidos = @Leidos + @@ROWCOUNT;
        SET @Cargados = @Cargados + @@ROWCOUNT;

        -- ---------------------------------------------------------------
        -- STG_Devoluciones: JOIN Devoluciones + Ventas (para FechaVentaOrigen)
        -- ---------------------------------------------------------------
        INSERT INTO dbo.STG_Devoluciones (
            DevolucionID, Fecha, IdVenta, IdProducto,
            Cantidad, Motivo, TipoDevolucion, FechaVentaOrigen,
            STG_FuenteOrigen
        )
        SELECT
            D.DevolucionID,
            CAST(D.Fecha AS NVARCHAR(50)),
            D.IdVenta,
            D.IdProducto,
            D.Cantidad,
            D.Motivo,
            D.TipoDevolucion,
            V.Fecha,   -- Fecha de la venta origen para validación cruzada
            'BI_OLTP.Devoluciones'
        FROM BI_OLTP.dbo.Devoluciones D
        JOIN BI_OLTP.dbo.Ventas V ON D.IdVenta = V.VentaID;

        SET @Leidos = @Leidos + @@ROWCOUNT;
        SET @Cargados = @Cargados + @@ROWCOUNT;

        -- ---------------------------------------------------------------
        -- STG_Compras: JOIN Compras + DetalleCompras + Proveedores
        -- ---------------------------------------------------------------
        INSERT INTO dbo.STG_Compras (
            CompraID, FechaCompra, IdProveedor, NombreProveedor,
            IdTienda, EstadoCompra,
            DetalleCompraID, IdProducto, Cantidad, PrecioUnidad, Subtotal,
            STG_FuenteOrigen
        )
        SELECT
            C.CompraID,
            CAST(C.Fecha AS NVARCHAR(50)),
            C.IdProveedor,
            P.Nombre,
            C.IdTienda,
            C.Estado,
            DC.DetalleCompraID,
            DC.IdProducto,
            DC.Cantidad,
            DC.PrecioUnidadProducto,
            DC.Cantidad * DC.PrecioUnidadProducto,
            'BI_OLTP.Compras+DetalleCompras'
        FROM BI_OLTP.dbo.Compras C
        JOIN BI_OLTP.dbo.DetalleCompras DC ON C.CompraID = DC.IdCompra
        JOIN BI_OLTP.dbo.Proveedores P    ON C.IdProveedor = P.ProveedorID;

        SET @Leidos = @Leidos + @@ROWCOUNT;
        SET @Cargados = @Cargados + @@ROWCOUNT;

        -- Cerrar log exitoso
        UPDATE dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = 0
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        SET @Error = ERROR_MESSAGE();
        UPDATE dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'FALLIDO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = @Rechazados,
            MensajeError        = @Error
        WHERE LogID = @LogID;

        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 2. sp_ValidarStaging
-- Aplica reglas de calidad sobre cada tabla STG_*
-- Marca cada fila como VALIDO o RECHAZADO con mensaje descriptivo
-- DEBE ejecutarse después de sp_CargarStaging y antes de cargar el DW
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ValidarStaging
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Validos    INT = 0;
    DECLARE @Rechazados INT = 0;

    INSERT INTO dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_ValidarStaging', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- Contar total de registros a validar
        SELECT @Leidos = COUNT(*) FROM dbo.STG_Ventas;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_Productos;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_Clientes;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_Inventario;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_Devoluciones;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_Compras;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_Metas;
        SELECT @Leidos = @Leidos + COUNT(*) FROM dbo.STG_AjustesInventario;

        -- ---------------------------------------------------------------
        -- Validaciones STG_Ventas
        -- ---------------------------------------------------------------

        -- Regla 1: Fecha no puede ser NULL ni futura
        UPDATE dbo.STG_Ventas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Fecha NULL o futura'
        WHERE STG_Estado = 'PENDIENTE'
          AND (Fecha IS NULL
               OR TRY_CAST(Fecha AS DATE) IS NULL
               OR TRY_CAST(Fecha AS DATE) > CAST(GETDATE() AS DATE));

        -- Regla 2: Claves foráneas del OLTP deben existir
        UPDATE dbo.STG_Ventas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'IdCliente no existe en OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND IdCliente NOT IN (SELECT ClienteID FROM BI_OLTP.dbo.Clientes);

        UPDATE dbo.STG_Ventas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'IdProducto no existe en OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND IdProducto NOT IN (SELECT ProductoID FROM BI_OLTP.dbo.Productos);

        -- Regla 3: Cantidad y precio deben ser positivos
        UPDATE dbo.STG_Ventas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Cantidad o PrecioUnidad no positivos'
        WHERE STG_Estado = 'PENDIENTE'
          AND (Cantidad <= 0 OR PrecioUnidad <= 0);

        -- Regla 4: Estado debe ser valor permitido
        UPDATE dbo.STG_Ventas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'EstadoVenta no permitido'
        WHERE STG_Estado = 'PENDIENTE'
          AND EstadoVenta NOT IN ('Completa', 'Cancelada', 'Pendiente');

        -- Marcar restantes como válidos
        UPDATE dbo.STG_Ventas
        SET STG_Estado = 'VALIDO'
        WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_Productos
        -- ---------------------------------------------------------------

        -- Regla 1: PrecioVenta debe ser mayor que PrecioCosto (margen positivo)
        UPDATE dbo.STG_Productos
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'PrecioVenta menor o igual a PrecioCosto'
        WHERE STG_Estado = 'PENDIENTE'
          AND (PrecioVenta IS NULL OR PrecioCosto IS NULL OR PrecioVenta <= PrecioCosto);

        -- Regla 2: CodigoProducto no puede ser NULL
        UPDATE dbo.STG_Productos
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'CodigoProducto NULL'
        WHERE STG_Estado = 'PENDIENTE'
          AND CodigoProducto IS NULL;

        -- Regla 3: Detectar duplicados por CodigoProducto (dejar solo el de menor STG_ID)
        UPDATE dbo.STG_Productos
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Duplicado por CodigoProducto'
        WHERE STG_Estado = 'PENDIENTE'
          AND STG_ID NOT IN (
              SELECT MIN(STG_ID)
              FROM dbo.STG_Productos
              WHERE STG_Estado = 'PENDIENTE'
              GROUP BY CodigoProducto
          );

        UPDATE dbo.STG_Productos SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_Clientes
        -- ---------------------------------------------------------------

        -- Regla 1: Campos obligatorios no nulos
        UPDATE dbo.STG_Clientes
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Nombre, Apellido o NumeroDocumento NULL'
        WHERE STG_Estado = 'PENDIENTE'
          AND (Nombre IS NULL OR Apellido IS NULL OR NumeroDocumento IS NULL);

        -- Regla 2: TipoDocumento debe ser valor permitido
        UPDATE dbo.STG_Clientes
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'TipoDocumento no permitido'
        WHERE STG_Estado = 'PENDIENTE'
          AND TipoDocumento NOT IN ('CC', 'NIT', 'CE', 'Pasaporte', 'TI');

        -- Regla 3: Segmento debe ser valor permitido
        UPDATE dbo.STG_Clientes
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Segmento no permitido'
        WHERE STG_Estado = 'PENDIENTE'
          AND Segmento NOT IN ('Minorista', 'Mayorista', 'Corporativo', 'VIP', 'Regular');

        -- Regla 4: Duplicados por (TipoDocumento, NumeroDocumento)
        UPDATE dbo.STG_Clientes
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Duplicado por TipoDocumento + NumeroDocumento'
        WHERE STG_Estado = 'PENDIENTE'
          AND STG_ID NOT IN (
              SELECT MIN(STG_ID)
              FROM dbo.STG_Clientes
              WHERE STG_Estado = 'PENDIENTE'
              GROUP BY TipoDocumento, NumeroDocumento
          );

        -- Estandarizar Ciudad y Region: TRIM + capitalización básica
        UPDATE dbo.STG_Clientes
        SET Ciudad = LTRIM(RTRIM(Ciudad)),
            Region = LTRIM(RTRIM(Region))
        WHERE STG_Estado = 'PENDIENTE';

        UPDATE dbo.STG_Clientes SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_Inventario
        -- ---------------------------------------------------------------

        -- Regla 1: Consistencia matemática StockFinal = StockInicial + Entrantes - Salientes
        UPDATE dbo.STG_Inventario
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Inconsistencia: StockFinal != StockInicial + Entrantes - Salientes'
        WHERE STG_Estado = 'PENDIENTE'
          AND StockFinal != ConsistenciaCalculada;

        -- Regla 2: Stocks no pueden ser negativos
        UPDATE dbo.STG_Inventario
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Stock negativo detectado'
        WHERE STG_Estado = 'PENDIENTE'
          AND (StockInicial < 0 OR StockFinal < 0);

        UPDATE dbo.STG_Inventario SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_Devoluciones
        -- ---------------------------------------------------------------

        -- Regla 1: Fecha devolución debe ser >= Fecha venta
        UPDATE dbo.STG_Devoluciones
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Fecha devolución anterior a fecha de venta'
        WHERE STG_Estado = 'PENDIENTE'
          AND TRY_CAST(Fecha AS DATE) < FechaVentaOrigen;

        -- Regla 2: TipoDevolucion debe ser valor permitido
        UPDATE dbo.STG_Devoluciones
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'TipoDevolucion no permitido'
        WHERE STG_Estado = 'PENDIENTE'
          AND TipoDevolucion NOT IN ('Cliente', 'Proveedor');

        UPDATE dbo.STG_Devoluciones SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_Compras
        -- ---------------------------------------------------------------

        -- Regla 1: Cantidad y precio deben ser positivos
        UPDATE dbo.STG_Compras
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Cantidad o PrecioUnidad no positivos'
        WHERE STG_Estado = 'PENDIENTE'
          AND (Cantidad <= 0 OR PrecioUnidad <= 0);

        -- Regla 2: IdProveedor debe existir en OLTP
        UPDATE dbo.STG_Compras
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'IdProveedor no existe en OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND IdProveedor NOT IN (SELECT ProveedorID FROM BI_OLTP.dbo.Proveedores);

        UPDATE dbo.STG_Compras SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_Metas (viene del CSV)
        -- Mapeo de nombres de categoría del CSV al CategoriaID del OLTP
        -- ---------------------------------------------------------------

        -- Primero: resolver TiendaID del CSV contra OLTP
        UPDATE dbo.STG_Metas
        SET TiendaID_Resuelto = T.TiendaID
        FROM dbo.STG_Metas M
        JOIN BI_OLTP.dbo.Tiendas T ON M.TiendaID_CSV = T.TiendaID;

        -- Segundo: mapear nombre de categoría del CSV al CategoriaID del OLTP
        -- Esta tabla de mapeo resuelve la inconsistencia entre el CSV y el OLTP
        UPDATE dbo.STG_Metas
        SET CategoriaID_Resuelto = C.CategoriaID
        FROM dbo.STG_Metas M
        JOIN BI_OLTP.dbo.Categorias C
          ON C.Nombre = CASE M.NombreCategoria_CSV
                WHEN 'Electrónica'        THEN 'Tecnología'
                WHEN 'Electrodomésticos'  THEN 'Electrodomésticos'
                WHEN 'Automotriz'         THEN 'Automotriz'
                WHEN 'Ropa y Moda'        THEN 'Moda y Calzado'
                WHEN 'Juguetes y Juegos'  THEN 'Juguetería'
                WHEN 'Salud y Cuidado'    THEN 'Salud y Belleza'
                WHEN 'Herramientas'       THEN 'Herramientas'
                WHEN 'Mascotas'           THEN 'Mascotas'
                WHEN 'Alimentos'          THEN 'Alimentos y Bebidas'
                WHEN 'Belleza y Cuidado'  THEN 'Salud y Belleza'
                WHEN 'Ferretería'         THEN 'Herramientas'
                WHEN 'Hogar y Decoración' THEN 'Hogar y Cocina'
                WHEN 'Librería y Papelería' THEN 'Libros y Papelería'
                ELSE M.NombreCategoria_CSV   -- Si ya coincide, pasa directo
             END;

        -- Rechazar metas donde no se pudo resolver tienda o categoría
        UPDATE dbo.STG_Metas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'TiendaID no resuelto contra OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND TiendaID_Resuelto IS NULL;

        UPDATE dbo.STG_Metas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Categoría del CSV no mapeada a OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND CategoriaID_Resuelto IS NULL;

        -- Rechazar ValorMeta no positivo
        UPDATE dbo.STG_Metas
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'ValorMeta no positivo o no numérico'
        WHERE STG_Estado = 'PENDIENTE'
          AND (TRY_CAST(ValorMeta AS DECIMAL(15,2)) IS NULL
               OR TRY_CAST(ValorMeta AS DECIMAL(15,2)) <= 0);

        UPDATE dbo.STG_Metas SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Validaciones STG_AjustesInventario (viene del CSV)
        -- ---------------------------------------------------------------

        -- Regla 1: TiendaID y ProductoID deben existir en OLTP
        UPDATE dbo.STG_AjustesInventario
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'TiendaID no existe en OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND TiendaID_CSV NOT IN (SELECT TiendaID FROM BI_OLTP.dbo.Tiendas);

        UPDATE dbo.STG_AjustesInventario
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'ProductoID no existe en OLTP'
        WHERE STG_Estado = 'PENDIENTE'
          AND ProductoID_CSV NOT IN (SELECT ProductoID FROM BI_OLTP.dbo.Productos);

        -- Regla 2: Ajuste = 0 es ruido, se rechaza (el CSV tiene estos casos)
        UPDATE dbo.STG_AjustesInventario
        SET STG_Estado       = 'RECHAZADO',
            STG_MensajeError = 'Ajuste = 0, registro sin impacto analítico'
        WHERE STG_Estado = 'PENDIENTE'
          AND Ajuste = 0;

        -- Categorizar tipo de ajuste y motivo en campos derivados
        UPDATE dbo.STG_AjustesInventario
        SET TipoAjuste = CASE
                WHEN Ajuste > 0 THEN 'POSITIVO'
                WHEN Ajuste < 0 THEN 'NEGATIVO'
                ELSE 'NEUTRO'
             END,
            MotivoCategorizado = CASE
                WHEN Motivo LIKE '%merma%'          THEN 'Merma'
                WHEN Motivo LIKE '%vencimiento%'    THEN 'Vencimiento'
                WHEN Motivo LIKE '%transferencia%'  THEN 'Transferencia'
                WHEN Motivo LIKE '%error%'          THEN 'Error Sistema'
                WHEN Motivo LIKE '%exceso%'         THEN 'Exceso'
                WHEN Motivo LIKE '%devoluci%'       THEN 'Devolución'
                ELSE 'Otro'
             END
        WHERE STG_Estado = 'PENDIENTE';

        UPDATE dbo.STG_AjustesInventario SET STG_Estado = 'VALIDO' WHERE STG_Estado = 'PENDIENTE';

        -- ---------------------------------------------------------------
        -- Conteo final
        -- ---------------------------------------------------------------
        SELECT @Validos =
            (SELECT COUNT(*) FROM dbo.STG_Ventas           WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_Productos         WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_Clientes          WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_Inventario        WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_Devoluciones      WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_Compras           WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_Metas             WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM dbo.STG_AjustesInventario WHERE STG_Estado = 'VALIDO');

        SELECT @Rechazados =
            (SELECT COUNT(*) FROM dbo.STG_Ventas           WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_Productos         WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_Clientes          WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_Inventario        WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_Devoluciones      WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_Compras           WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_Metas             WHERE STG_Estado = 'RECHAZADO') +
            (SELECT COUNT(*) FROM dbo.STG_AjustesInventario WHERE STG_Estado = 'RECHAZADO');

        UPDATE dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Validos,
            RegistrosRechazados = @Rechazados
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'FALLIDO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Validos,
            RegistrosRechazados = @Rechazados,
            MensajeError        = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- A partir de aquí los SP de carga trabajan sobre BI_DW
-- ===========================================================================
USE BI_DW;
GO


-- ===========================================================================
-- 3. sp_CargarDimFecha
-- Genera el calendario día a día desde 2024-01-01 hasta 2026-12-31
-- No lee del Staging — es una generación matemática pura
-- DimFecha usa FechaKey = YYYYMMDD (entero), no IDENTITY
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimFecha
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID  INT;
    DECLARE @Inicio DATETIME = GETDATE();

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimFecha', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- Solo insertar fechas que no existan (idempotente)
        DECLARE @Fecha DATE = '2024-01-01';
        DECLARE @FechaFin DATE = '2026-12-31';
        DECLARE @Cargados INT = 0;

        WHILE @Fecha <= @FechaFin
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.DimFecha WHERE FechaKey = CAST(FORMAT(@Fecha, 'yyyyMMdd') AS INT))
            BEGIN
                INSERT INTO dbo.DimFecha (
                    FechaKey, Fecha, Año, Trimestre, NombreTrimestre,
                    Mes, NombreMes, NombreMesCorto, AñoMes,
                    Semana, DiaSemana, NombreDiaSemana, EsFinDeSemana, EsFestivoColombia
                )
                VALUES (
                    CAST(FORMAT(@Fecha, 'yyyyMMdd') AS INT),
                    @Fecha,
                    YEAR(@Fecha),
                    DATEPART(QUARTER, @Fecha),
                    CONCAT('Q', DATEPART(QUARTER, @Fecha)),
                    MONTH(@Fecha),
                    CASE MONTH(@Fecha)
                        WHEN 1  THEN 'Enero'      WHEN 2  THEN 'Febrero'
                        WHEN 3  THEN 'Marzo'      WHEN 4  THEN 'Abril'
                        WHEN 5  THEN 'Mayo'       WHEN 6  THEN 'Junio'
                        WHEN 7  THEN 'Julio'      WHEN 8  THEN 'Agosto'
                        WHEN 9  THEN 'Septiembre' WHEN 10 THEN 'Octubre'
                        WHEN 11 THEN 'Noviembre'  WHEN 12 THEN 'Diciembre'
                    END,
                    CASE MONTH(@Fecha)
                        WHEN 1  THEN 'Ene' WHEN 2  THEN 'Feb' WHEN 3  THEN 'Mar'
                        WHEN 4  THEN 'Abr' WHEN 5  THEN 'May' WHEN 6  THEN 'Jun'
                        WHEN 7  THEN 'Jul' WHEN 8  THEN 'Ago' WHEN 9  THEN 'Sep'
                        WHEN 10 THEN 'Oct' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dic'
                    END,
                    CAST(FORMAT(@Fecha, 'yyyyMM') AS INT),
                    DATEPART(ISO_WEEK, @Fecha),
                    -- Aritmética determinista de días (Lunes=1, Domingo=7) independiente de DATEFIRST
                    (DATEDIFF(DAY, 0, @Fecha) % 7) + 1,
                    CASE (DATEDIFF(DAY, 0, @Fecha) % 7) + 1
                        WHEN 1 THEN 'Lunes'     WHEN 2 THEN 'Martes'
                        WHEN 3 THEN 'Miércoles' WHEN 4 THEN 'Jueves'
                        WHEN 5 THEN 'Viernes'   WHEN 6 THEN 'Sábado'
                        WHEN 7 THEN 'Domingo'
                    END,
                    CASE WHEN (DATEDIFF(DAY, 0, @Fecha) % 7) + 1 IN (6, 7) THEN 1 ELSE 0 END,
                    0   -- EsFestivoColombia: se puede actualizar manualmente después
                );
                SET @Cargados = @Cargados + 1;
            END;
            SET @Fecha = DATEADD(DAY, 1, @Fecha);
        END;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Cargados, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 4. sp_CargarDimGeografia
-- Extrae combinaciones únicas (Ciudad, Region) de Clientes, Tiendas
-- y Proveedores del OLTP y las inserta en DimGeografia
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimGeografia
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Cargados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimGeografia', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        -- Unión de todas las ciudades/regiones conocidas en el OLTP
        ;WITH TodasGeografias AS (
            SELECT LTRIM(RTRIM(Ciudad)) AS Ciudad, LTRIM(RTRIM(Region)) AS Region
            FROM BI_OLTP.dbo.Clientes
            UNION
            SELECT LTRIM(RTRIM(Ciudad)), LTRIM(RTRIM(Region))
            FROM BI_OLTP.dbo.Tiendas
            UNION
            SELECT LTRIM(RTRIM(Ciudad)), 'Colombia'   -- Proveedores no tienen Region en el OLTP
            FROM BI_OLTP.dbo.Proveedores
        )
        INSERT INTO dbo.DimGeografia (Ciudad, Region, Pais)
        SELECT G.Ciudad, G.Region, 'Colombia'
        FROM TodasGeografias G
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DimGeografia DG
            WHERE DG.Ciudad = G.Ciudad AND DG.Region = G.Region
        );

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Cargados, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 5. sp_CargarDimPromocion
-- Carga campañas comerciales del OLTP en DimPromocion
-- El registro -1 'Sin Promoción' ya fue insertado en el script de creación
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimPromocion
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Leidos INT;
    DECLARE @Cargados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimPromocion', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_OLTP.dbo.CampañasComerciales;

        -- Insertar solo campañas nuevas (idempotente por PromocionID_OLTP)
        INSERT INTO dbo.DimPromocion (PromocionID_OLTP, NombrePromocion, TipoPromocion, FechaInicio, FechaFin)
        SELECT C.CampañaID, C.Nombre, C.TipoCampaña, C.FechaInicio, C.FechaFin
        FROM BI_OLTP.dbo.CampañasComerciales C
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DimPromocion DP
            WHERE DP.PromocionID_OLTP = C.CampañaID
        );

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Leidos, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 6. sp_CargarDimCanalVenta
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimCanalVenta
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Leidos INT;
    DECLARE @Cargados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimCanalVenta', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_OLTP.dbo.CanalVenta;

        INSERT INTO dbo.DimCanalVenta (CanalVentaID_OLTP, NombreCanal, Descripcion)
        SELECT C.CanalVentaID, C.Nombre, C.Descripcion
        FROM BI_OLTP.dbo.CanalVenta C
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DimCanalVenta DC
            WHERE DC.CanalVentaID_OLTP = C.CanalVentaID
        );

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Leidos, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 7. sp_CargarDimProveedor
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimProveedor
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Leidos INT;
    DECLARE @Cargados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimProveedor', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_OLTP.dbo.Proveedores;

        INSERT INTO dbo.DimProveedor (
            ProveedorID_OLTP, NombreProveedor, NIT, Ciudad,
            NombreContacto, Telefono, GeografiaKey
        )
        SELECT
            P.ProveedorID,
            P.Nombre,
            P.NumeroIdentificacionTributaria,
            P.Ciudad,
            P.NombreContacto,
            P.Telefono,
            G.GeografiaKey
        FROM BI_OLTP.dbo.Proveedores P
        JOIN dbo.DimGeografia G ON G.Ciudad = LTRIM(RTRIM(P.Ciudad)) AND G.Region = 'Colombia'
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DimProveedor DP
            WHERE DP.ProveedorID_OLTP = P.ProveedorID
        );

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Leidos, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 8. sp_CargarDimTienda
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimTienda
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Leidos INT;
    DECLARE @Cargados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimTienda', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_OLTP.dbo.Tiendas;

        INSERT INTO dbo.DimTienda (
            TiendaID_OLTP, NombreTienda, Ciudad, Region,
            Direccion, Telefono, FechaInicioOperaciones, GeografiaKey
        )
        SELECT
            T.TiendaID,
            T.Nombre,
            T.Ciudad,
            T.Region,
            T.Direccion,
            T.Telefono,
            T.FechaInicioOperaciones,
            G.GeografiaKey
        FROM BI_OLTP.dbo.Tiendas T
        JOIN dbo.DimGeografia G
          ON G.Ciudad = LTRIM(RTRIM(T.Ciudad)) AND G.Region = LTRIM(RTRIM(T.Region))
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DimTienda DT
            WHERE DT.TiendaID_OLTP = T.TiendaID
        );

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Leidos, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 9. sp_CargarDimVendedor
-- Depende de DimTienda (debe ejecutarse después)
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimVendedor
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio DATETIME = GETDATE();
    DECLARE @Leidos INT;
    DECLARE @Cargados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimVendedor', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_OLTP.dbo.Vendedores;

        INSERT INTO dbo.DimVendedor (
            VendedorID_OLTP, Nombre, Apellido, NombreCompleto,
            TiendaAsignadaKey, FechaIngreso
        )
        SELECT
            V.VendedorID,
            V.Nombre,
            V.Apellido,
            CONCAT(V.Nombre, ' ', V.Apellido),
            DT.TiendaKey,
            V.FechaIngreso
        FROM BI_OLTP.dbo.Vendedores V
        JOIN dbo.DimTienda DT ON DT.TiendaID_OLTP = V.IdTiendaAsignada
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.DimVendedor DV
            WHERE DV.VendedorID_OLTP = V.VendedorID
        );

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos = @Leidos, RegistrosCargados = @Cargados, RegistrosRechazados = 0
        WHERE LogID = @LogID;
    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 10. sp_CargarDimCliente — SCD TIPO 2
-- Lógica:
--   a) Si el cliente no existe en DimCliente → INSERT nuevo registro activo
--   b) Si existe Y algún atributo SCD cambió (Ciudad, Region, Segmento):
--      → UPDATE registro actual: FechaFinVigencia = hoy-1, EsRegistroActual = 0
--      → INSERT nueva versión con FechaInicioVigencia = hoy, EsRegistroActual = 1
--   c) Si existe y no cambió nada → no hacer nada (idempotente)
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimCliente
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    DECLARE @Inicio   DATETIME = GETDATE();
    DECLARE @Hoy      DATE     = CAST(GETDATE() AS DATE);
    DECLARE @Leidos   INT = 0;
    DECLARE @Nuevos   INT = 0;
    DECLARE @Versiones INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimCliente', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_Staging.dbo.STG_Clientes WHERE STG_Estado = 'VALIDO';

        -- a) Insertar clientes nuevos (no existen en DimCliente)
        INSERT INTO dbo.DimCliente (
            ClienteID_OLTP, Nombre, Apellido, NombreCompleto,
            TipoDocumento, NumeroDocumento, Ciudad, Region, Segmento,
            GeografiaKey, FechaInicioVigencia, FechaFinVigencia, EsRegistroActual
        )
        SELECT
            S.ClienteID,
            S.Nombre,
            S.Apellido,
            CONCAT(S.Nombre, ' ', S.Apellido),
            S.TipoDocumento,
            S.NumeroDocumento,
            S.Ciudad,
            S.Region,
            S.Segmento,
            G.GeografiaKey,
            '2024-01-01',  -- Fecha base del proyecto: cubre todo el historial de transacciones
            NULL,
            1
        FROM BI_Staging.dbo.STG_Clientes S
        JOIN dbo.DimGeografia G
          ON G.Ciudad = S.Ciudad AND G.Region = S.Region
        WHERE S.STG_Estado = 'VALIDO'
          AND NOT EXISTS (
              SELECT 1 FROM dbo.DimCliente DC
              WHERE DC.ClienteID_OLTP = S.ClienteID
          );

        SET @Nuevos = @@ROWCOUNT;

        -- b) Detectar clientes con cambios en atributos SCD (Ciudad, Region, Segmento)
        --    y cerrar el registro actual
        UPDATE dbo.DimCliente
        SET FechaFinVigencia  = DATEADD(DAY, -1, @Hoy),
            EsRegistroActual  = 0
        FROM dbo.DimCliente DC
        JOIN BI_Staging.dbo.STG_Clientes S
          ON DC.ClienteID_OLTP = S.ClienteID
         AND S.STG_Estado = 'VALIDO'
         AND DC.EsRegistroActual = 1
        WHERE DC.Ciudad    <> S.Ciudad
           OR DC.Region    <> S.Region
           OR DC.Segmento  <> S.Segmento;

        SET @Versiones = @@ROWCOUNT;

        -- Insertar nueva versión para los clientes que cambiaron
        INSERT INTO dbo.DimCliente (
            ClienteID_OLTP, Nombre, Apellido, NombreCompleto,
            TipoDocumento, NumeroDocumento, Ciudad, Region, Segmento,
            GeografiaKey, FechaInicioVigencia, FechaFinVigencia, EsRegistroActual
        )
        SELECT
            S.ClienteID,
            S.Nombre,
            S.Apellido,
            CONCAT(S.Nombre, ' ', S.Apellido),
            S.TipoDocumento,
            S.NumeroDocumento,
            S.Ciudad,
            S.Region,
            S.Segmento,
            G.GeografiaKey,
            @Hoy,
            NULL,
            1
        FROM BI_Staging.dbo.STG_Clientes S
        JOIN dbo.DimGeografia G
          ON G.Ciudad = S.Ciudad AND G.Region = S.Region
        WHERE S.STG_Estado = 'VALIDO'
          AND NOT EXISTS (
              SELECT 1 FROM dbo.DimCliente DC
              WHERE DC.ClienteID_OLTP = S.ClienteID
                AND DC.EsRegistroActual = 1
          );

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Nuevos + @Versiones,
            RegistrosRechazados = 0
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 11. sp_CargarDimProducto — SCD TIPO 2
-- Misma lógica que DimCliente
-- Atributos SCD: PrecioVenta, PrecioCosto, NombreCategoria
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarDimProducto
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID    INT;
    DECLARE @Inicio   DATETIME = GETDATE();
    DECLARE @Hoy      DATE     = CAST(GETDATE() AS DATE);
    DECLARE @Leidos   INT = 0;
    DECLARE @Nuevos   INT = 0;
    DECLARE @Versiones INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarDimProducto', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @Leidos = COUNT(*) FROM BI_Staging.dbo.STG_Productos WHERE STG_Estado = 'VALIDO';

        -- a) Productos nuevos
        INSERT INTO dbo.DimProducto (
            ProductoID_OLTP, CodigoProducto, NombreProducto, Descripcion,
            CategoriaID_OLTP, NombreCategoria, PrecioVenta, PrecioCosto,
            MargenBruto, MargenPorcentaje, UnidadMedida, StockMinimo,
            FechaInicioVigencia, FechaFinVigencia, EsRegistroActual
        )
        SELECT
            S.ProductoID,
            S.CodigoProducto,
            S.NombreProducto,
            S.Descripcion,
            S.CategoriaID,
            S.NombreCategoria,
            S.PrecioVenta,
            S.PrecioCosto,
            S.PrecioVenta - S.PrecioCosto,
            CAST(((S.PrecioVenta - S.PrecioCosto) / S.PrecioVenta) * 100 AS DECIMAL(6,2)),
            S.UnidadMedida,
            S.StockMinimo,
            '2024-01-01',  -- Fecha base del proyecto: cubre todo el historial de transacciones
            NULL,
            1
        FROM BI_Staging.dbo.STG_Productos S
        WHERE S.STG_Estado = 'VALIDO'
          AND NOT EXISTS (
              SELECT 1 FROM dbo.DimProducto DP
              WHERE DP.ProductoID_OLTP = S.ProductoID
          );

        SET @Nuevos = @@ROWCOUNT;

        -- b) Cerrar versión actual si cambió precio o categoría
        UPDATE dbo.DimProducto
        SET FechaFinVigencia = DATEADD(DAY, -1, @Hoy),
            EsRegistroActual = 0
        FROM dbo.DimProducto DP
        JOIN BI_Staging.dbo.STG_Productos S
          ON DP.ProductoID_OLTP = S.ProductoID
         AND S.STG_Estado = 'VALIDO'
         AND DP.EsRegistroActual = 1
        WHERE DP.PrecioVenta     <> S.PrecioVenta
           OR DP.PrecioCosto     <> S.PrecioCosto
           OR DP.NombreCategoria <> S.NombreCategoria;

        SET @Versiones = @@ROWCOUNT;

        -- Insertar nueva versión
        INSERT INTO dbo.DimProducto (
            ProductoID_OLTP, CodigoProducto, NombreProducto, Descripcion,
            CategoriaID_OLTP, NombreCategoria, PrecioVenta, PrecioCosto,
            MargenBruto, MargenPorcentaje, UnidadMedida, StockMinimo,
            FechaInicioVigencia, FechaFinVigencia, EsRegistroActual
        )
        SELECT
            S.ProductoID,
            S.CodigoProducto,
            S.NombreProducto,
            S.Descripcion,
            S.CategoriaID,
            S.NombreCategoria,
            S.PrecioVenta,
            S.PrecioCosto,
            S.PrecioVenta - S.PrecioCosto,
            CAST(((S.PrecioVenta - S.PrecioCosto) / S.PrecioVenta) * 100 AS DECIMAL(6,2)),
            S.UnidadMedida,
            S.StockMinimo,
            @Hoy,
            NULL,
            1
        FROM BI_Staging.dbo.STG_Productos S
        WHERE S.STG_Estado = 'VALIDO'
          AND NOT EXISTS (
              SELECT 1 FROM dbo.DimProducto DP
              WHERE DP.ProductoID_OLTP = S.ProductoID
                AND DP.EsRegistroActual = 1
          );

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Nuevos + @Versiones,
            RegistrosRechazados = 0
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin = GETDATE(), Estado = 'FALLIDO', MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO

PRINT '=========================================================';
PRINT '  ETL Parte 1 creada exitosamente.';
PRINT '  Procedimientos: 11';
PRINT '  sp_CargarStaging, sp_ValidarStaging,';
PRINT '  sp_CargarDimFecha, sp_CargarDimGeografia,';
PRINT '  sp_CargarDimPromocion, sp_CargarDimCanalVenta,';
PRINT '  sp_CargarDimProveedor, sp_CargarDimTienda,';
PRINT '  sp_CargarDimVendedor, sp_CargarDimCliente,';
PRINT '  sp_CargarDimProducto';
PRINT '=========================================================';
GO
