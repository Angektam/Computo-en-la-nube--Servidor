/**
 * migrate.js — Crea todas las tablas necesarias en la base de datos en la nube.
 * Ejecutar una sola vez: node src/db/migrate.js
 */
require('dotenv').config();
const pool = require('./connection');

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Tabla de usuarios del sistema
    await client.query(`
      CREATE TABLE IF NOT EXISTS usuarios (
        id          SERIAL PRIMARY KEY,
        nombre      VARCHAR(100) NOT NULL,
        correo      VARCHAR(150) UNIQUE NOT NULL,
        password    VARCHAR(255) NOT NULL,
        rol         VARCHAR(20)  NOT NULL CHECK (rol IN ('administrador','bodega','cajero')),
        activo      BOOLEAN DEFAULT TRUE,
        creado_en   TIMESTAMP DEFAULT NOW()
      );
    `);

    // Tabla de categorías de productos
    await client.query(`
      CREATE TABLE IF NOT EXISTS categorias (
        id          SERIAL PRIMARY KEY,
        nombre      VARCHAR(100) UNIQUE NOT NULL,
        descripcion TEXT
      );
    `);

    // Tabla de productos (inventario)
    await client.query(`
      CREATE TABLE IF NOT EXISTS productos (
        id              SERIAL PRIMARY KEY,
        codigo          VARCHAR(50) UNIQUE NOT NULL,
        nombre          VARCHAR(200) NOT NULL,
        descripcion     TEXT,
        categoria_id    INTEGER REFERENCES categorias(id),
        precio          NUMERIC(10,2) NOT NULL DEFAULT 0,
        stock_actual    INTEGER NOT NULL DEFAULT 0,
        stock_minimo    INTEGER NOT NULL DEFAULT 5,
        unidad          VARCHAR(30) DEFAULT 'pieza',
        imagen_url      TEXT,
        activo          BOOLEAN DEFAULT TRUE,
        creado_en       TIMESTAMP DEFAULT NOW(),
        actualizado_en  TIMESTAMP DEFAULT NOW()
      );
    `);

    // Tabla de movimientos de inventario (entradas/salidas)
    await client.query(`
      CREATE TABLE IF NOT EXISTS movimientos (
        id            SERIAL PRIMARY KEY,
        producto_id   INTEGER NOT NULL REFERENCES productos(id),
        usuario_id    INTEGER NOT NULL REFERENCES usuarios(id),
        tipo          VARCHAR(20) NOT NULL CHECK (tipo IN ('entrada','salida','ajuste')),
        cantidad      INTEGER NOT NULL,
        stock_antes   INTEGER NOT NULL,
        stock_despues INTEGER NOT NULL,
        motivo        TEXT,
        fecha         TIMESTAMP DEFAULT NOW()
      );
    `);

    // Tabla de pedidos automáticos generados por faltantes
    await client.query(`
      CREATE TABLE IF NOT EXISTS pedidos (
        id              SERIAL PRIMARY KEY,
        producto_id     INTEGER NOT NULL REFERENCES productos(id),
        cantidad_sugerida INTEGER NOT NULL,
        estado          VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente','enviado','recibido','cancelado')),
        generado_en     TIMESTAMP DEFAULT NOW(),
        actualizado_en  TIMESTAMP DEFAULT NOW()
      );
    `);

    await client.query('COMMIT');
    console.log('✅ Migración completada — todas las tablas creadas.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Error en migración:', err.message);
    process.exit(1);
  } finally {
    client.release();
    pool.end();
  }
}

migrate();
