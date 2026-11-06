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
 * Actualiza un producto. Solo bodega.
 */
router.put('/:id', permitirRoles('bodega'), async (req, res, next) => {
  const { codigo, nombre, descripcion, categoria_id, precio, stock_actual, stock_minimo, unidad } = req.body;

  if ((codigo !== undefined && codigo.toString().trim() === '') || !nombre || nombre.toString().trim() === '') {
    return res.status(400).json({ error: 'El nombre es obligatorio y el código no puede estar vacío' });
  }
  const precioNum    = parseFloat(precio);
  const minimoNum    = parseInt(stock_minimo);
  if (isNaN(precioNum) || precioNum < 0) {
    return res.status(400).json({ error: 'El precio debe ser un número mayor o igual a 0' });
  }
  if (isNaN(minimoNum) || minimoNum < 0) {
    return res.status(400).json({ error: 'El stock mínimo debe ser un número mayor o igual a 0' });
  }
  const stockNum = stock_actual === undefined ? null : Number(stock_actual);
  if (stock_actual !== undefined &&
      (stock_actual === null || stock_actual === '' || !Number.isInteger(stockNum) || stockNum < 0)) {
    return res.status(400).json({ error: 'El stock debe ser un número entero mayor o igual a 0' });
  }

  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    const { rows: existentes } = await client.query(
      'SELECT stock_actual FROM productos WHERE id=$1 AND activo=TRUE FOR UPDATE',
      [req.params.id]
    );
    if (!existentes[0]) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Producto no encontrado' });
    }

    const stockAntes = existentes[0].stock_actual;
    const stockNuevo = stockNum === null ? stockAntes : stockNum;
    const { rows } = await client.query(`
      UPDATE productos
      SET codigo=COALESCE($1,codigo), nombre=$2, descripcion=$3, categoria_id=$4, precio=$5,
          stock_actual=$6, stock_minimo=$7, unidad=$8, actualizado_en=NOW()
      WHERE id=$9 AND activo=TRUE
      RETURNING *
    `, [codigo === undefined ? null : codigo.toString().trim(), nombre.toString().trim(), descripcion || null,
        categoria_id || null, precioNum, stockNuevo, minimoNum, unidad || 'pieza', req.params.id]);

    if (stockNuevo !== stockAntes) {
      await client.query(`
        INSERT INTO movimientos (producto_id, usuario_id, tipo, cantidad, stock_antes, stock_despues, motivo)
        VALUES ($1,$2,'ajuste',$3,$4,$3,$5)
      `, [req.params.id, req.usuario.id, stockNuevo, stockAntes, 'Ajuste de existencias desde edición del producto']);

      if (stockNuevo < minimoNum) {
        await client.query(`
          INSERT INTO pedidos (producto_id, cantidad_sugerida)
          SELECT $1, $2
          WHERE NOT EXISTS (
            SELECT 1 FROM pedidos WHERE producto_id = $1 AND estado = 'pendiente'
          )
        `, [req.params.id, minimoNum * 2]);
      }
    }

    await client.query('COMMIT');
    res.json(rows[0]);
  } catch (err) {
    if (client) {
      await client.query('ROLLBACK');
    }
    if (err.code === '23505') {
      return res.status(409).json({ error: 'El código ya existe' });
    }
    next(err);
  } finally {
    if (client) client.release();
  }
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
