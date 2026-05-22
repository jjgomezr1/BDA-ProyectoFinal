/*******************************************************************************
   PROYECTO 3 - SISTEMAS DE INFORMACIÓN (SI3009)
   SCRIPT DE POBLADO DE DATOS SINTÉTICOS LIMPIOS - BASE DE DATOS: BI_OLTP
   
   Cumple con:
   - 50,000 Facturas de Ventas (Mínimo exigido)
   - >150,000 Líneas de Detalle de Ventas (Mínimo exigido)
   - Poblado completo de Compras, DetalleCompras, InventarioDiario y Devoluciones
   - Exclusión de la tabla MetasComerciales (Mapeada para archivo plano externo)
   - Cero anomalías sembradas (Estructuras transaccionales íntegras)
*******************************************************************************/

USE BI_OLTP;
GO

SET NOCOUNT ON;

PRINT 'Iniciando limpieza previa de datos transaccionales y maestros...';

-- ==========================================================
-- 1. LIMPIEZA DE TABLAS (Respetando restricciones de FK)
-- ==========================================================
DELETE FROM dbo.InventarioDiario;
DELETE FROM dbo.Devoluciones;
DELETE FROM dbo.DetalleCompras;
DELETE FROM dbo.DetalleVentas;

ALTER TABLE dbo.Ventas NOCHECK CONSTRAINT ALL;
DELETE FROM dbo.Ventas;
ALTER TABLE dbo.Ventas CHECK CONSTRAINT ALL;

ALTER TABLE dbo.Compras NOCHECK CONSTRAINT ALL;
DELETE FROM dbo.Compras;
ALTER TABLE dbo.Compras CHECK CONSTRAINT ALL;

ALTER TABLE dbo.Vendedores NOCHECK CONSTRAINT ALL;
DELETE FROM dbo.Vendedores;
ALTER TABLE dbo.Vendedores CHECK CONSTRAINT ALL;

ALTER TABLE dbo.Productos NOCHECK CONSTRAINT ALL;
DELETE FROM dbo.Productos;
ALTER TABLE dbo.Productos CHECK CONSTRAINT ALL;

DELETE FROM dbo.Clientes;
DELETE FROM dbo.Tiendas;
DELETE FROM dbo.Proveedores;
DELETE FROM dbo.Categorias;
DELETE FROM dbo.CanalVenta;
DELETE FROM dbo.CampañasComerciales;
GO

-- ==========================================================
-- 2. POBLADO DE TABLAS MAESTRAS ABSOLUTAS
-- ==========================================================
PRINT 'Poblando tablas maestras...';

-- 2.1 Categorías
INSERT INTO dbo.Categorias (Nombre, Descripcion) VALUES 
('Tecnología', 'Dispositivos electrónicos, computadores y accesorios'),
('Hogar y Cocina', 'Muebles, electrodomésticos menores y utensilios'),
('Moda y Calzado', 'Ropa para adultos, niños y calzado deportivo/formal'),
('Deportes y Fitness', 'Maquinaria de ejercicio, ropa deportiva y accesorios'),
('Juguetería', 'Juegos de mesa, juguetes interactivos y coleccionables'),
('Libros y Papelería', 'Útiles escolares, material de oficina y literatura'),
('Automotriz', 'Accesorios para vehículos, herramientas y fluidos'),
('Salud y Belleza', 'Cuidado personal, cosméticos y suplementos'),
('Mascotas', 'Alimento y accesorios para perros, gatos y otras mascotas'),
('Alimentos y Bebidas', 'Productos no perecederos y licores premium'),
('Herramientas', 'Herramientas manuales, eléctricas y ferretería general'),
('Electrodomésticos', 'Neveras, lavadoras, televisores y grandes equipos');

-- 2.2 Proveedores
INSERT INTO dbo.Proveedores (Nombre, NumeroIdentificacionTributaria, Ciudad, NombreContacto, Telefono) VALUES 
('Distribuciones Industriales S.A.S.', '900123456-1', 'Medellín', 'Carlos Mendoza', '6043214567'),
('TecnoMayoristas Colombia', '860987654-2', 'Bogotá', 'Diana Guerrero', '6017458962'),
('Logística y Suministros del Valle', '901456123-3', 'Cali', 'Andrés Felipe', '6024859632'),
('Importaciones del Caribe Ltda.', '800321789-4', 'Barranquilla', 'Marta Cantillo', '6053698521'),
('Ferretería y Equipos del Eje', '900753159-5', 'Pereira', 'Jorge Robledo', '6063154789');

-- 2.3 Tiendas (Con FechaInicioOperaciones coherente y pasada)
INSERT INTO dbo.Tiendas (Nombre, Ciudad, Region, Direccion, Telefono, FechaInicioOperaciones) VALUES 
('Éxito Poblado', 'Medellín', 'Antioquia', 'Calle 10 #43E-20', '6042660000', '2020-01-15'),
('Unicentro Bogotá', 'Bogotá', 'Bogotá DC', 'Avenida Carrera 15 #122-30', '6016123456', '2020-03-22'),
('Chipichape Cali', 'Cali', 'Valle del Cauca', 'Calle 38 Norte #6N-35', '6026591000', '2021-05-10'),
('Buenavista Barranquilla', 'Barranquilla', 'Atlántico', 'Calle 98 #52-115', '6053784000', '2021-08-18'),
('Arboleda Pereira', 'Pereira', 'Eje Cafetero', 'Avenida Circunvalar #5-20', '6063401000', '2022-02-02'),
('Bucaramanga Centro', 'Bucaramanga', 'Santander', 'Carrera 19 #35-02', '6076304000', '2022-11-12'),
('Viva Envigado', 'Envigado', 'Antioquia', 'Carrera 48 #32S-29', '6044482020', '2023-01-20'),
('Llanogrande Rionegro', 'Rionegro', 'Antioquia', 'Kilómetro 8 Vía Don Diego', '6045619000', '2023-06-14'),
('Plaza de las Américas', 'Bogotá', 'Bogotá DC', 'Carrera 71D #6-94 Sur', '6014490000', '2023-10-05'),
('Mayorista Itagüí', 'Itagüí', 'Antioquia', 'Calle 85 #48-01', '6043725000', '2024-01-10');

-- 2.4 CanalVenta
INSERT INTO dbo.CanalVenta (Nombre, Descripcion) VALUES 
('Tienda Física', 'Venta presencial directa en el punto físico'),
('Sitio Web', 'Plataforma e-commerce corporativa desktop/mobile'),
('App Móvil', 'Transacciones nativas desde la aplicación iOS y Android'),
('WhatsApp Business', 'Ventas cerradas mediante canales conversacionales guiados');

-- 2.5 CampañasComerciales (Rango adaptado para cubrir ventas de 2024 a inicios de 2026)
INSERT INTO dbo.CampañasComerciales (Nombre, FechaInicio, FechaFin, TipoCampaña) VALUES 
('Sin Campaña', '2024-01-01', '2026-05-01', 'Permanente'),
('Black Friday 2024', '2024-11-24', '2024-11-30', 'Estacional'),
('Navidad Dorada 2024', '2024-12-01', '2024-12-25', 'Estacional'),
('Aniversario Tienda 2025', '2025-05-01', '2025-05-08', 'Especial'),
('Black Friday 2025', '2025-11-23', '2025-11-30', 'Estacional'),
('Navidad Mágica 2025', '2025-12-01', '2025-12-25', 'Estacional');
GO

-- ==========================================================
-- 3. POBLADO DE TABLAS CON DEPENDENCIAS (Primer Nivel)
-- ==========================================================
PRINT 'Poblando Clientes, Productos y Vendedores...';

-- 3.1 Clientes (1,500 registros con nombres colombianos realistas)
DECLARE @i INT = 1;
DECLARE @TiposDoc TABLE (ID INT IDENTITY(1,1), Doc VARCHAR(20));
INSERT INTO @TiposDoc VALUES ('CC'), ('NIT'), ('CE'), ('Pasaporte'), ('TI');

DECLARE @Segmentos TABLE (ID INT IDENTITY(1,1), Seg NVARCHAR(50));
INSERT INTO @Segmentos VALUES ('Minorista'), ('Mayorista'), ('Corporativo'), ('VIP'), ('Regular');

-- Nombres y apellidos colombianos representativos
DECLARE @Nombres  TABLE (ID INT IDENTITY(1,1), Nom NVARCHAR(100));
INSERT INTO @Nombres VALUES
('Carlos'),('María'),('Andrés'),('Valentina'),('Juan'),('Camila'),
('Felipe'),('Laura'),('Santiago'),('Daniela'),('Sebastián'),('Alejandra'),
('Julián'),('Natalia'),('David'),('Paola'),('Jorge'),('Catalina'),
('Miguel'),('Luisa'),('Ricardo'),('Sofía'),('Hernando'),('Gloria'),
('Fabio'),('Marcela'),('Iván'),('Adriana'),('Oswaldo'),('Claudia');

DECLARE @Apellidos TABLE (ID INT IDENTITY(1,1), Ape NVARCHAR(100));
INSERT INTO @Apellidos VALUES
('García'),('Rodríguez'),('Martínez'),('López'),('González'),('Pérez'),
('Sánchez'),('Ramírez'),('Torres'),('Flores'),('Vargas'),('Moreno'),
('Jiménez'),('Ruiz'),('Herrera'),('Medina'),('Castillo'),('Ortiz'),
('Gómez'),('Reyes'),('Morales'),('Cruz'),('Ramos'),('Aguilar'),
('Suárez'),('Miranda'),('Mendoza'),('Ospina'),('Cárdenas'),('Ríos');

DECLARE @TotalNombres INT = (SELECT COUNT(*) FROM @Nombres);
DECLARE @TotalApellidos INT = (SELECT COUNT(*) FROM @Apellidos);

-- Ciudades colombianas con sus regiones
DECLARE @Ciudades TABLE (ID INT IDENTITY(1,1), Ciudad NVARCHAR(100), Region NVARCHAR(100));
INSERT INTO @Ciudades VALUES
('Medellín','Antioquia'),('Bogotá','Bogotá DC'),('Cali','Valle del Cauca'),
('Barranquilla','Atlántico'),('Bucaramanga','Santander'),('Pereira','Eje Cafetero'),
('Manizales','Caldas'),('Cartagena','Bolívar'),('Cúcuta','Norte de Santander'),
('Ibagué','Tolima'),('Santa Marta','Magdalena'),('Villavicencio','Meta');
DECLARE @TotalCiudades INT = (SELECT COUNT(*) FROM @Ciudades);

WHILE @i <= 1500
BEGIN
    DECLARE @IdDoc  INT = (ABS(CHECKSUM(NEWID())) % 5) + 1;
    DECLARE @IdSeg  INT = (ABS(CHECKSUM(NEWID())) % 5) + 1;
    DECLARE @IdNom  INT = (ABS(CHECKSUM(NEWID())) % @TotalNombres)  + 1;
    DECLARE @IdApe  INT = (ABS(CHECKSUM(NEWID())) % @TotalApellidos) + 1;
    DECLARE @IdCiu  INT = (ABS(CHECKSUM(NEWID())) % @TotalCiudades)  + 1;

    INSERT INTO dbo.Clientes (Nombre, Apellido, TipoDocumento, NumeroDocumento, Ciudad, Region, Segmento, FechaRegistro)
    VALUES (
        (SELECT Nom FROM @Nombres    WHERE ID = @IdNom),
        (SELECT Ape FROM @Apellidos  WHERE ID = @IdApe),
        (SELECT Doc FROM @TiposDoc   WHERE ID = @IdDoc),
        CAST(10000000 + @i * 317 + ABS(CHECKSUM(NEWID())) % 9999 AS VARCHAR(30)),
        (SELECT Ciudad FROM @Ciudades WHERE ID = @IdCiu),
        (SELECT Region FROM @Ciudades WHERE ID = @IdCiu),
        (SELECT Seg FROM @Segmentos  WHERE ID = @IdSeg),
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 730), '2024-12-31')
    );
    SET @i = @i + 1;
END;

-- 3.2 Productos (250 registros limpios respetando Margen y Códigos únicos)
SET @i = 1;

-- Tabla de nombres por categoría (compatible con todas las versiones de SQL Server)
DECLARE @NombresProd TABLE (ID INT IDENTITY(1,1), CatID INT, NomProd NVARCHAR(150));
INSERT INTO @NombresProd (CatID, NomProd) VALUES
(1,'Portátil HP Pavilion 15'),(1,'Smartphone Samsung Galaxy A54'),(1,'Tablet Lenovo Tab M10'),
(1,'Monitor LG 24 Full HD'),(1,'Teclado Logitech MX Keys'),(1,'Mouse Inalámbrico HP'),
(1,'Audífonos Sony WH-1000XM4'),(1,'Cámara Canon EOS R50'),(1,'Smart TV Samsung 55'),
(1,'Disco SSD Kingston 1TB'),(1,'Router TP-Link WiFi 6'),(1,'Impresora Epson EcoTank'),
(2,'Sartén Antiadherente Tramontina'),(2,'Cafetera Oster 12 Tazas'),(2,'Juego de Ollas Imusa 5 Piezas'),
(2,'Licuadora Oster 700W'),(2,'Tostadora Black Decker'),(2,'Set Cuchillos Chef 6 Piezas'),
(2,'Horno Eléctrico Haceb 45L'),(2,'Sandwichera Oster'),(2,'Vajilla 24 Piezas Corona'),
(2,'Organizador Modular Plástico'),(2,'Exprimidor Eléctrico Hamilton'),(2,'Batidora KitchenAid'),
(3,'Camiseta Cuello V Algodón'),(3,'Jean Slim Fit Azul'),(3,'Vestido Floral Mujer'),
(3,'Chaqueta Deportiva Hombre'),(3,'Tenis Casual Mujer'),(3,'Zapatos Oxford Cuero'),
(3,'Blusa Manga Larga Mujer'),(3,'Pantaloneta Deportiva'),(3,'Bota Cuero Hombre'),
(3,'Conjunto Pijama Algodón'),(3,'Camisa Lino Hombre'),(3,'Falda Plisada Mujer'),
(4,'Bicicleta Estática Sunny Health'),(4,'Mancuernas Ajustables 20kg'),(4,'Colchoneta Yoga Antideslizante'),
(4,'Banda de Resistencia Set x5'),(4,'Cuerda de Saltar Pro'),(4,'Guantes Boxeo 12oz'),
(4,'Botella Térmica 1L'),(4,'Caminadora Eléctrica Sunny'),(4,'Balón Fútbol Adidas'),
(4,'Zapatillas Running Nike'),(4,'Barra Dominadas Puerta'),(4,'Rodillera Deportiva Par'),
(5,'LEGO Technic 42154'),(5,'Muñeca Barbie Fashionista'),(5,'Carro Control Remoto 4x4'),
(5,'Juego de Mesa Monopoly'),(5,'Set Pintura Dedos 12 Colores'),(5,'Rompecabezas 1000 Piezas'),
(5,'Peluche Oso Gigante 60cm'),(5,'Set Construcción 200 Piezas'),(5,'Pista Carros Hot Wheels'),
(5,'Juego UNO Edición Especial'),(5,'Bloques Lógicos Madera'),(5,'Títere Teatro Familiar'),
(6,'Resma Papel Carta 500 Hojas'),(6,'Cuaderno Universitario 200 Hojas'),(6,'Set Bolígrafos Stabilo 20u'),
(6,'Carpeta Archivadora A4'),(6,'Libro Contabilidad Básica'),(6,'Marcadores Permanentes x10'),
(6,'Agenda Ejecutiva 2025'),(6,'Calculadora Científica Casio'),(6,'Paquete Post-its Colores'),
(6,'Corta Papel Profesional A3'),(6,'Resaltadores Colores x6'),(6,'Grapadora Metálica Rapid'),
(7,'Aceite Motor Mobil 1 4L'),(7,'Filtro Aire Universal'),(7,'Llanta 195/65R15'),
(7,'Batería Automotriz 45Ah'),(7,'Kit Herramientas Auto 40 Piezas'),(7,'Limpiabrisas Bosch Par'),
(7,'Aromatizante Tablero Vanilla'),(7,'Cámara Reversa HD'),(7,'Alarma Auto Panacom'),
(7,'Cable Auxiliar Audio Auto'),(7,'Inflador Digital Portátil'),(7,'Tapetes Caucho Auto'),
(8,'Crema Hidratante Cetaphil 250ml'),(8,'Shampoo Pantene Pro-V 400ml'),(8,'Perfume Carolina Herrera 100ml'),
(8,'Bloqueador Solar SPF50 200ml'),(8,'Afeitadora Gillette Fusion'),(8,'Vitamina C 1000mg x60'),
(8,'Crema Antiedad LOreal'),(8,'Desodorante Rexona 150ml'),(8,'Maquillaje Base Maybelline'),
(8,'Cepillo Eléctrico Oral-B'),(8,'Sérum Vitamina E 30ml'),(8,'Mascarilla Capilar Elvive'),
(9,'Alimento Perro Royal Canin 15kg'),(9,'Alimento Gato Whiskas 3kg'),(9,'Collar Anti-Pulgas Seresto'),
(9,'Comedero Doble Acero Inox'),(9,'Cama Mascota Orthopedic L'),(9,'Juguete Kong Classic M'),
(9,'Shampoo Mascota Neutro 500ml'),(9,'Correa Retráctil 5m'),(9,'Arena Sanitaria Gato 5kg'),
(9,'Vitaminas Mascota Omega 3'),(9,'Transportador Perro Mediano'),(9,'Rascador Gato Torre'),
(10,'Arroz Supremo 5kg'),(10,'Aceite Oleocampo 3L'),(10,'Café Sello Rojo 500g'),
(10,'Azúcar Manuelita 2kg'),(10,'Jabón Dersa x5 Barras'),(10,'Sal Refisal 1kg'),
(10,'Panela Pulverizada 500g'),(10,'Chocolate Corona 250g'),(10,'Atún Van Camps Pack x3'),
(10,'Arvejas La Especial 500g'),(10,'Pasta Doria 500g'),(10,'Leche Colanta 1L'),
(11,'Taladro Inalámbrico Dewalt 20V'),(11,'Nivel Láser Bosch'),(11,'Juego Llaves 12 Piezas'),
(11,'Pulidora Angular 4.5 Bosch'),(11,'Cinta Métrica Stanley 8m'),(11,'Destornilladores x6'),
(11,'Sierra Circular 7 Black Decker'),(11,'Pistola de Calor 1800W'),(11,'Compresor Aire 24L'),
(11,'Tornillos Drywall Caja x500'),(11,'Llave Expansiva 12 Pulgadas'),(11,'Serrucho Profesional'),
(12,'Nevera Haceb 310L No Frost'),(12,'Lavadora LG 12kg Inverter'),(12,'Televisor Samsung 50 4K UHD'),
(12,'Microondas Electrolux 30L'),(12,'Aire Acondicionado Mirage 9000BTU'),(12,'Secadora Mabe 18kg'),
(12,'Lavavajillas Whirlpool 12 Puestos'),(12,'Plancha Vapor Imusa 2400W'),(12,'Aspiradora Electrolux 1600W'),
(12,'Calentador Haceb 10 Litros'),(12,'Ventilador Industrial Torre'),(12,'Horno Microondas Haceb');

DECLARE @TotalNomProd INT = (SELECT COUNT(*) FROM @NombresProd);

WHILE @i <= 250
BEGIN
    DECLARE @CatID INT = (SELECT TOP 1 CategoriaID FROM dbo.Categorias ORDER BY NEWID());
    DECLARE @Costo DECIMAL(12,2) = CAST((RAND() * 450000) + 5000 AS DECIMAL(12,2));
    DECLARE @Venta DECIMAL(12,2) = CAST(@Costo * (1.25 + (RAND() * 0.50)) AS DECIMAL(12,2));

    DECLARE @NomProd NVARCHAR(150);
    SELECT TOP 1 @NomProd = NomProd
    FROM @NombresProd
    WHERE CatID = @CatID
    ORDER BY NEWID();

    -- Si no hay nombre para esa categoría, usar genérico
    IF @NomProd IS NULL
        SET @NomProd = CONCAT('Producto Cat-', @CatID);

    INSERT INTO dbo.Productos (Nombre, Descripcion, CategoriaID, PrecioVenta, PrecioCosto, CodigoProducto, UnidadMedida, StockMinimo)
    VALUES (
        CONCAT(@NomProd, ' #', @i),
        CONCAT('Producto de la categoría ', (SELECT Nombre FROM dbo.Categorias WHERE CategoriaID = @CatID), ' — ref. PROD-', 10000 + @i),
        @CatID,
        @Venta,
        @Costo,
        CONCAT('PROD-', 10000 + @i),
        CASE @i % 3 WHEN 0 THEN 'Unidad' WHEN 1 THEN 'Caja x12' ELSE 'Unidad' END,
        CASE @i % 4 WHEN 0 THEN 5 WHEN 1 THEN 10 WHEN 2 THEN 20 ELSE 0 END
    );
    SET @NomProd = NULL;
    SET @i = @i + 1;
END;

-- 3.3 Vendedores (25 asesores asignados a tiendas reales con FechaIngreso válida)
SET @i = 1;

WHILE @i <= 25
BEGIN
    DECLARE @TiendaAsig INT = (SELECT TOP 1 TiendaID FROM dbo.Tiendas ORDER BY NEWID());
    DECLARE @NomVen  NVARCHAR(100) = (SELECT TOP 1 Nom FROM @Nombres   ORDER BY NEWID());
    DECLARE @ApeVen  NVARCHAR(100) = (SELECT TOP 1 Ape FROM @Apellidos ORDER BY NEWID());
    INSERT INTO dbo.Vendedores (Nombre, Apellido, IdTiendaAsignada, FechaIngreso)
    VALUES (
        @NomVen,
        @ApeVen,
        @TiendaAsig,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 730), '2024-01-01')
    );
    SET @i = @i + 1;
END;
GO

-- ==========================================================
-- 4. POBLADO MASIVO DE VENTAS Y DETALLES (50,000 / >150,000)
-- ==========================================================
PRINT 'Generando masivamente 50,000 Ventas y sus detalles...';

DECLARE @FechaInicio DATE = '2024-01-01';
DECLARE @FechaFin DATE = '2026-04-30'; -- Rango controlado inferior a la fecha actual de 2026
DECLARE @DiasTotales INT = DATEDIFF(DAY, @FechaInicio, @FechaFin);

-- Estructuras de aceleración en memoria
-- Limpiar tablas temporales si quedaron de una ejecución anterior
IF OBJECT_ID('tempdb..#TClientes')   IS NOT NULL DROP TABLE #TClientes;
IF OBJECT_ID('tempdb..#TProductos')  IS NOT NULL DROP TABLE #TProductos;
IF OBJECT_ID('tempdb..#TVendedores') IS NOT NULL DROP TABLE #TVendedores;
IF OBJECT_ID('tempdb..#TCanales')    IS NOT NULL DROP TABLE #TCanales;

SELECT ClienteID, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum INTO #TClientes  FROM dbo.Clientes;
SELECT ProductoID, PrecioVenta, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum INTO #TProductos  FROM dbo.Productos;
SELECT VendedorID, IdTiendaAsignada, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum INTO #TVendedores FROM dbo.Vendedores;
SELECT CanalVentaID, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum INTO #TCanales FROM dbo.CanalVenta;

DECLARE @C_Clientes INT = (SELECT COUNT(*) FROM #TClientes);
DECLARE @C_Productos INT = (SELECT COUNT(*) FROM #TProductos);
DECLARE @C_Vendedores INT = (SELECT COUNT(*) FROM #TVendedores);
DECLARE @C_Canales INT = (SELECT COUNT(*) FROM #TCanales);

DECLARE @v INT = 1;
DECLARE @TotalFacturas INT = 50000;

BEGIN TRANSACTION;

WHILE @v <= @TotalFacturas
BEGIN
    DECLARE @DiasRandom  INT  = ABS(CHECKSUM(NEWID())) % (@DiasTotales + 1);
    DECLARE @FechaVenta  DATE = DATEADD(DAY, @DiasRandom, @FechaInicio);

    -- Selección con TOP 1 para garantizar exactamente 1 valor siempre
    DECLARE @CliSel    INT;
    DECLARE @VenSel    INT;
    DECLARE @TiendaSel INT;
    DECLARE @CanalSel  INT;
    DECLARE @VendedIdx INT = (ABS(CHECKSUM(NEWID())) % @C_Vendedores) + 1;

    SELECT TOP 1 @CliSel   = ClienteID
    FROM #TClientes
    ORDER BY ABS(CHECKSUM(NEWID()));

    SELECT TOP 1 @VenSel   = VendedorID,
                 @TiendaSel = IdTiendaAsignada
    FROM #TVendedores
    ORDER BY ABS(CHECKSUM(NEWID()));

    SELECT TOP 1 @CanalSel = CanalVentaID
    FROM #TCanales
    ORDER BY ABS(CHECKSUM(NEWID()));

    -- Campaña activa en esa fecha (1 = Sin Campaña, es el fallback)
    DECLARE @CampaniaSel INT = 1;
    SELECT TOP 1 @CampaniaSel = CampañaID
    FROM dbo.CampañasComerciales
    WHERE @FechaVenta BETWEEN FechaInicio AND FechaFin
      AND CampañaID <> 1
    ORDER BY NEWID();

    -- Insertar cabecera de venta
    INSERT INTO dbo.Ventas (Fecha, IdCliente, IdTienda, IdVendedor, IdCanalVenta, IdCampañaComercial, Estado)
    VALUES (@FechaVenta, @CliSel, @TiendaSel, @VenSel, @CanalSel, @CampaniaSel, 'Completa');

    DECLARE @IdVenta INT = SCOPE_IDENTITY();

    -- Entre 3 y 7 líneas por factura (garantiza >150,000 detalles)
    DECLARE @Lineas INT = (ABS(CHECKSUM(NEWID())) % 5) + 3;
    DECLARE @l INT = 1;

    WHILE @l <= @Lineas
    BEGIN
        DECLARE @ProdSel   INT;
        DECLARE @PrecioUnit DECIMAL(12,2);

        SELECT TOP 1 @ProdSel    = ProductoID,
                     @PrecioUnit = PrecioVenta
        FROM #TProductos
        ORDER BY ABS(CHECKSUM(NEWID()));

        DECLARE @Cant INT = (ABS(CHECKSUM(NEWID())) % 4) + 1;

        INSERT INTO dbo.DetalleVentas (IdVenta, IdProducto, Cantidad, PrecioUnidadProducto)
        VALUES (@IdVenta, @ProdSel, @Cant, @PrecioUnit);

        SET @l = @l + 1;
    END;

    -- Commit parcial cada 10,000 para no desbordar el log
    IF @v % 10000 = 0
    BEGIN
        COMMIT TRANSACTION;
        BEGIN TRANSACTION;
        PRINT CONCAT('... Insertadas ', @v, ' facturas de venta.');
    END;

    SET @v = @v + 1;
END;

COMMIT TRANSACTION;
DROP TABLE #TClientes;
DROP TABLE #TProductos;
DROP TABLE #TVendedores;
DROP TABLE #TCanales;
GO

-- ==========================================================
-- 5. POBLADO DE COMPRAS Y DETALLECOMPRAS (Abastecimiento)
-- ==========================================================
PRINT 'Generando registros sintéticos de Compras de abastecimiento...';

DECLARE @c INT = 1;
DECLARE @TotalCompras INT = 2500; -- Volumen óptimo relacional

BEGIN TRANSACTION;

WHILE @c <= @TotalCompras
BEGIN
    DECLARE @ProvSel INT = (SELECT TOP 1 ProveedorID FROM dbo.Proveedores ORDER BY NEWID());
    DECLARE @TienSel INT = (SELECT TOP 1 TiendaID FROM dbo.Tiendas ORDER BY NEWID());
    DECLARE @FechaCompra DATE = DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 730), '2026-04-30');

    INSERT INTO dbo.Compras (Fecha, IdProveedor, IdTienda, Estado)
    VALUES (@FechaCompra, @ProvSel, @TienSel, 'Completa');

    DECLARE @IdCompra INT = SCOPE_IDENTITY();
    
    -- Insertar líneas de abastecimiento de mercancía
    DECLARE @LineasC INT = (ABS(CHECKSUM(NEWID())) % 6) + 2; -- Entre 2 y 7 productos por compra
    DECLARE @lc INT = 1;

    WHILE @lc <= @LineasC
    BEGIN
        DECLARE @ProdSel INT = (SELECT TOP 1 ProductoID FROM dbo.Productos ORDER BY NEWID());
        DECLARE @CostoUnit DECIMAL(12,2) = (SELECT PrecioCosto FROM dbo.Productos WHERE ProductoID = @ProdSel);
        DECLARE @CantC INT = (ABS(CHECKSUM(NEWID())) % 50) + 10; -- Compras al por mayor (10 a 60 unidades)

        INSERT INTO dbo.DetalleCompras (IdCompra, IdProducto, Cantidad, PrecioUnidadProducto)
        VALUES (@IdCompra, @ProdSel, @CantC, @CostoUnit);

        SET @lc = @lc + 1;
    END;

    SET @c = @c + 1;
END;

COMMIT TRANSACTION;
GO

-- ==========================================================
-- 6. POBLADO MATEMÁTICO DE INVENTARIO DIARIO (Garantiza Check Constraint)
-- ==========================================================
PRINT 'Poblando Histórico de Inventario Diario usando lógica de conjuntos segura...';

-- Extraemos un muestreo representativo de combinaciones Fecha, Tienda y Producto desde las transacciones reales
-- Esto garantiza consistencia lógica y evita explosión de registros masivos que cuelguen la VM de Azure
IF OBJECT_ID('tempdb..#PoolInventario') IS NOT NULL DROP TABLE #PoolInventario;

WITH CombinacionesBase AS (
    SELECT DISTINCT 
        V.Fecha,
        V.IdTienda,
        D.IdProducto
    FROM dbo.Ventas V
    JOIN dbo.DetalleVentas D ON V.VentaID = D.IdVenta
    WHERE V.Fecha >= '2024-01-01'
)
SELECT 
    Fecha,
    IdTienda,
    IdProducto,
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Idx
INTO #PoolInventario
FROM CombinacionesBase;

DECLARE @CursorInv INT = 1;
DECLARE @MaxInv INT = (SELECT COUNT(*) FROM #PoolInventario);

BEGIN TRANSACTION;

-- Inserción basada en conjuntos vectoriales controlados aritméticamente
-- El check exige: StockFinal = StockInicial + UnidadesEntrantes - UnidadesSalientes
INSERT INTO dbo.InventarioDiario (Fecha, IdProducto, IdTienda, StockInicial, StockFinal, UnidadesEntrantes, UnidadesSalientes)
SELECT 
    P.Fecha,
    P.IdProducto,
    P.IdTienda,
    Movs.StockInicial,
    (Movs.StockInicial + Movs.Entrantes - Movs.Salientes) AS StockFinal, -- Cumple matemáticamente el CK_Inventario_Consistencia
    Movs.Entrantes,
    Movs.Salientes
FROM #PoolInventario P
CROSS APPLY (
    SELECT 
        ABS(CHECKSUM(NEWID())) % 50 + 20 AS StockInicial,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 5 = 0 THEN (ABS(CHECKSUM(NEWID())) % 30) + 5 ELSE 0 END AS Entrantes,
        ABS(CHECKSUM(NEWID())) % 15 AS Salientes
) Movs;

COMMIT TRANSACTION;
DROP TABLE #PoolInventario;
GO

-- ==========================================================
-- 7. POBLADO DE DEVOLUCIONES (Post-Venta)
-- ==========================================================
PRINT 'Poblando histórico de Devoluciones (Clientes y Proveedores)...';

-- Tomamos una muestra aleatoria del 2% de los detalles de ventas reales para simular devoluciones de clientes
INSERT INTO dbo.Devoluciones (Fecha, IdVenta, IdProducto, Cantidad, Motivo, TipoDevolucion)
SELECT TOP (2500)
    DATEADD(DAY, (ABS(CHECKSUM(NEWID())) % 5) + 1, V.Fecha) AS FechaDevolucion, -- Devuelto de 1 a 5 días después
    V.VentaID,
    D.IdProducto,
    1 AS Cantidad, -- Devolución estándar de una unidad
    CASE ABS(CHECKSUM(NEWID())) % 4 
         WHEN 0 THEN 'Garantía por defecto de fábrica'
         WHEN 1 THEN 'El cliente se arrepintió de la compra'
         WHEN 2 THEN 'Empaque averiado durante el despacho'
         ELSE 'Talla o especificación técnica errónea' END AS Motivo,
    'Cliente' AS TipoDevolucion
FROM dbo.Ventas V
JOIN dbo.DetalleVentas D ON V.VentaID = D.IdVenta
WHERE V.Estado = 'Completa'
ORDER BY NEWID();

PRINT '========================================================================';
PRINT '  ¡PROCESO FINALIZADO CON ÉXITO!';
PRINT '  Se han poblado datos de alta calidad y listos para procesos OLAP/DW.';
PRINT '========================================================================';
GO