const express  = require('express');
const router   = express.Router();
const pool     = require('../db/connection');

/**
 * GET /health
 * Verifica el estado de la base de datos y del servidor.
 * Si SUPABASE_URL es local o fake, omite la verificación de storage.
 */
router.get('/', async (_req, res) => {
  const estado = {
    status:    'ok',
    db:        'ok',
    storage:   'omitido',
    timestamp: new Date().toISOString()
  };
  let httpStatus = 200;

  // Verificar base de datos
  try {
    await pool.query('SELECT 1');
  } catch (err) {
    estado.db     = 'error';
    estado.status = 'degradado';
    estado.db_error = err.message;
    httpStatus    = 503;
  }

  // Verificar Supabase Storage solo si está configurado con URL real
  const supabaseUrl = process.env.SUPABASE_URL || '';
  const esReal = supabaseUrl.includes('supabase.co');

  if (esReal) {
    try {
      const supabase = require('../db/supabase');
      const { error } = await supabase.storage
        .from(process.env.SUPABASE_BUCKET || 'inventario-archivos')
        .list('', { limit: 1 });
      if (error) throw error;
      estado.storage = 'ok';
    } catch (err) {
      estado.storage = 'error';
      estado.status  = 'degradado';
      httpStatus     = 503;
    }
  }

  res.status(httpStatus).json(estado);
});

module.exports = router;
