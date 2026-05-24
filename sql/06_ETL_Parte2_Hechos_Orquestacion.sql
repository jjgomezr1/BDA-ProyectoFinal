/*******************************************************************************
   PROYECTO 3 - BASES DE DATOS AVANZADAS
   SCRIPT: ETL Parte 2 — Carga de Hechos y Orquestador del Pipeline
   Persona 2 — Staging, DW & ETL

   CONTENIDO:
   1. sp_ValidarCalidadDatos    — Reporte de calidad post-validacion (SELECT)
   2. sp_CargarFactVentas       — Granularidad: linea de detalle de factura
   3. sp_CargarFactInventario   — Granularidad: producto x tienda x dia
   4. sp_CargarFactMetas        — Granularidad: tienda x categoria x mes
   5. sp_CargarFactDevoluciones — Granularidad: linea de devolucion
   6. sp_CargarFactCompras      — Granularidad: linea de detalle de compra
   7. sp_CargarFactRentabilidad — Pre-agregacion mensual: producto x tienda
   8. sp_OrquestadorPipeline    — Ejecuta las 5 fases en orden atomico

   DEPENDENCIAS:
   - ETL Parte 1 debe estar compilada y ejecutada al menos una vez
   - STG_* ya validadas (STG_Estado IN ('VALIDO','RECHAZADO'))
   - Dimensiones ya cargadas en BI_DW
   - ETL_Log vive en BI_Staging.dbo.ETL_Log

   CONVENCION DE LLAVES SUBROGADAS:
   - SCD2 (DimCliente, DimProducto): se busca la version vigente a la fecha
     de la transaccion usando FechaInicioVigencia <= FechaEvento
     AND (FechaFinVigencia IS NULL OR FechaFinVigencia >= FechaEvento)
   - Dimension Sin Promocion: PromocionKey = -1 cuando IdCampana es NULL
   - Fechas: FechaKey = CONVERT(INT, FORMAT(fecha, 'yyyyMMdd'))
*******************************************************************************/

USE BI_DW;
GO


-- ===========================================================================
-- 1. sp_ValidarCalidadDatos
-- Genera un reporte de calidad post-ejecucion de sp_ValidarStaging.
-- No modifica datos. Devuelve un conjunto de resultados por tabla STG
-- con: total de registros, validos, rechazados, tasa de rechazo (%) y
-- el top de motivos de rechazo por tabla para evidencia en el informe.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_ValidarCalidadDatos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID  INT;
    DECLARE @Inicio DATETIME = GETDATE();

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_ValidarCalidadDatos', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- -------------------------------------------------------------------
        -- Panel 1: Resumen por tabla
        -- -------------------------------------------------------------------
        SELECT
            'STG_Ventas' AS TablaStaging,
            COUNT(*)                                                   AS TotalRegistros,
            SUM(CASE WHEN STG_Estado = 'VALIDO'     THEN 1 ELSE 0 END) AS Validos,
            SUM(CASE WHEN STG_Estado = 'RECHAZADO'  THEN 1 ELSE 0 END) AS Rechazados,
            CAST(
                SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0)
            AS DECIMAL(5,2))                                           AS TasaRechazo_Pct
        FROM BI_Staging.dbo.STG_Ventas
        UNION ALL
        SELECT 'STG_Productos',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_Productos
        UNION ALL
        SELECT 'STG_Clientes',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_Clientes
        UNION ALL
        SELECT 'STG_Inventario',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_Inventario
        UNION ALL
        SELECT 'STG_Devoluciones',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_Devoluciones
        UNION ALL
        SELECT 'STG_Compras',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_Compras
        UNION ALL
        SELECT 'STG_Metas',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_Metas
        UNION ALL
        SELECT 'STG_AjustesInventario',
            COUNT(*),
            SUM(CASE WHEN STG_Estado = 'VALIDO'    THEN 1 ELSE 0 END),
            SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END),
            CAST(SUM(CASE WHEN STG_Estado = 'RECHAZADO' THEN 1 ELSE 0 END) * 100.0
                / NULLIF(COUNT(*), 0) AS DECIMAL(5,2))
        FROM BI_Staging.dbo.STG_AjustesInventario
        ORDER BY TasaRechazo_Pct DESC;

        -- -------------------------------------------------------------------
        -- Panel 2: Top motivos de rechazo por tabla (para el informe)
        -- -------------------------------------------------------------------
        SELECT
            'STG_Ventas'    AS TablaStaging,
            STG_MensajeError,
            COUNT(*)        AS CantidadRechazados
        FROM BI_Staging.dbo.STG_Ventas
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_Productos', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_Productos
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_Clientes', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_Clientes
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_Inventario', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_Inventario
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_Devoluciones', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_Devoluciones
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_Compras', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_Compras
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_Metas', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_Metas
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        UNION ALL

        SELECT 'STG_AjustesInventario', STG_MensajeError, COUNT(*)
        FROM BI_Staging.dbo.STG_AjustesInventario
        WHERE STG_Estado = 'RECHAZADO'
        GROUP BY STG_MensajeError

        ORDER BY TablaStaging, CantidadRechazados DESC;

        -- -------------------------------------------------------------------
        -- Panel 3: Resumen del DW — cuantos registros hay en cada hecho
        -- (util para verificar que la carga de hechos fue exitosa)
        -- -------------------------------------------------------------------
        SELECT
            'FactVentas'           AS TablaHechos, COUNT(*) AS TotalFilas FROM dbo.FactVentas
        UNION ALL SELECT 'FactInventarioDiario',   COUNT(*) FROM dbo.FactInventarioDiario
        UNION ALL SELECT 'FactMetasComerciales',   COUNT(*) FROM dbo.FactMetasComerciales
        UNION ALL SELECT 'FactDevoluciones',        COUNT(*) FROM dbo.FactDevoluciones
        UNION ALL SELECT 'FactCompras',             COUNT(*) FROM dbo.FactCompras
        UNION ALL SELECT 'FactRentabilidad',        COUNT(*) FROM dbo.FactRentabilidad;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = 0,
            RegistrosCargados   = 0,
            RegistrosRechazados = 0
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin     = GETDATE(),
            Estado       = 'FALLIDO',
            MensajeError = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 2. sp_CargarFactVentas
-- Granularidad: una fila por linea de detalle de factura
--
-- Resolucion de llaves subrogadas:
--   - DimCliente  : version vigente a la fecha de la venta (SCD2 por fecha)
--   - DimProducto : version vigente a la fecha de la venta (SCD2 por fecha)
--   - DimFecha    : FechaKey = YYYYMMDD del campo Fecha
--   - DimTienda   : TiendaID_OLTP directo
--   - DimVendedor : VendedorID_OLTP directo
--   - DimCanalVenta : CanalVentaID_OLTP directo
--   - DimPromocion  : PromocionKey = -1 si IdCampañaComercial es NULL
--
-- Calculo de MontoCosto:
--   Cantidad * PrecioCosto de la version de DimProducto vigente a la fecha
--   (refleja el costo historico real, no el precio actual del catalogo)
--
-- Patron: TRUNCATE + INSERT completo (full-refresh de hechos)
-- Los hechos no tienen SCD — si el OLTP cambia un registro historico,
-- el pipeline completo vuelve a cargar desde cero.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarFactVentas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;
    DECLARE @Rechazados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarFactVentas', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        SELECT @Leidos = COUNT(*)
        FROM BI_Staging.dbo.STG_Ventas
        WHERE STG_Estado = 'VALIDO';

        -- Full-refresh de la tabla de hechos
        TRUNCATE TABLE dbo.FactVentas;

        -- Insercion principal con resolucion de todas las llaves subrogadas
        INSERT INTO dbo.FactVentas (
            FechaKey,
            ClienteKey,
            ProductoKey,
            TiendaKey,
            VendedorKey,
            CanalVentaKey,
            PromocionKey,
            VentaID_OLTP,
            DetalleVentaID_OLTP,
            Cantidad,
            PrecioUnitario,
            MontoVenta,
            MontoCosto,
            MargenBruto
        )
        SELECT
            -- FechaKey: entero YYYYMMDD
            CONVERT(INT, FORMAT(TRY_CAST(S.Fecha AS DATE), 'yyyyMMdd'))    AS FechaKey,

            -- DimCliente: version vigente a la fecha de la venta (SCD2)
            DC.ClienteKey,

            -- DimProducto: version vigente a la fecha de la venta (SCD2)
            DP.ProductoKey,

            -- DimTienda
            DT.TiendaKey,

            -- DimVendedor
            DV.VendedorKey,

            -- DimCanalVenta
            DCV.CanalVentaKey,

            -- DimPromocion: -1 si no hay campana
            ISNULL(DPR.PromocionKey, -1)                                    AS PromocionKey,

            S.VentaID,
            S.DetalleVentaID,
            S.Cantidad,
            S.PrecioUnidad,

            -- MontoVenta: precio de lista * cantidad (ya calculado en Staging)
            S.Subtotal                                                       AS MontoVenta,

            -- MontoCosto: costo historico via DimProducto vigente a la fecha
            S.Cantidad * DP.PrecioCosto                                      AS MontoCosto,

            -- MargenBruto = Venta - Costo
            S.Subtotal - (S.Cantidad * DP.PrecioCosto)                      AS MargenBruto

        FROM BI_Staging.dbo.STG_Ventas S

        -- DimCliente: version vigente a la fecha exacta de la venta
        JOIN dbo.DimCliente DC
          ON DC.ClienteID_OLTP = S.IdCliente
         AND TRY_CAST(S.Fecha AS DATE) >= DC.FechaInicioVigencia
         AND (DC.FechaFinVigencia IS NULL
              OR TRY_CAST(S.Fecha AS DATE) <= DC.FechaFinVigencia)

        -- DimProducto: version vigente a la fecha exacta de la venta
        JOIN dbo.DimProducto DP
          ON DP.ProductoID_OLTP = S.IdProducto
         AND TRY_CAST(S.Fecha AS DATE) >= DP.FechaInicioVigencia
         AND (DP.FechaFinVigencia IS NULL
              OR TRY_CAST(S.Fecha AS DATE) <= DP.FechaFinVigencia)

        -- DimTienda
        JOIN dbo.DimTienda DT
          ON DT.TiendaID_OLTP = S.IdTienda

        -- DimVendedor
        JOIN dbo.DimVendedor DV
          ON DV.VendedorID_OLTP = S.IdVendedor

        -- DimCanalVenta
        JOIN dbo.DimCanalVenta DCV
          ON DCV.CanalVentaID_OLTP = S.IdCanalVenta

        -- DimPromocion: LEFT JOIN para tolerar NULLs (se mapea a -1 con ISNULL)
        LEFT JOIN dbo.DimPromocion DPR
          ON DPR.PromocionID_OLTP = S.IdCampañaComercial

        WHERE S.STG_Estado = 'VALIDO'
          AND S.EstadoVenta = 'Completa';   -- Solo ventas completadas aportan a hechos

        SET @Cargados = @@ROWCOUNT;

        -- Rechazados = validos que no se cargaron (fallos de lookup de llaves)
        SET @Rechazados = @Leidos - @Cargados;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = @Rechazados
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
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
-- 3. sp_CargarFactInventarioDiario
-- Granularidad: una fila por (Producto, Tienda, Dia)
--
-- Fuentes:
--   a) STG_Inventario    — registros del OLTP (InventarioDiario)
--   b) STG_AjustesInventario — registros del CSV externo
--
-- Logica de fusion:
--   Los ajustes del CSV se integran SOBRE el inventario base del OLTP.
--   Si para un mismo (Producto, Tienda, Dia) existe registro en OLTP
--   y uno o mas ajustes en el CSV, el StockFinal del hecho refleja:
--     StockFinal_OLTP + SUM(Ajuste_CSV)
--   Si solo hay ajuste CSV sin base OLTP (stockeo manual), se inserta
--   igual con StockInicial = 0.
--
-- Nota conceptual (resumibilidad):
--   StockFinal es SEMI-ADITIVO: no se suma a lo largo del tiempo
--   (sumar stock del lunes + martes no da nada util), pero si es
--   aditivo a traves de tiendas en un mismo dia (stock total del dia).
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarFactInventarioDiario
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;
    DECLARE @Rechazados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarFactInventarioDiario', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        SELECT @Leidos =
            (SELECT COUNT(*) FROM BI_Staging.dbo.STG_Inventario        WHERE STG_Estado = 'VALIDO') +
            (SELECT COUNT(*) FROM BI_Staging.dbo.STG_AjustesInventario WHERE STG_Estado = 'VALIDO');

        TRUNCATE TABLE dbo.FactInventarioDiario;

        -- -------------------------------------------------------------------
        -- Paso 1: Cargar inventario base desde STG_Inventario (OLTP)
        -- Pre-agrega ajustes CSV del mismo dia sobre el stock base
        -- -------------------------------------------------------------------
        INSERT INTO dbo.FactInventarioDiario (
            FechaKey,
            ProductoKey,
            TiendaKey,
            InventarioID_OLTP,
            StockInicial,
            StockFinal,
            StockPromedio,
            UnidadesEntrantes,
            UnidadesSalientes,
            AjusteManual
        )
        SELECT
            CONVERT(INT, FORMAT(TRY_CAST(INV.Fecha AS DATE), 'yyyyMMdd'))  AS FechaKey,
            DP.ProductoKey,
            DT.TiendaKey,
            INV.InventarioID,
            INV.StockInicial,
            INV.StockFinal + ISNULL(AJ.TotalAjuste, 0)                     AS StockFinal,
            CAST((INV.StockInicial + (INV.StockFinal + ISNULL(AJ.TotalAjuste, 0))) / 2.0 AS DECIMAL(10,2)) AS StockPromedio,
            INV.UnidadesEntrantes,
            INV.UnidadesSalientes,
            -- Sumar ajustes CSV del mismo dia para el mismo (Producto, Tienda)
            ISNULL(AJ.TotalAjuste, 0)                                       AS AjusteManual
        FROM BI_Staging.dbo.STG_Inventario INV

        -- Version vigente del producto a la fecha del inventario
        JOIN dbo.DimProducto DP
          ON DP.ProductoID_OLTP = INV.IdProducto
         AND TRY_CAST(INV.Fecha AS DATE) >= DP.FechaInicioVigencia
         AND (DP.FechaFinVigencia IS NULL
              OR TRY_CAST(INV.Fecha AS DATE) <= DP.FechaFinVigencia)

        JOIN dbo.DimTienda DT
          ON DT.TiendaID_OLTP = INV.IdTienda

        -- Agrupacion de ajustes CSV del mismo mes (STG_AjustesInventario tiene Año+Mes, no Fecha)
        LEFT JOIN (
            SELECT
                DATEFROMPARTS(TRY_CAST(Año AS INT), TRY_CAST(Mes AS INT), 1) AS FechaAjuste,
                ProductoID_CSV,
                TiendaID_CSV,
                SUM(Ajuste)             AS TotalAjuste
            FROM BI_Staging.dbo.STG_AjustesInventario
            WHERE STG_Estado = 'VALIDO'
            GROUP BY TRY_CAST(Año AS INT), TRY_CAST(Mes AS INT), ProductoID_CSV, TiendaID_CSV
        ) AJ
          ON AJ.FechaAjuste     = DATEFROMPARTS(YEAR(TRY_CAST(INV.Fecha AS DATE)), MONTH(TRY_CAST(INV.Fecha AS DATE)), 1)
         AND AJ.ProductoID_CSV  = INV.IdProducto
         AND AJ.TiendaID_CSV    = INV.IdTienda

        WHERE INV.STG_Estado = 'VALIDO';

        SET @Cargados = @@ROWCOUNT;

        -- -------------------------------------------------------------------
        -- Paso 2: Ajustes CSV huerfanos (sin base OLTP en ese dia)
        -- Se insertan como registros independientes para no perder informacion
        -- -------------------------------------------------------------------
        INSERT INTO dbo.FactInventarioDiario (
            FechaKey,
            ProductoKey,
            TiendaKey,
            InventarioID_OLTP,
            StockInicial,
            StockFinal,
            StockPromedio,
            UnidadesEntrantes,
            UnidadesSalientes,
            AjusteManual
        )
        SELECT
            CONVERT(INT, FORMAT(DATEFROMPARTS(TRY_CAST(AJ.Año AS INT), TRY_CAST(AJ.Mes AS INT), 1), 'yyyyMMdd')) AS FechaKey,
            DP.ProductoKey,
            DT.TiendaKey,
            NULL                                                            AS InventarioID_OLTP,
            0                                                               AS StockInicial,
            AJ.Ajuste                                                       AS StockFinal,
            CAST(AJ.Ajuste / 2.0 AS DECIMAL(10,2))                          AS StockPromedio,
            0                                                               AS UnidadesEntrantes,
            0                                                               AS UnidadesSalientes,
            AJ.Ajuste                                                       AS AjusteManual
        FROM BI_Staging.dbo.STG_AjustesInventario AJ

        JOIN dbo.DimProducto DP
          ON DP.ProductoID_OLTP = AJ.ProductoID_CSV
         AND DATEFROMPARTS(TRY_CAST(AJ.Año AS INT), TRY_CAST(AJ.Mes AS INT), 1) >= DP.FechaInicioVigencia
         AND (DP.FechaFinVigencia IS NULL
              OR DATEFROMPARTS(TRY_CAST(AJ.Año AS INT), TRY_CAST(AJ.Mes AS INT), 1) <= DP.FechaFinVigencia)

        JOIN dbo.DimTienda DT
          ON DT.TiendaID_OLTP = AJ.TiendaID_CSV

        WHERE AJ.STG_Estado = 'VALIDO'
          -- Solo los que NO tienen base en STG_Inventario para el mismo dia
          AND NOT EXISTS (
              SELECT 1
              FROM BI_Staging.dbo.STG_Inventario INV
              WHERE INV.STG_Estado  = 'VALIDO'
                AND INV.IdProducto  = AJ.ProductoID_CSV
                AND INV.IdTienda    = AJ.TiendaID_CSV
                AND TRY_CAST(INV.Fecha AS DATE) >= DATEFROMPARTS(TRY_CAST(AJ.Año AS INT), TRY_CAST(AJ.Mes AS INT), 1)
                AND TRY_CAST(INV.Fecha AS DATE) <  DATEADD(MONTH, 1, DATEFROMPARTS(TRY_CAST(AJ.Año AS INT), TRY_CAST(AJ.Mes AS INT), 1))
          );

        SET @Cargados = @Cargados + @@ROWCOUNT;
        SET @Rechazados = @Leidos - @Cargados;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = @Rechazados
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
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
-- 4. sp_CargarFactMetasComerciales
-- Granularidad: una fila por (Tienda, Categoria, Mes)
--
-- La fecha de la meta se mapea al primer dia del mes correspondiente
-- para poder cruzarla con DimFecha usando FechaKey.
-- Ejemplo: meta de Marzo 2025 -> FechaKey = 20250301
--
-- CategoriaID_Resuelto ya fue calculado en sp_ValidarStaging mediante
-- el CASE de homologacion de categorias del CSV.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarFactMetasComerciales
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;
    DECLARE @Rechazados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarFactMetasComerciales', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        SELECT @Leidos = COUNT(*)
        FROM BI_Staging.dbo.STG_Metas
        WHERE STG_Estado = 'VALIDO';

        TRUNCATE TABLE dbo.FactMetasComerciales;

        INSERT INTO dbo.FactMetasComerciales (
            FechaKey,
            TiendaKey,
            ProductoKey,
            CategoriaID_OLTP,
            NombreCategoria,
            ValorMeta,
            Año,
            Mes
        )
        SELECT
            -- Primer dia del mes: Año + Mes + '01'
            CONVERT(INT,
                FORMAT(
                    DATEFROMPARTS(
                        TRY_CAST(M.Año AS INT),
                        TRY_CAST(M.Mes AS INT),
                        1
                    ),
                    'yyyyMMdd'
                )
            )                                       AS FechaKey,

            DT.TiendaKey,

            -- ProductoKey = -1: la granularidad de metas es por categoria, no producto
            -1                                      AS ProductoKey,

            -- CategoriaID ya resuelto por sp_ValidarStaging
            M.CategoriaID_Resuelto                  AS CategoriaID_OLTP,

            -- NombreCategoria: texto original del CSV (ya homologado en Staging)
            M.NombreCategoria_CSV                   AS NombreCategoria,

            TRY_CAST(M.ValorMeta AS DECIMAL(15,2))  AS ValorMeta,

            TRY_CAST(M.Año AS INT)                  AS Año,
            TRY_CAST(M.Mes AS INT)                  AS Mes

        FROM BI_Staging.dbo.STG_Metas M

        JOIN dbo.DimTienda DT
          ON DT.TiendaID_OLTP = M.TiendaID_Resuelto

        -- Verificar que el FechaKey existe en DimFecha (el calendario fue generado)
        JOIN dbo.DimFecha DF
          ON DF.FechaKey = CONVERT(INT,
                FORMAT(
                    DATEFROMPARTS(
                        TRY_CAST(M.Año AS INT),
                        TRY_CAST(M.Mes AS INT),
                        1
                    ),
                    'yyyyMMdd'
                )
             )

        WHERE M.STG_Estado = 'VALIDO'
          AND M.TiendaID_Resuelto    IS NOT NULL
          AND M.CategoriaID_Resuelto IS NOT NULL;

        SET @Cargados = @@ROWCOUNT;
        SET @Rechazados = @Leidos - @Cargados;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = @Rechazados
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
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
-- 5. sp_CargarFactDevoluciones
-- Granularidad: una fila por linea de devolucion (DevolucionID + Producto)
--
-- Nota de diseño: las devoluciones se cruzan contra la version de
-- DimProducto vigente a la fecha de la venta ORIGINAL (no la de la
-- devolucion), porque el costo que se revierte es el del momento de
-- la transaccion original.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarFactDevoluciones
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;
    DECLARE @Rechazados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarFactDevoluciones', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        SELECT @Leidos = COUNT(*)
        FROM BI_Staging.dbo.STG_Devoluciones
        WHERE STG_Estado = 'VALIDO';

        TRUNCATE TABLE dbo.FactDevoluciones;

        INSERT INTO dbo.FactDevoluciones (
            FechaKey,
            FechaVentaKey,
            ProductoKey,
            TiendaKey,
            ClienteKey,
            DevolucionID_OLTP,
            VentaID_OLTP,
            TipoDevolucion,
            Motivo,
            CantidadDevuelta,
            MontoDevuelto
        )
        SELECT
            -- Fecha de la devolucion
            CONVERT(INT, FORMAT(TRY_CAST(D.Fecha AS DATE), 'yyyyMMdd'))         AS FechaKey,

            -- Fecha de la venta que origino la devolucion
            FV.FechaKey                                                         AS FechaVentaKey,

            -- Version del producto vigente a la fecha de la VENTA ORIGINAL
            DP.ProductoKey,

            FV.TiendaKey,
            FV.ClienteKey,
            D.DevolucionID,
            D.IdVenta,
            D.TipoDevolucion,
            D.Motivo,
            D.Cantidad                                                          AS CantidadDevuelta,

            -- MontoDevuelto: reconstruido desde el precio unitario real de la venta
            D.Cantidad * FV.PrecioUnitario                                      AS MontoDevuelto

        FROM BI_Staging.dbo.STG_Devoluciones D

        -- Version de DimProducto vigente a la fecha de la VENTA, no la devolucion
        JOIN dbo.DimProducto DP
          ON DP.ProductoID_OLTP = D.IdProducto
         AND D.FechaVentaOrigen >= DP.FechaInicioVigencia
         AND (DP.FechaFinVigencia IS NULL
              OR D.FechaVentaOrigen <= DP.FechaFinVigencia)

        -- Join con FactVentas para traer las llaves subrogadas de tienda, cliente, fecha de venta original y precio unitario real
        JOIN dbo.FactVentas FV
          ON FV.VentaID_OLTP = D.IdVenta
         AND FV.ProductoKey = DP.ProductoKey

        WHERE D.STG_Estado = 'VALIDO';

        SET @Cargados = @@ROWCOUNT;
        SET @Rechazados = @Leidos - @Cargados;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = @Rechazados
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
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
-- 6. sp_CargarFactCompras
-- Granularidad: una fila por linea de detalle de orden de compra
--
-- Este hecho captura el lado de la cadena de suministro: cuanto se
-- compro a cada proveedor, a que costo y en que tienda ingreso.
-- Permite calcular variaciones entre costo de compra y costo catalogo.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarFactCompras
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;
    DECLARE @Rechazados INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarFactCompras', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        SELECT @Leidos = COUNT(*)
        FROM BI_Staging.dbo.STG_Compras
        WHERE STG_Estado = 'VALIDO';

        TRUNCATE TABLE dbo.FactCompras;

        INSERT INTO dbo.FactCompras (
            FechaKey,
            ProductoKey,
            ProveedorKey,
            TiendaKey,
            CompraID_OLTP,
            DetalleCompraID_OLTP,
            Cantidad,
            PrecioUnitario,
            MontoCompra
        )
        SELECT
            CONVERT(INT, FORMAT(TRY_CAST(C.FechaCompra AS DATE), 'yyyyMMdd'))   AS FechaKey,

            -- Version del producto vigente a la fecha de la compra
            DP.ProductoKey,

            DPV.ProveedorKey,
            DT.TiendaKey,

            C.CompraID,
            C.DetalleCompraID,
            C.Cantidad,
            C.PrecioUnidad                                                       AS PrecioUnitario,
            C.Subtotal                                                           AS MontoCompra

        FROM BI_Staging.dbo.STG_Compras C

        JOIN dbo.DimProducto DP
          ON DP.ProductoID_OLTP = C.IdProducto
         AND TRY_CAST(C.FechaCompra AS DATE) >= DP.FechaInicioVigencia
         AND (DP.FechaFinVigencia IS NULL
              OR TRY_CAST(C.FechaCompra AS DATE) <= DP.FechaFinVigencia)

        JOIN dbo.DimProveedor DPV
          ON DPV.ProveedorID_OLTP = C.IdProveedor

        JOIN dbo.DimTienda DT
          ON DT.TiendaID_OLTP = C.IdTienda

        WHERE C.STG_Estado = 'VALIDO'
          AND C.EstadoCompra = 'Completa';   -- Valor real en OLTP: CHECK constraint permite 'Cancelada','Pendiente','Completa'

        SET @Cargados = @@ROWCOUNT;
        SET @Rechazados = @Leidos - @Cargados;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = @Rechazados
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
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
-- 7. sp_CargarFactRentabilidad
-- Granularidad: una fila por (Producto, Tienda, Año, Mes)
--
-- FUENTE: Se lee directamente desde FactVentas del DW, NO desde Staging.
-- Este hecho es derivado: pre-agrega los margenes ya calculados en
-- FactVentas para acelerar los calculos de rentabilidad en Power BI.
--
-- Metricas calculadas:
--   - TotalVentas       : SUM(MontoVenta)
--   - TotalCosto        : SUM(MontoCosto)
--   - MargenBruto       : TotalVentas - TotalCosto
--   - MargenPorcentaje  : MargenBruto / TotalVentas * 100
--   - UnidadesVendidas  : SUM(Cantidad)
--   - NumeroTransacciones : COUNT(transacciones distintas)
--
-- IMPORTANTE: Este SP debe ejecutarse SIEMPRE despues de sp_CargarFactVentas
-- porque lee desde FactVentas, no desde Staging.
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CargarFactRentabilidad
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @Leidos     INT = 0;
    DECLARE @Cargados   INT = 0;

    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_CargarFactRentabilidad', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        SELECT @Leidos = COUNT(*) FROM dbo.FactVentas;

        TRUNCATE TABLE dbo.FactRentabilidad;

        -- Pre-agregacion mensual por Producto y Tienda desde FactVentas
        INSERT INTO dbo.FactRentabilidad (
            FechaKey,
            ProductoKey,
            TiendaKey,
            Año,
            Mes,
            TotalVentas,
            TotalCosto,
            MargenBruto,
            MargenPorcentaje,
            UnidadesVendidas,
            NumeroTransacciones
        )
        SELECT
            -- FechaKey al primer dia del mes para agrupar por mes
            CONVERT(INT,
                FORMAT(
                    DATEFROMPARTS(DF.Año, DF.Mes, 1),
                    'yyyyMMdd'
                )
            )                                                       AS FechaKey,

            FV.ProductoKey,
            FV.TiendaKey,
            DF.Año,
            DF.Mes,

            SUM(FV.MontoVenta)                                      AS TotalVentas,
            SUM(FV.MontoCosto)                                      AS TotalCosto,
            SUM(FV.MontoVenta) - SUM(FV.MontoCosto)                AS MargenBruto,

            -- Cálculo determinista de margen evitando división por cero
            ISNULL((SUM(FV.MontoVenta) - SUM(FV.MontoCosto)) / NULLIF(SUM(FV.MontoVenta), 0) * 100, 0) AS MargenPorcentaje,

            SUM(FV.Cantidad)                                        AS UnidadesVendidas,
            COUNT(DISTINCT FV.VentaID_OLTP)                         AS NumeroTransacciones

        FROM dbo.FactVentas FV

        -- Unir con DimFecha para obtener Año y Mes de la clave entera
        JOIN dbo.DimFecha DF
          ON DF.FechaKey = FV.FechaKey

        GROUP BY
            DF.Año,
            DF.Mes,
            FV.ProductoKey,
            FV.TiendaKey;

        SET @Cargados = @@ROWCOUNT;

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'EXITOSO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = 0
        WHERE LogID = @LogID;

    END TRY
    BEGIN CATCH
        DECLARE @Error NVARCHAR(1000) = ERROR_MESSAGE();
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin            = GETDATE(),
            Estado              = 'FALLIDO',
            RegistrosLeidos     = @Leidos,
            RegistrosCargados   = @Cargados,
            RegistrosRechazados = 0,
            MensajeError        = @Error
        WHERE LogID = @LogID;
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- 8. sp_OrquestadorPipeline
-- Ejecuta las 5 fases del ecosistema ETL en orden atomico y secuencial.
-- Si cualquier fase falla, el pipeline se detiene y registra el fallo
-- sin continuar hacia las fases siguientes (control de cascada).
--
-- ORDEN DE EJECUCION:
--   Fase 1 — Extraccion   : sp_CargarStaging
--   Fase 2 — Transformacion: sp_ValidarStaging
--   Fase 3 — Dimensiones  : sp_CargarDimFecha -> sp_CargarDimGeografia
--                           -> sp_CargarDimPromocion -> sp_CargarDimCanalVenta
--                           -> sp_CargarDimProveedor -> sp_CargarDimTienda
--                           -> sp_CargarDimVendedor  -> sp_CargarDimCliente
--                           -> sp_CargarDimProducto
--   Fase 4 — Hechos Base  : sp_CargarFactVentas -> sp_CargarFactInventarioDiario
--                           -> sp_CargarFactMetasComerciales
--                           -> sp_CargarFactDevoluciones -> sp_CargarFactCompras
--   Fase 5 — Hechos Derivados: sp_CargarFactRentabilidad
--
-- NOTA: sp_ValidarCalidadDatos se puede llamar al final de forma informativa.
-- No es parte del pipeline de carga sino un reporte de auditoria.
--
-- USO:
--   EXEC BI_DW.dbo.sp_OrquestadorPipeline;
--   -- Ver resultado:
--   SELECT * FROM BI_Staging.dbo.ETL_Log ORDER BY LogID DESC;
-- ===========================================================================
CREATE OR ALTER PROCEDURE dbo.sp_OrquestadorPipeline
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogID      INT;
    DECLARE @Inicio     DATETIME = GETDATE();
    DECLARE @FaseActual NVARCHAR(100);
    DECLARE @Error      NVARCHAR(1000);

    -- Abrir registro maestro del orquestador
    INSERT INTO BI_Staging.dbo.ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES ('sp_OrquestadorPipeline', @Inicio, 'EN EJECUCION');
    SET @LogID = SCOPE_IDENTITY();

    BEGIN TRY

        -- ===================================================================
        -- FASE 1: Extraccion — OLTP -> Staging
        -- ===================================================================
        SET @FaseActual = 'Fase 1 — sp_CargarStaging';
        EXEC BI_Staging.dbo.sp_CargarStaging;

        -- ===================================================================
        -- FASE 2: Transformacion y calidad — Staging
        -- sp_ValidarStaging vive en BI_Staging, no en BI_DW
        -- ===================================================================
        SET @FaseActual = 'Fase 2 — sp_ValidarStaging';
        EXEC BI_Staging.dbo.sp_ValidarStaging;

        -- ===================================================================
        -- FASE 3: Carga de dimensiones (orden estricto por dependencias)
        -- DimFecha y DimGeografia primero (sin dependencias)
        -- DimProveedor, DimTienda dependen de DimGeografia
        -- DimVendedor depende de DimTienda
        -- DimCliente depende de DimGeografia
        -- DimProducto no depende de geografias
        -- ===================================================================
        SET @FaseActual = 'Fase 3 — sp_CargarDimFecha';
        EXEC dbo.sp_CargarDimFecha;

        SET @FaseActual = 'Fase 3 — sp_CargarDimGeografia';
        EXEC dbo.sp_CargarDimGeografia;

        SET @FaseActual = 'Fase 3 — sp_CargarDimPromocion';
        EXEC dbo.sp_CargarDimPromocion;

        SET @FaseActual = 'Fase 3 — sp_CargarDimCanalVenta';
        EXEC dbo.sp_CargarDimCanalVenta;

        SET @FaseActual = 'Fase 3 — sp_CargarDimProveedor';
        EXEC dbo.sp_CargarDimProveedor;

        SET @FaseActual = 'Fase 3 — sp_CargarDimTienda';
        EXEC dbo.sp_CargarDimTienda;

        SET @FaseActual = 'Fase 3 — sp_CargarDimVendedor';
        EXEC dbo.sp_CargarDimVendedor;

        SET @FaseActual = 'Fase 3 — sp_CargarDimCliente';
        EXEC dbo.sp_CargarDimCliente;

        SET @FaseActual = 'Fase 3 — sp_CargarDimProducto';
        EXEC dbo.sp_CargarDimProducto;

        -- ===================================================================
        -- FASE 4: Carga de hechos base
        -- FactVentas primero (FactRentabilidad la necesita como fuente)
        -- Las demas son independientes entre si
        -- ===================================================================
        SET @FaseActual = 'Fase 4 — sp_CargarFactVentas';
        EXEC dbo.sp_CargarFactVentas;

        SET @FaseActual = 'Fase 4 — sp_CargarFactInventarioDiario';
        EXEC dbo.sp_CargarFactInventarioDiario;

        SET @FaseActual = 'Fase 4 — sp_CargarFactMetasComerciales';
        EXEC dbo.sp_CargarFactMetasComerciales;

        SET @FaseActual = 'Fase 4 — sp_CargarFactDevoluciones';
        EXEC dbo.sp_CargarFactDevoluciones;

        SET @FaseActual = 'Fase 4 — sp_CargarFactCompras';
        EXEC dbo.sp_CargarFactCompras;

        -- ===================================================================
        -- FASE 5: Hechos derivados (lee desde FactVentas, no desde Staging)
        -- ===================================================================
        SET @FaseActual = 'Fase 5 — sp_CargarFactRentabilidad';
        EXEC dbo.sp_CargarFactRentabilidad;

        -- ===================================================================
        -- Reporte de calidad al final (informativo, no bloquea el pipeline)
        -- ===================================================================
        EXEC dbo.sp_ValidarCalidadDatos;

        -- Cerrar registro maestro como exitoso
        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin     = GETDATE(),
            Estado       = 'EXITOSO',
            MensajeError = CONCAT(
                'Pipeline completado exitosamente. ',
                '5 fases ejecutadas. ',
                'Duracion: ',
                DATEDIFF(SECOND, @Inicio, GETDATE()),
                ' segundos.'
            )
        WHERE LogID = @LogID;

        -- Imprimir resumen en consola SSMS
        PRINT '=========================================================';
        PRINT '  PIPELINE ETL COMPLETADO';
        PRINT '  Duracion: ' + CAST(DATEDIFF(SECOND, @Inicio, GETDATE()) AS NVARCHAR) + ' segundos';
        PRINT '  Ver detalle: SELECT * FROM BI_Staging.dbo.ETL_Log ORDER BY LogID DESC';
        PRINT '=========================================================';

    END TRY
    BEGIN CATCH
        SET @Error = CONCAT(
            'FALLO en [', @FaseActual, ']: ', ERROR_MESSAGE()
        );

        UPDATE BI_Staging.dbo.ETL_Log
        SET FechaFin     = GETDATE(),
            Estado       = 'FALLIDO',
            MensajeError = @Error
        WHERE LogID = @LogID;

        PRINT '=========================================================';
        PRINT '  PIPELINE ETL FALLIDO';
        PRINT '  ' + @Error;
        PRINT '  Ver detalle: SELECT * FROM BI_Staging.dbo.ETL_Log ORDER BY LogID DESC';
        PRINT '=========================================================';

        -- Re-lanzar para que el caller (SSMS o job) sepa que fallo
        RAISERROR(@Error, 16, 1);
    END CATCH
END;
GO


-- ===========================================================================
-- INSTRUCCIONES DE EJECUCION
-- ===========================================================================
-- 1. Compilar este script completo en SSMS con el contexto en BI_DW
--    USE BI_DW; ejecutar el script
--
-- 2. Para ejecutar el pipeline completo:
--    EXEC BI_DW.dbo.sp_OrquestadorPipeline;
--
-- 3. Para verificar el resultado:
--    SELECT * FROM BI_Staging.dbo.ETL_Log ORDER BY LogID DESC;
--
-- 4. Para ver el reporte de calidad sin correr el pipeline:
--    EXEC BI_DW.dbo.sp_ValidarCalidadDatos;
--
-- 5. Para ejecutar solo un hecho especifico (re-carga parcial):
--    EXEC BI_DW.dbo.sp_CargarFactVentas;
--    EXEC BI_DW.dbo.sp_CargarFactRentabilidad;   -- siempre despues de Ventas
-- ===========================================================================

PRINT '=========================================================';
PRINT '  ETL Parte 2 creada exitosamente.';
PRINT '  Procedimientos: 8';
PRINT '  sp_ValidarCalidadDatos,';
PRINT '  sp_CargarFactVentas,';
PRINT '  sp_CargarFactInventarioDiario,';
PRINT '  sp_CargarFactMetasComerciales,';
PRINT '  sp_CargarFactDevoluciones,';
PRINT '  sp_CargarFactCompras,';
PRINT '  sp_CargarFactRentabilidad,';
PRINT '  sp_OrquestadorPipeline';
PRINT '=========================================================';
GO