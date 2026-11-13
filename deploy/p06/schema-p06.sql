-- =============================================================================
-- PRÁCTICA 06 — Esquema del proyecto: Sistema de Inventario Cloud
-- Equipo   : Los Rojos
-- Motor    : PostgreSQL 15 (Amazon RDS)
-- Base     : inventario
-- Fecha    : 13 oct 2026
--
-- CÓMO USAR:
--   Conéctate al servidor EC2 (práctica 3) vía SSH, luego:
--   psql -h <DB_ENDPOINT> -U postgres -d inventario -f schema-p06.sql
-- =============================================================================

-- Mostrar en qué base estamos (para la captura de evidencia)
SELECT current_database() AS base_activa,
       current_user       AS usuario,
       version()          AS motor;

-- =============================================================================
-- PASO 7 (P06): Crear tablas del modelo de datos
-- =============================================================================

-- ── 1. Usuarios del sistema ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuarios (
  id         SERIAL PRIMARY KEY,
  nombre     VARCHAR(100)  NOT NULL,
  correo     VARCHAR(150)  UNIQUE NOT NULL,
  password   VARCHAR(255)  NOT NULL,
  rol        VARCHAR(20)   NOT NULL
               CHECK (rol IN ('administrador','bodega','cajero')),
  activo     BOOLEAN       NOT NULL DEFAULT TRUE,
  creado_en  TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- ── 2. Categorías de productos ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categorias (
  id          SERIAL PRIMARY KEY,
  nombre      VARCHAR(100) UNIQUE NOT NULL,
  descripcion TEXT
);

-- ── 3. Productos (inventario) ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS productos (
  id              SERIAL PRIMARY KEY,
  codigo          VARCHAR(50)   UNIQUE NOT NULL,
  nombre          VARCHAR(200)  NOT NULL,
  descripcion     TEXT,
  categoria_id    INTEGER       REFERENCES categorias(id),
  precio          NUMERIC(10,2) NOT NULL DEFAULT 0,
  stock_actual    INTEGER       NOT NULL DEFAULT 0,
  stock_minimo    INTEGER       NOT NULL DEFAULT 5,
  unidad          VARCHAR(30)   DEFAULT 'pieza',
  imagen_url      TEXT,
  activo          BOOLEAN       NOT NULL DEFAULT TRUE,
  creado_en       TIMESTAMP     NOT NULL DEFAULT NOW(),
  actualizado_en  TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- ── 4. Movimientos de inventario (entradas / salidas / ajustes) ───────────────
CREATE TABLE IF NOT EXISTS movimientos (
  id             SERIAL PRIMARY KEY,
  producto_id    INTEGER  NOT NULL REFERENCES productos(id),
  usuario_id     INTEGER  NOT NULL REFERENCES usuarios(id),
  tipo           VARCHAR(20) NOT NULL
                   CHECK (tipo IN ('entrada','salida','ajuste')),
  cantidad       INTEGER  NOT NULL,
  stock_antes    INTEGER  NOT NULL,
  stock_despues  INTEGER  NOT NULL,
  motivo         TEXT,
  fecha          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ── 5. Pedidos automáticos generados por faltantes ───────────────────────────
CREATE TABLE IF NOT EXISTS pedidos (
  id                SERIAL PRIMARY KEY,
  producto_id       INTEGER NOT NULL REFERENCES productos(id),
  cantidad_sugerida INTEGER NOT NULL,
  estado            VARCHAR(20) DEFAULT 'pendiente'
                      CHECK (estado IN ('pendiente','enviado','recibido','cancelado')),
  generado_en       TIMESTAMP NOT NULL DEFAULT NOW(),
  actualizado_en    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Confirmar creación de tablas
SELECT tablename AS tabla_creada
FROM   pg_tables
WHERE  schemaname = 'public'
ORDER  BY tablename;

-- =============================================================================
-- PASO 7 (P06): Insertar datos ficticios de prueba (mínimo 5 registros)
-- Nota: NO se usan datos personales reales.
-- =============================================================================

-- ── Usuarios de prueba ────────────────────────────────────────────────────────
INSERT INTO usuarios (nombre, correo, password, rol) VALUES
  ('Admin Prueba',   'admin@miscelanea.test',   'hash_admin_123',  'administrador'),
  ('Bodega Prueba',  'bodega@miscelanea.test',  'hash_bodega_456', 'bodega'),
  ('Cajero Prueba',  'cajero@miscelanea.test',  'hash_cajero_789', 'cajero'),
  ('Bodega Dos',     'bodega2@miscelanea.test', 'hash_bodega_002', 'bodega'),
  ('Cajero Dos',     'cajero2@miscelanea.test', 'hash_cajero_002', 'cajero')
ON CONFLICT (correo) DO NOTHING;

-- ── Categorías ────────────────────────────────────────────────────────────────
INSERT INTO categorias (nombre, descripcion) VALUES
  ('Abarrotes',  'Productos no perecederos de consumo general'),
  ('Bebidas',    'Refrescos, agua y jugos'),
  ('Limpieza',   'Detergentes y artículos de aseo'),
  ('Dulcería',   'Dulces, chicles y golosinas'),
  ('Papelería',  'Cuadernos, plumas y útiles escolares')
ON CONFLICT (nombre) DO NOTHING;

-- ── Productos ─────────────────────────────────────────────────────────────────
INSERT INTO productos (codigo, nombre, descripcion, categoria_id, precio, stock_actual, stock_minimo, unidad) VALUES
  ('ABA-001', 'Arroz 1 kg',          'Arroz blanco grano largo',   1, 22.50,  45, 10, 'bolsa'),
  ('ABA-002', 'Frijol negro 1 kg',   'Frijol negro de primera',    1, 28.00,  30,  8, 'bolsa'),
  ('BEB-001', 'Refresco cola 600 ml','Refresco de cola individual', 2, 18.00, 120, 24, 'pieza'),
  ('BEB-002', 'Agua natural 1 L',    'Agua purificada botella',     2, 12.00,  80, 20, 'pieza'),
  ('LIM-001', 'Cloro 1 L',           'Blanqueador doméstico',       3, 15.50,  20,  5, 'botella'),
  ('DUL-001', 'Chicle menta',        'Chicle de menta individual',  4,  2.00, 200, 50, 'pieza'),
  ('PAP-001', 'Cuaderno 100 hojas',  'Cuaderno composición',        5, 35.00,  15,  5, 'pieza')
ON CONFLICT (codigo) DO NOTHING;

-- ── Movimientos de inventario ─────────────────────────────────────────────────
INSERT INTO movimientos (producto_id, usuario_id, tipo, cantidad, stock_antes, stock_despues, motivo) VALUES
  (1, 2, 'entrada',  50, 0,  50, 'Inventario inicial arroz'),
  (3, 2, 'entrada', 120, 0, 120, 'Inventario inicial refrescos'),
  (3, 3, 'salida',    5, 120, 115, 'Venta mostrador'),
  (1, 3, 'salida',    5, 50,  45, 'Venta mostrador'),
  (5, 2, 'entrada',  20, 0,  20, 'Inventario inicial cloro')
ON CONFLICT DO NOTHING;

-- ── Pedidos automáticos ───────────────────────────────────────────────────────
INSERT INTO pedidos (producto_id, cantidad_sugerida, estado) VALUES
  (7, 10, 'pendiente'),   -- cuadernos por debajo de mínimo
  (5,  5, 'pendiente')    -- cloro en nivel mínimo
ON CONFLICT DO NOTHING;

-- =============================================================================
-- CONSULTA DE EVIDENCIA — captura requerida por el paso 7
-- =============================================================================
\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo '  EVIDENCIA P06 — Esquema creado y datos de prueba insertados'
\echo '════════════════════════════════════════════════════════════════'

\echo ''
\echo '▶ Usuarios registrados:'
SELECT id, nombre, correo, rol, activo FROM usuarios ORDER BY id;

\echo ''
\echo '▶ Categorías:'
SELECT id, nombre FROM categorias ORDER BY id;

\echo ''
\echo '▶ Productos con stock actual vs mínimo:'
SELECT p.codigo, p.nombre, c.nombre AS categoria,
       p.stock_actual, p.stock_minimo,
       CASE WHEN p.stock_actual <= p.stock_minimo
            THEN '⚠ BAJO' ELSE '✔ OK' END AS estado_stock
FROM   productos p
JOIN   categorias c ON c.id = p.categoria_id
ORDER  BY p.id;

\echo ''
\echo '▶ Últimos movimientos de inventario:'
SELECT m.id, p.nombre AS producto, u.nombre AS usuario,
       m.tipo, m.cantidad, m.stock_antes, m.stock_despues, m.fecha
FROM   movimientos m
JOIN   productos p ON p.id = m.producto_id
JOIN   usuarios  u ON u.id = m.usuario_id
ORDER  BY m.fecha DESC;

\echo ''
\echo '▶ Pedidos pendientes:'
SELECT pe.id, pr.nombre AS producto,
       pe.cantidad_sugerida, pe.estado, pe.generado_en
FROM   pedidos pe
JOIN   productos pr ON pr.id = pe.producto_id
WHERE  pe.estado = 'pendiente';

\echo ''
\echo '↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑'
\echo '════════════════════════════════════════════════════════════════'
