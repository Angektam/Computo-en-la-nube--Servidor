const { Pool } = require('pg');

/**
 * Pool de conexiones a PostgreSQL administrado en Supabase.
 * La cadena de conexión se obtiene en:
 *   Supabase → Project Settings → Database → Connection string (URI)
 */
const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  // Supabase requiere SSL en la conexión directa
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis:    30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('[DB] Error inesperado en cliente inactivo:', err.message);
});

module.exports = pool;
