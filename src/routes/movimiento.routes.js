const express = require('express');
const router  = express.Router();
const pool    = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');

router.use(verificarToken);

/**
 * GET /api/movimientos
 * Lista movimientos con paginación y filtros opcionales.
 * Query params: ?page=1&limit=50&tipo=entrada&producto_id=5&desde=YYYY-MM-DD&hasta=YYYY-MM-DD
 */
router.get('/', async (req, res, next) => {
  const page       = Math.max(1, parseInt(req.query.page)  || 1);
  const limit      = Math.min(200, parseInt(req.query.limit) || 50);
  const offset     = (page - 1) * limit;
  const tipo       = req.query.tipo;
  const producto_id = req.query.producto_id;
  const desde      = req.query.desde;
  const hasta      = req.query.hasta;

  const condiciones = [];
  const params      = [];
  let idx = 1;

  if (tipo && ['entrada','salida','ajuste'].includes(tipo)) {
    condiciones.push(`m.tipo = $${idx++}`); params.push(tipo);
  }
  if (producto_id) {
    condiciones.push(`m.producto_id = $${idx++}`); params.push(parseInt(producto_id));
  }
  if (desde) {
    condiciones.push(`m.fecha >= $${idx++}::date`); params.push(desde);
  }
  if (hasta) {
    condiciones.push(`m.fecha < ($${idx++}::date + INTERVAL '1 day')`); params.push(hasta);
  }

  const where = condiciones.length ? 'WHERE ' + condiciones.join(' AND ') : '';

  try {
    const [{ rows }, { rows: total }] = await Promise.all([
      pool.query(`
        SELECT m.*, p.nombre AS producto, p.codigo, u.nombre AS usuario
        FROM movimientos m
        JOIN productos p ON m.producto_id = p.id
        JOIN usuarios  u ON m.usuario_id  = u.id
        ${where}
        ORDER BY m.fecha DESC
        LIMIT ${limit} OFFSET ${offset}
      `, params),
      pool.query(`
        SELECT COUNT(*) FROM movimientos m ${where}
      `, params)
    ]);
    res.json({
      datos: rows,
      total: parseInt(total[0].count),
      page,
      limit,
      paginas: Math.ceil(parseInt(total[0].count) / limit)
    });
  } catch (err) { next(err); }
});

/**
 * POST /api/movimientos
 * Registra una entrada, salida o ajuste de inventario.
 * Body: { producto_id, tipo, cantidad, motivo }
 */
router.post('/', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const { producto_id, tipo, cantidad, motivo } = req.body;

  if (!producto_id || !tipo || !cantidad) {
    return res.status(400).json({ error: 'producto_id, tipo y cantidad son obligatorios' });
  }
  if (!['entrada', 'salida', 'ajuste'].includes(tipo)) {
    return res.status(400).json({ error: 'Tipo inválido. Use: entrada, salida o ajuste' });
  }
  if (cantidad <= 0) {
    return res.status(400).json({ error: 'La cantidad debe ser mayor a 0' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Bloquea la fila del producto para evitar condiciones de carrera
    const { rows: prod } = await client.query(
      'SELECT stock_actual FROM productos WHERE id=$1 FOR UPDATE',
      [producto_id]
    );
    if (!prod[0]) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });

    const stockAntes = prod[0].stock_actual;
    let stockDespues;

    if (tipo === 'entrada') {
      stockDespues = stockAntes + cantidad;
    } else if (tipo === 'salida') {
      if (stockAntes < cantidad) throw Object.assign(new Error('Stock insuficiente'), { status: 400 });
      stockDespues = stockAntes - cantidad;
    } else {
      // ajuste: la cantidad representa el nuevo stock total
      stockDespues = cantidad;
    }

    // Actualizar stock
    await client.query(
      'UPDATE productos SET stock_actual=$1, actualizado_en=NOW() WHERE id=$2',
      [stockDespues, producto_id]
    );

    // Registrar movimiento
    const { rows } = await client.query(`
      INSERT INTO movimientos (producto_id, usuario_id, tipo, cantidad, stock_antes, stock_despues, motivo)
      VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *
    `, [producto_id, req.usuario.id, tipo, cantidad, stockAntes, stockDespues, motivo]);

    // Si el stock queda por debajo del mínimo, generar pedido automático
    const { rows: prod2 } = await client.query(
      'SELECT stock_minimo FROM productos WHERE id=$1', [producto_id]
    );
    if (stockDespues < prod2[0].stock_minimo) {
      const sugerido = prod2[0].stock_minimo * 2;
      await client.query(`
        INSERT INTO pedidos (producto_id, cantidad_sugerida)
        VALUES ($1, $2)
      `, [producto_id, sugerido]);
    }

    await client.query('COMMIT');
    res.status(201).json(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
