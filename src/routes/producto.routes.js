const express = require('express');
const router  = express.Router();
const pool    = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');

// Todas las rutas requieren autenticación
router.use(verificarToken);

/**
 * GET /api/productos
 * Lista todos los productos activos con su categoría.
 */
router.get('/', async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT p.*, c.nombre AS categoria
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      WHERE p.activo = TRUE
      ORDER BY p.nombre ASC
    `);
    res.json(rows);
  } catch (err) { next(err); }
});

/**
 * GET /api/productos/:id
 * Detalle de un producto.
 */
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT p.*, c.nombre AS categoria
      FROM productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      WHERE p.id = $1 AND p.activo = TRUE
    `, [req.params.id]);

    if (!rows[0]) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

/**
 * POST /api/productos
 * Crea un producto. Solo administrador y bodega.
 */
router.post('/', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const { codigo, nombre, descripcion, categoria_id, precio, stock_actual, stock_minimo, unidad } = req.body;
  if (!codigo || !nombre) return res.status(400).json({ error: 'Código y nombre son obligatorios' });

  try {
    const { rows } = await pool.query(`
      INSERT INTO productos (codigo, nombre, descripcion, categoria_id, precio, stock_actual, stock_minimo, unidad)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING *
    `, [codigo, nombre, descripcion, categoria_id, precio || 0, stock_actual || 0, stock_minimo || 5, unidad || 'pieza']);

    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'El código ya existe' });
    next(err);
  }
});

/**
 * PUT /api/productos/:id
 * Actualiza un producto. Solo administrador y bodega.
 */
router.put('/:id', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const { nombre, descripcion, categoria_id, precio, stock_minimo, unidad } = req.body;
  try {
    const { rows } = await pool.query(`
      UPDATE productos
      SET nombre=$1, descripcion=$2, categoria_id=$3, precio=$4,
          stock_minimo=$5, unidad=$6, actualizado_en=NOW()
      WHERE id=$7 AND activo=TRUE
      RETURNING *
    `, [nombre, descripcion, categoria_id, precio, stock_minimo, unidad, req.params.id]);

    if (!rows[0]) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

/**
 * DELETE /api/productos/:id
 * Desactiva un producto (borrado lógico). Solo administrador.
 */
router.delete('/:id', permitirRoles('administrador'), async (req, res, next) => {
  try {
    await pool.query('UPDATE productos SET activo=FALSE WHERE id=$1', [req.params.id]);
    res.json({ mensaje: 'Producto desactivado correctamente' });
  } catch (err) { next(err); }
});

module.exports = router;
