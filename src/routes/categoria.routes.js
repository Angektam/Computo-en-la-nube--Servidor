/**
 * categoria.routes.js — CRUD completo de categorías.
 */
const express = require('express');
const router  = express.Router();
const pool    = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');

router.use(verificarToken);

/** GET /api/categorias — Lista todas las categorías */
router.get('/', async (_req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT c.*, COUNT(p.id) AS total_productos
      FROM categorias c
      LEFT JOIN productos p ON p.categoria_id = c.id AND p.activo = TRUE
      GROUP BY c.id
      ORDER BY c.nombre ASC
    `);
    res.json(rows);
  } catch (err) { next(err); }
});

/** POST /api/categorias — Crea categoría (solo admin) */
router.post('/', permitirRoles('administrador'), async (req, res, next) => {
  const { nombre, descripcion, abreviacion } = req.body;
  if (!nombre) return res.status(400).json({ error: 'El nombre es obligatorio' });
  if (typeof abreviacion !== 'string' || !/^[A-Z]{2,10}$/.test(abreviacion.trim().toUpperCase())) {
    return res.status(400).json({ error: 'La abreviaciÃ³n debe tener entre 2 y 10 letras mayÃºsculas' });
  }
  try {
    const { rows } = await pool.query(
      'INSERT INTO categorias (nombre, descripcion, abreviacion) VALUES ($1,$2,$3) RETURNING *',
      [nombre.trim(), descripcion?.trim() || null, abreviacion.trim().toUpperCase()]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Ya existe una categoría con ese nombre' });
    next(err);
  }
});

/** PUT /api/categorias/:id — Edita categoría (solo admin) */
router.put('/:id', permitirRoles('administrador'), async (req, res, next) => {
  const { nombre, descripcion, abreviacion } = req.body;
  if (!nombre) return res.status(400).json({ error: 'El nombre es obligatorio' });
  if (typeof abreviacion !== 'string' || !/^[A-Z]{2,10}$/.test(abreviacion.trim().toUpperCase())) {
    return res.status(400).json({ error: 'La abreviaciÃ³n debe tener entre 2 y 10 letras mayÃºsculas' });
  }
  try {
    const { rows } = await pool.query(
      'UPDATE categorias SET nombre=$1, descripcion=$2, abreviacion=$3 WHERE id=$4 RETURNING *',
      [nombre.trim(), descripcion?.trim() || null, abreviacion.trim().toUpperCase(), req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Categoría no encontrada' });
    res.json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Ya existe una categoría con ese nombre' });
    next(err);
  }
});

/** DELETE /api/categorias/:id — Elimina si no tiene productos (solo admin) */
router.delete('/:id', permitirRoles('administrador'), async (req, res, next) => {
  try {
    const { rows: check } = await pool.query(
      'SELECT COUNT(*) FROM productos WHERE categoria_id=$1 AND activo=TRUE',
      [req.params.id]
    );
    if (parseInt(check[0].count) > 0) {
      return res.status(409).json({ error: 'No se puede eliminar: tiene productos asignados' });
    }
    const { rowCount } = await pool.query('DELETE FROM categorias WHERE id=$1', [req.params.id]);
    if (!rowCount) return res.status(404).json({ error: 'Categoría no encontrada' });
    res.json({ mensaje: 'Categoría eliminada' });
  } catch (err) { next(err); }
});

module.exports = router;
