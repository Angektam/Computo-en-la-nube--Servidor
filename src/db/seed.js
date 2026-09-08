/**
 * seed.js — Carga datos iniciales de prueba.
 * Ejecutar: node src/db/seed.js
 */
require('dotenv').config();
const pool    = require('./connection');
const bcrypt  = require('bcryptjs');

async function seed() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Categorías de ejemplo
    await client.query(`
      INSERT INTO categorias (nombre, descripcion) VALUES
        ('Electrónica',  'Dispositivos y componentes electrónicos'),
        ('Papelería',    'Artículos de oficina y escritura'),
        ('Herramientas', 'Herramientas manuales y eléctricas')
      ON CONFLICT (nombre) DO NOTHING;
    `);

    // Usuario administrador por defecto
    const hash = await bcrypt.hash('Admin1234!', 10);
    await client.query(`
      INSERT INTO usuarios (nombre, correo, password, rol) VALUES
        ('Administrador', 'admin@empresa.com', $1, 'administrador'),
        ('Bodeguero',     'bodega@empresa.com', $1, 'bodega'),
        ('Cajero',        'cajero@empresa.com', $1, 'cajero')
      ON CONFLICT (correo) DO NOTHING;
    `, [hash]);

    // Productos de ejemplo
    await client.query(`
      INSERT INTO productos (codigo, nombre, precio, stock_actual, stock_minimo, categoria_id) VALUES
        ('ELEC-001', 'Cable USB Tipo C 1m',   85.00,  20, 5, 1),
        ('ELEC-002', 'Teclado Inalámbrico',  350.00,   8, 3, 1),
        ('PAP-001',  'Resma Papel Carta',     95.00,  15, 5, 2),
        ('PAP-002',  'Plumas Azules (caja)', 120.00,   3, 5, 2),
        ('HER-001',  'Desarmador de Estrella', 55.00, 12, 4, 3)
      ON CONFLICT (codigo) DO NOTHING;
    `);

    await client.query('COMMIT');
    console.log('✅ Seed completado — datos iniciales insertados.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Error en seed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    pool.end();
  }
}

seed();
