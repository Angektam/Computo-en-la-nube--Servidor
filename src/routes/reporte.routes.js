const express = require('express');
const router  = express.Router();
const pool    = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');

router.use(verificarToken);

// ── Helper: rango de fechas con valor por defecto últimos 30 días ──────
function rangoFechas(query) {
  const desde = query.desde || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const hasta = query.hasta || new Date().toISOString().slice(0, 10);
  return { desde, hasta };
}

const ESTADOS_PEDIDO = ['pendiente', 'enviado', 'recibido', 'cancelado'];

// ── Query reutilizable de faltantes ───────────────────────────────────
async function queryFaltantes() {
  return pool.query(`
    SELECT p.id, p.codigo, p.nombre, p.stock_actual, p.stock_minimo,
           (p.stock_minimo - p.stock_actual) AS faltante,
           c.nombre AS categoria
    FROM   productos p
    LEFT JOIN categorias c ON p.categoria_id = c.id
    WHERE  p.stock_actual < p.stock_minimo
      AND  p.activo = TRUE
    ORDER BY faltante DESC
  `);
}

/**
 * GET /api/reportes/faltantes
 * Productos con stock_actual < stock_minimo (alerta de existencias mínimas).
 */
router.get('/faltantes', async (_req, res, next) => {
  try {
    const { rows } = await queryFaltantes();
    res.json({ total: rows.length, productos: rows });
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/sobrantes?factor=3
 * Productos con stock_actual > stock_minimo * factor (exceso de mercancía).
 */
router.get('/sobrantes', async (req, res, next) => {
  const factor = Math.max(1, parseInt(req.query.factor) || 3);
  try {
    const { rows } = await pool.query(`
      SELECT p.id, p.codigo, p.nombre, p.stock_actual, p.stock_minimo,
             (p.stock_actual - p.stock_minimo * $1) AS sobrante,
             c.nombre AS categoria
      FROM   productos p
      LEFT JOIN categorias c ON p.categoria_id = c.id
      WHERE  p.stock_actual > p.stock_minimo * $1
        AND  p.activo = TRUE
      ORDER BY sobrante DESC
    `, [factor]);
    res.json({ total: rows.length, factor, productos: rows });
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/movimientos?desde=YYYY-MM-DD&hasta=YYYY-MM-DD
 * Resumen de entradas, salidas y ajustes por producto en un rango de fechas.
 * Por defecto muestra los últimos 30 días.
 */
router.get('/movimientos', async (req, res, next) => {
  const { desde, hasta } = rangoFechas(req.query);

  try {
    const { rows } = await pool.query(`
      SELECT p.codigo, p.nombre,
             SUM(CASE WHEN m.tipo = 'entrada' THEN m.cantidad ELSE 0 END) AS total_entradas,
             SUM(CASE WHEN m.tipo = 'salida'  THEN m.cantidad ELSE 0 END) AS total_salidas,
             SUM(CASE WHEN m.tipo = 'ajuste'  THEN m.cantidad ELSE 0 END) AS total_ajustes
      FROM   movimientos m
      JOIN   productos p ON m.producto_id = p.id
      WHERE  m.fecha BETWEEN $1::date AND $2::date + INTERVAL '1 day'
      GROUP BY p.id, p.codigo, p.nombre
      ORDER BY total_salidas DESC
    `, [desde, hasta]);
    res.json({ desde, hasta, productos: rows });
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/corte-diario?fecha=YYYY-MM-DD
 * Corte del día: total de movimientos, valor movido y estado de alertas.
 * Si no se indica fecha, usa hoy.
 */
router.get('/corte-diario', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const fecha = req.query.fecha || new Date().toISOString().slice(0, 10);

  try {
    // Resumen de movimientos del día
    const { rows: movs } = await pool.query(`
      SELECT
        COUNT(*)                                                        AS total_movimientos,
        SUM(CASE WHEN m.tipo = 'entrada' THEN m.cantidad ELSE 0 END)  AS entradas,
        SUM(CASE WHEN m.tipo = 'salida'  THEN m.cantidad ELSE 0 END)  AS salidas,
        SUM(CASE WHEN m.tipo = 'ajuste'  THEN m.cantidad ELSE 0 END)  AS ajustes,
        SUM(CASE WHEN m.tipo = 'salida'  THEN m.cantidad * p.precio ELSE 0 END) AS valor_salidas
      FROM movimientos m
      JOIN productos p ON m.producto_id = p.id
      WHERE m.fecha::date = $1::date
    `, [fecha]);

    // Productos bajo mínimo al cierre del día
    const { rows: alertas } = await pool.query(`
      SELECT COUNT(*) AS productos_bajo_minimo
      FROM   productos
      WHERE  stock_actual < stock_minimo AND activo = TRUE
    `);

    // Pedidos generados ese día
    const { rows: pedidos } = await pool.query(`
      SELECT COUNT(*) AS pedidos_generados
      FROM   pedidos
      WHERE  generado_en::date = $1::date
    `, [fecha]);

    res.json({
      fecha,
      resumen: movs[0],
      alertas: {
        productos_bajo_minimo: parseInt(alertas[0].productos_bajo_minimo),
        pedidos_generados:     parseInt(pedidos[0].pedidos_generados)
      }
    });
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/gastos?desde=YYYY-MM-DD&hasta=YYYY-MM-DD
 * Historial de gastos acumulados por período (valor de salidas por día y total).
 */
router.get('/gastos', permitirRoles('administrador'), async (req, res, next) => {
  const { desde, hasta } = rangoFechas(req.query);

  try {
    // Desglose diario de valor movido en salidas
    const { rows: porDia } = await pool.query(`
      SELECT
        m.fecha::date                                          AS dia,
        COUNT(*)                                               AS movimientos,
        SUM(m.cantidad * p.precio)                             AS valor_total,
        SUM(CASE WHEN m.tipo='salida'  THEN m.cantidad * p.precio ELSE 0 END) AS valor_salidas,
        SUM(CASE WHEN m.tipo='entrada' THEN m.cantidad * p.precio ELSE 0 END) AS valor_entradas
      FROM movimientos m
      JOIN productos p ON m.producto_id = p.id
      WHERE m.fecha BETWEEN $1::date AND $2::date + INTERVAL '1 day'
        AND m.tipo IN ('entrada', 'salida')
      GROUP BY dia
      ORDER BY dia ASC
    `, [desde, hasta]);

    // Totales del período
    const { rows: totales } = await pool.query(`
      SELECT
        SUM(CASE WHEN m.tipo='salida'  THEN m.cantidad * p.precio ELSE 0 END) AS total_salidas,
        SUM(CASE WHEN m.tipo='entrada' THEN m.cantidad * p.precio ELSE 0 END) AS total_entradas,
        COUNT(*) AS total_movimientos
      FROM movimientos m
      JOIN productos p ON m.producto_id = p.id
      WHERE m.fecha BETWEEN $1::date AND $2::date + INTERVAL '1 day'
        AND m.tipo IN ('entrada', 'salida')
    `, [desde, hasta]);

    // Top 5 productos con mayor valor de salidas en el período
    const { rows: topProductos } = await pool.query(`
      SELECT
        p.codigo, p.nombre,
        SUM(m.cantidad)         AS unidades_vendidas,
        SUM(m.cantidad * p.precio) AS valor_acumulado
      FROM movimientos m
      JOIN productos p ON m.producto_id = p.id
      WHERE m.tipo = 'salida'
        AND m.fecha BETWEEN $1::date AND $2::date + INTERVAL '1 day'
      GROUP BY p.id, p.codigo, p.nombre
      ORDER BY valor_acumulado DESC
      LIMIT 5
    `, [desde, hasta]);

    res.json({
      desde,
      hasta,
      totales: totales[0],
      por_dia: porDia,
      top_productos: topProductos
    });
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/pedidos?estado=pendiente
 * Lista pedidos automáticos. Por defecto solo los pendientes.
 */
router.get('/pedidos', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const estado = req.query.estado && ESTADOS_PEDIDO.includes(req.query.estado)
    ? req.query.estado
    : 'pendiente';

  try {
    const { rows } = await pool.query(`
      SELECT ped.*, p.codigo, p.nombre AS producto, p.stock_actual, p.stock_minimo
      FROM   pedidos ped
      JOIN   productos p ON ped.producto_id = p.id
      WHERE  ped.estado = $1
      ORDER BY ped.generado_en DESC
    `, [estado]);
    res.json({ total: rows.length, pedidos: rows, estado });
  } catch (err) { next(err); }
});

/**
 * PATCH /api/reportes/pedidos/:id
 * Actualiza el estado de un pedido: pendiente → enviado → recibido | cancelado.
 */
router.patch('/pedidos/:id', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const { estado } = req.body;

  if (!ESTADOS_PEDIDO.includes(estado)) {
    return res.status(400).json({ error: `Estado inválido. Use: ${ESTADOS_PEDIDO.join(', ')}` });
  }

  try {
    const { rows } = await pool.query(`
      UPDATE pedidos
      SET    estado = $1, actualizado_en = NOW()
      WHERE  id = $2
      RETURNING *
    `, [estado, req.params.id]);

    if (!rows[0]) return res.status(404).json({ error: 'Pedido no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/export/movimientos?desde=&hasta=&tipo=&formato=csv
 * Exporta movimientos a CSV.
 */
router.get('/export/movimientos', async (req, res, next) => {
  const { desde, hasta } = rangoFechas(req.query);
  const tipo  = req.query.tipo;

  const condiciones = [`m.fecha BETWEEN $1::date AND $2::date + INTERVAL '1 day'`];
  const params      = [desde, hasta];
  if (tipo && ['entrada','salida','ajuste'].includes(tipo)) {
    condiciones.push(`m.tipo = $3`); params.push(tipo);
  }

  try {
    const { rows } = await pool.query(`
      SELECT m.fecha, m.tipo, p.codigo, p.nombre AS producto,
             m.cantidad, m.stock_antes, m.stock_despues,
             u.nombre AS usuario, m.motivo
      FROM movimientos m
      JOIN productos p ON m.producto_id = p.id
      JOIN usuarios  u ON m.usuario_id  = u.id
      WHERE ${condiciones.join(' AND ')}
      ORDER BY m.fecha DESC
    `, params);

    const cabecera = 'Fecha,Tipo,Código,Producto,Cantidad,Stock antes,Stock después,Usuario,Motivo';
    const lineas   = rows.map(r =>
      [
        new Date(r.fecha).toLocaleString('es-MX'),
        r.tipo, r.codigo,
        `"${r.producto}"`,
        r.cantidad, r.stock_antes, r.stock_despues,
        `"${r.usuario}"`,
        `"${r.motivo || ''}"`,
      ].join(',')
    );

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="movimientos-${desde}-${hasta}.csv"`);
    res.send('\uFEFF' + [cabecera, ...lineas].join('\n'));
  } catch (err) { next(err); }
});

/**
 * GET /api/reportes/export/faltantes — Exporta faltantes a CSV.
 */
router.get('/export/faltantes', async (_req, res, next) => {
  try {
    const { rows } = await queryFaltantes();

    const cab = 'Código,Nombre,Categoría,Stock actual,Stock mínimo,Faltante';
    const lin = rows.map(r =>
      [r.codigo, `"${r.nombre}"`, `"${r.categoria||''}"`, r.stock_actual, r.stock_minimo, r.faltante].join(',')
    );

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="faltantes-${new Date().toISOString().slice(0,10)}.csv"`);
    res.send('\uFEFF' + [cab, ...lin].join('\n'));
  } catch (err) { next(err); }
});

module.exports = router;
