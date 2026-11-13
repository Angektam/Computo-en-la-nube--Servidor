const express = require('express');
const router  = express.Router();
const pool    = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');
const { esEnteroPositivo } = require('../middleware/validation.middleware');
const { generarPorFaltantes } = require('../services/pedidos.service');

// Todas las rutas requieren autenticación
router.use(verificarToken);
router.param('id', (_req, res, next, id) => {
  if (!esEnteroPositivo(id)) {
    return res.status(400).json({ error: 'El ID del producto debe ser un número entero positivo' });
  }
  next();
});

/**
 * GET /api/productos
 * Lista todos los productos activos con su categoría.
 */
router.get('/', async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT p.*, c.nombre AS categoria, c.abreviacion AS categoria_abreviacion
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
      SELECT p.*, c.nombre AS categoria, c.abreviacion AS categoria_abreviacion
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
  if (!nombre) return res.status(400).json({ error: 'El nombre es obligatorio' });

  const stock = Number(stock_actual ?? 0);
  const minimo = Number(stock_minimo ?? 5);
  if (![stock, minimo].every(value => Number.isInteger(value) && value >= 0 && value <= 2147483647)) {
    return res.status(400).json({ error: 'El stock y el mínimo deben ser enteros mayores o iguales a 0' });
  }
  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    let codigoFinal = typeof codigo === 'string' ? codigo.trim() : '';
    if (!codigoFinal && categoria_id) {
      const { rows: categoriaRows } = await client.query(
        'SELECT abreviacion FROM categorias WHERE id=$1',
        [categoria_id]
      );
      const abreviacion = categoriaRows[0]?.abreviacion;
      if (!abreviacion) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'La categorÃ­a seleccionada no tiene abreviaciÃ³n configurada' });
      }
      const { rows: codigos } = await client.query(
        'SELECT codigo FROM productos WHERE codigo LIKE $1 FOR UPDATE',
        [`${abreviacion}-%`]
      );
      const siguiente = codigos.reduce((max, row) => {
        const match = new RegExp(`^${abreviacion}-(\\d+)$`, 'i').exec(row.codigo);
        return match ? Math.max(max, Number(match[1])) : max;
      }, 0) + 1;
      codigoFinal = `${abreviacion}-${String(siguiente).padStart(3, '0')}`;
    }
    if (!codigoFinal) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'CÃ³digo o categorÃ­a son obligatorios' });
    }
    const { rows } = await client.query(`
      INSERT INTO productos (codigo, nombre, descripcion, categoria_id, precio, stock_actual, stock_minimo, unidad)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING *
    `, [codigoFinal, nombre, descripcion, categoria_id, precio || 0, stock, minimo, unidad || 'pieza']);

    await generarPorFaltantes(client, rows[0].id, req.usuario.id);
    await client.query('COMMIT');

    res.status(201).json(rows[0]);
  } catch (err) {
    if (client) await client.query('ROLLBACK');
    if (err.code === '23505') return res.status(409).json({ error: 'El código ya existe' });
    next(err);
  } finally {
    if (client) client.release();
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
        VALUES ($1,$2,'ajuste',$3,$4,$5,$6)
      `, [req.params.id, req.usuario.id, Math.abs(stockNuevo - stockAntes), stockAntes, stockNuevo, 'Ajuste de existencias desde edición del producto']);

    }

    // También cubre un aumento del mínimo sin cambiar existencias.
    await generarPorFaltantes(client, req.params.id, req.usuario.id);

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
    const result = await pool.query('UPDATE productos SET activo=FALSE, actualizado_en=NOW() WHERE id=$1 AND activo=TRUE', [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'Producto no encontrado o ya desactivado' });
    res.json({ mensaje: 'Producto desactivado correctamente' });
  } catch (err) { next(err); }
});

module.exports = router;
