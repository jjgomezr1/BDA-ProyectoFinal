# Diccionario de Datos — Base de Datos Operacional OLTP

---

## Categorias

Catálogo maestro de categorías de productos. Tabla de referencia sin dependencias externas.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| CategoriaID | INT IDENTITY | PK, NOT NULL | Identificador único autoincremental de la categoría |
| Nombre | NVARCHAR(100) | NOT NULL, UNIQUE | Nombre descriptivo de la categoría. No puede repetirse |
| Descripcion | NVARCHAR(255) | NULL | Descripción opcional con detalles adicionales |

---

## Proveedores

Registro de empresas o personas que abastecen productos a las tiendas.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| ProveedorID | INT IDENTITY | PK, NOT NULL | Identificador único del proveedor |
| Nombre | NVARCHAR(150) | NOT NULL | Razón social o nombre comercial del proveedor |
| NumeroIdentificacionTributaria | VARCHAR(20) | NOT NULL, UNIQUE | NIT o número de identificación fiscal. Debe ser único |
| Ciudad | NVARCHAR(100) | NOT NULL | Ciudad donde está ubicada la sede del proveedor |
| NombreContacto | NVARCHAR(150) | NOT NULL | Nombre completo de la persona de contacto comercial |
| Telefono | VARCHAR(20) | NOT NULL | Número de teléfono de contacto |

---

## Tiendas

Sedes físicas de la empresa minorista distribuidas en diferentes ciudades de Colombia.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| TiendaID | INT IDENTITY | PK, NOT NULL | Identificador único de la tienda |
| Nombre | NVARCHAR(150) | NOT NULL | Nombre comercial de la tienda o sede |
| Ciudad | NVARCHAR(100) | NOT NULL | Ciudad donde opera la tienda |
| Region | NVARCHAR(100) | NOT NULL | Departamento o región geográfica de la tienda |
| Direccion | NVARCHAR(255) | NOT NULL | Dirección física completa de la tienda |
| Telefono | VARCHAR(20) | NOT NULL | Teléfono de contacto de la tienda |
| FechaInicioOperaciones | DATE | NOT NULL, CHECK(<=GETDATE()) | Fecha en que la tienda inició actividades comerciales |

---

## CanalVenta

Catálogo de canales a través de los cuales se realizan ventas (presencial, web, telefónico, etc.).

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| CanalVentaID | INT IDENTITY | PK, NOT NULL | Identificador único del canal de venta |
| Nombre | NVARCHAR(100) | NOT NULL, UNIQUE | Nombre del canal. Debe ser único en el sistema |
| Descripcion | NVARCHAR(255) | NULL | Descripción adicional del canal de venta |

---

## CampañasComerciales

Registro de campañas promocionales con su vigencia temporal. Permite asociar ventas a eventos comerciales.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| CampañaID | INT IDENTITY | PK, NOT NULL | Identificador único de la campaña |
| Nombre | NVARCHAR(150) | NOT NULL | Nombre descriptivo de la campaña |
| FechaInicio | DATE | NOT NULL | Fecha en que inicia la vigencia de la campaña |
| FechaFin | DATE | NOT NULL, CHECK(FechaFin >= FechaInicio) | Fecha de cierre de la campaña. Debe ser mayor o igual a FechaInicio |
| TipoCampaña | NVARCHAR(100) | NOT NULL | Clasificación de la campaña (Descuento, Permanente, etc.) |

---

## Clientes

Personas naturales o jurídicas registradas como compradores en el sistema.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| ClienteID | INT IDENTITY | PK, NOT NULL | Identificador único del cliente |
| Nombre | NVARCHAR(100) | NOT NULL | Primer nombre o razón social del cliente |
| Apellido | NVARCHAR(100) | NOT NULL | Apellido del cliente |
| TipoDocumento | VARCHAR(20) | NOT NULL, CHECK IN ('CC','NIT','CE','Pasaporte','TI') | Tipo de documento de identidad del cliente |
| NumeroDocumento | VARCHAR(30) | NOT NULL, UNIQUE(con TipoDocumento) | Número del documento. Único por tipo de documento |
| Ciudad | NVARCHAR(100) | NOT NULL | Ciudad de residencia o domicilio del cliente |
| Region | NVARCHAR(100) | NOT NULL | Departamento o región del cliente |
| Segmento | NVARCHAR(50) | NOT NULL, CHECK IN (Minorista, Mayorista, Corporativo, VIP, Regular) | Segmento comercial al que pertenece el cliente |
| FechaRegistro | DATE | NOT NULL, DEFAULT GETDATE() | Fecha en que el cliente fue registrado en el sistema |

---

## Productos

Catálogo de ítems comercializados. Depende de Categorias. Incluye precios y control de margen.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| ProductoID | INT IDENTITY | PK, NOT NULL | Identificador único del producto |
| Nombre | NVARCHAR(150) | NOT NULL | Nombre comercial del producto |
| Descripcion | NVARCHAR(500) | NULL | Descripción detallada del producto |
| CategoriaID | INT | NOT NULL, FK → Categorias | Categoría a la que pertenece el producto |
| PrecioVenta | DECIMAL(12,2) | NOT NULL, CHECK(>0), CHECK(>=PrecioCosto) | Precio de venta al público. Debe ser mayor o igual al costo |
| PrecioCosto | DECIMAL(12,2) | NOT NULL, CHECK(>0) | Costo de adquisición del producto |
| CodigoProducto | VARCHAR(50) | NOT NULL, UNIQUE | Código SKU interno único del producto |
| UnidadMedida | NVARCHAR(50) | NOT NULL | Unidad de medida para venta (Unidad, Caja x12, etc.) |
| StockMinimo | INT | NOT NULL, DEFAULT 0, CHECK(>=0) | Nivel mínimo de stock antes de generar alerta de reposición |

---

## Vendedores

Asesores comerciales asignados a una tienda específica.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| VendedorID | INT IDENTITY | PK, NOT NULL | Identificador único del vendedor |
| Nombre | NVARCHAR(100) | NOT NULL | Nombre del vendedor |
| Apellido | NVARCHAR(100) | NOT NULL | Apellido del vendedor |
| IdTiendaAsignada | INT | NOT NULL, FK → Tiendas | Tienda a la que está asignado el vendedor |
| FechaIngreso | DATE | NOT NULL, CHECK(<=GETDATE()) | Fecha de vinculación del vendedor a la empresa |

---

## Ventas

Cabecera de transacciones de venta. Cada registro representa una factura o transacción completa.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| VentaID | INT IDENTITY | PK, NOT NULL | Identificador único de la venta |
| Fecha | DATE | NOT NULL, CHECK(<=GETDATE()) | Fecha en que se realizó la venta |
| IdCliente | INT | NOT NULL, FK → Clientes | Cliente que realizó la compra |
| IdTienda | INT | NOT NULL, FK → Tiendas | Tienda donde se realizó la venta |
| IdVendedor | INT | NOT NULL, FK → Vendedores | Vendedor que atendió la transacción |
| IdCanalVenta | INT | NOT NULL, FK → CanalVenta | Canal a través del cual se realizó la venta |
| IdCampañaComercial | INT | NULL, FK → CampañasComerciales | Campaña asociada. NULL si no aplica ninguna campaña |
| Estado | VARCHAR(20) | NOT NULL, DEFAULT 'Completa', CHECK IN (Cancelada, Pendiente, Completa) | Estado actual de la venta |

---

## DetalleVentas

Líneas de detalle de cada venta. Granularidad: un producto por línea. Subtotal es columna calculada persistida.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| DetalleVentaID | INT IDENTITY | PK, NOT NULL | Identificador único de la línea de detalle |
| IdVenta | INT | NOT NULL, FK → Ventas | Venta a la que pertenece este detalle |
| IdProducto | INT | NOT NULL, FK → Productos | Producto vendido en esta línea |
| Cantidad | INT | NOT NULL, CHECK(>0) | Cantidad de unidades vendidas |
| PrecioUnidadProducto | DECIMAL(12,2) | NOT NULL, CHECK(>0) | Precio unitario al momento de la venta |
| Subtotal | DECIMAL(12,2) | COMPUTED PERSISTED | Calculado automáticamente: Cantidad × PrecioUnidadProducto |

---

## Compras

Cabecera de órdenes de compra a proveedores para abastecimiento de tiendas.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| CompraID | INT IDENTITY | PK, NOT NULL | Identificador único de la orden de compra |
| Fecha | DATE | NOT NULL, CHECK(<=GETDATE()) | Fecha en que se realizó la compra al proveedor |
| IdProveedor | INT | NOT NULL, FK → Proveedores | Proveedor al que se le realizó la compra |
| IdTienda | INT | NOT NULL, FK → Tiendas | Tienda que recibe la mercancía comprada |
| Estado | VARCHAR(20) | NOT NULL, DEFAULT 'Completa', CHECK IN (Cancelada, Pendiente, Completa) | Estado de la orden de compra |

---

## DetalleCompras

Líneas de detalle de cada orden de compra. Subtotal es columna calculada persistida.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| DetalleCompraID | INT IDENTITY | PK, NOT NULL | Identificador único de la línea de compra |
| IdCompra | INT | NOT NULL, FK → Compras | Orden de compra a la que pertenece este detalle |
| IdProducto | INT | NOT NULL, FK → Productos | Producto adquirido en esta línea |
| Cantidad | INT | NOT NULL, CHECK(>0) | Cantidad de unidades compradas |
| PrecioUnidadProducto | DECIMAL(12,2) | NOT NULL, CHECK(>0) | Precio unitario de compra pactado con el proveedor |
| Subtotal | DECIMAL(12,2) | COMPUTED PERSISTED | Calculado automáticamente: Cantidad × PrecioUnidadProducto |

---

## InventarioDiario

Registro diario de movimientos de inventario por producto y tienda. El CHECK de consistencia garantiza integridad matemática.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| InventarioID | INT IDENTITY | PK, NOT NULL | Identificador único del registro de inventario |
| Fecha | DATE | NOT NULL, CHECK(<=GETDATE()), UNIQUE* | Fecha del registro. Único por combinación Fecha+Producto+Tienda |
| IdProducto | INT | NOT NULL, FK → Productos, UNIQUE* | Producto al que corresponde el movimiento |
| IdTienda | INT | NOT NULL, FK → Tiendas, UNIQUE* | Tienda donde se registra el movimiento |
| StockInicial | INT | NOT NULL, CHECK(>=0) | Stock al inicio del día antes de movimientos |
| StockFinal | INT | NOT NULL, CHECK(>=0), CHECK(=Inicial+Entrantes-Salientes) | Stock al cierre del día. Debe cumplir la ecuación de consistencia |
| UnidadesEntrantes | INT | NOT NULL, DEFAULT 0, CHECK(>=0) | Unidades que ingresaron ese día |
| UnidadesSalientes | INT | NOT NULL, DEFAULT 0, CHECK(>=0) | Unidades que salieron ese día |

---

## Devoluciones

Registro de devoluciones de productos, tanto de clientes como hacia proveedores.

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| DevolucionID | INT IDENTITY | PK, NOT NULL | Identificador único de la devolución |
| Fecha | DATE | NOT NULL, CHECK(<=GETDATE()) | Fecha en que se registró la devolución |
| IdVenta | INT | NOT NULL, FK → Ventas | Venta original asociada a la devolución |
| IdProducto | INT | NOT NULL, FK → Productos | Producto devuelto |
| Cantidad | INT | NOT NULL, CHECK(>0) | Número de unidades devueltas |
| Motivo | NVARCHAR(255) | NOT NULL | Descripción del motivo de la devolución |
| TipoDevolucion | VARCHAR(20) | NOT NULL, CHECK IN (Cliente, Proveedor) | Origen de la devolución: del cliente o hacia el proveedor |

---

## MetasComerciales

Metas de ventas mensuales por tienda y categoría. Se carga desde fuente externa (metas_mensuales.csv).

| Columna | Tipo de Dato | Restricciones | Descripción |
|---|---|---|---|
| MetaID | INT IDENTITY | PK, NOT NULL | Identificador único de la meta comercial |
| Año | SMALLINT | NOT NULL, CHECK(BETWEEN 2020 AND 2100) | Año al que corresponde la meta |
| Mes | TINYINT | NOT NULL, CHECK(BETWEEN 1 AND 12) | Mes al que corresponde la meta |
| IdTienda | INT | NOT NULL, FK → Tiendas, UNIQUE* | Tienda a la que aplica la meta. Único por Año+Mes+Categoría |
| IdCategoria | INT | NOT NULL, FK → Categorias, UNIQUE* | Categoría de producto a la que aplica la meta |
| ValorMeta | DECIMAL(15,2) | NOT NULL, CHECK(>0) | Valor en pesos colombianos de la meta mensual de ventas |

---

## Índices de Apoyo Analítico

Se crearon 6 índices no agrupados (NONCLUSTERED) para optimizar las consultas analíticas del proceso ETL y la carga al Data Warehouse.

| Nombre del Índice | Tabla | Columna(s) | Tipo | Propósito |
|---|---|---|---|---|
| IX_Ventas_Fecha | Ventas | Fecha (+ includes) | NONCLUSTERED | Acelera consultas de time intelligence y rangos de fechas en el DW |
| IX_DetalleVentas_Venta | DetalleVentas | IdVenta (+ includes) | NONCLUSTERED | Optimiza JOINs entre Ventas y DetalleVentas para cálculo de totales |
| IX_DetalleVentas_Producto | DetalleVentas | IdProducto | NONCLUSTERED | Acelera búsquedas de ventas por producto específico |
| IX_Inventario_Fecha_Tienda | InventarioDiario | Fecha, IdTienda (+ includes) | NONCLUSTERED | Optimiza consultas de stock actual por tienda y fecha |
| IX_Compras_Fecha | Compras | Fecha (+ includes) | NONCLUSTERED | Facilita análisis de compras por periodo en el ETL |
| IX_Devoluciones_Venta | Devoluciones | IdVenta (+ includes) | NONCLUSTERED | Optimiza la búsqueda de devoluciones por venta para el ETL |

---

## Fuentes Externas (CSV)

### metas_mensuales.csv

Archivo de metas comerciales mensuales por tienda y categoría. Alimenta la tabla MetasComerciales vía proceso ETL de staging.

| Columna | Tipo | Descripción |
|---|---|---|
| Año | Entero | Año de la meta comercial |
| Mes | Entero | Mes de la meta (1 a 12) |
| TiendaID | Entero | ID de la tienda. Referencia a Tiendas.TiendaID |
| NombreTienda | Texto | Nombre descriptivo de la tienda (informativo, no se carga al DW) |
| CategoriaID | Entero | ID de la categoría. Referencia a Categorias.CategoriaID |
| NombreCategoria | Texto | Nombre de la categoría (informativo, no se carga al DW) |
| ValorMeta | Decimal | Valor en pesos colombianos de la meta mensual de ventas |

### inventario_ajustes.csv

Archivo de ajustes manuales de inventario producto de conteos físicos realizados en las tiendas. Sirve como insumo para la zona de staging para validación de calidad de datos.

| Columna | Tipo | Descripción |
|---|---|---|
| Año | Entero | Año del ajuste de inventario |
| Mes | Entero | Mes del ajuste |
| TiendaID | Entero | ID de la tienda donde se detectó la diferencia |
| NombreTienda | Texto | Nombre de la tienda (informativo) |
| ProductoID | Entero | ID del producto con diferencia. Referencia a Productos.ProductoID (1 a 250) |
| StockFisico | Entero | Stock contado físicamente en bodega |
| StockSistema | Entero | Stock registrado en el sistema OLTP |
| Ajuste | Entero | Diferencia: StockFisico - StockSistema. Negativo=faltante, Positivo=exceso |
| Motivo | Texto | Descripción del motivo del ajuste (merma, daño, error de entrada, etc.) |
