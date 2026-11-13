const express = require('express');
const router  = express.Router();
const pool    = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');
const { validarFechas, esEnteroPositivo } = require('../middleware/validation.middleware');
const { generarPorFaltantes, actualizarEstado } = require('../services/pedidos.service');
const { filtrosPedidos, from: pedidosFrom, select: pedidosSelect, csvCell } = require('../services/pedidos-query.service');

router.use(verificarToken);
router.use(validarFechas);

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
  try {
    const { estado, page, limit, values, where } = filtrosPedidos(req.query);
    const { rows: counts } = await pool.query(`SELECT COUNT(*)::integer AS total ${pedidosFrom} ${where}`, values);
    const { rows } = await pool.query(`${pedidosSelect} ${where} ORDER BY ped.generado_en DESC,ped.id DESC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
      [...values, limit, (page - 1) * limit]);
    const total = Number(counts[0]?.total || 0);
    res.json({ total, pedidos: rows, estado, page, limit, paginas: Math.ceil(total / limit) });
  } catch (err) { next(err); }
});

router.get('/pedidos/alertas', permitirRoles('administrador', 'bodega'), async (_req, res, next) => {
  try {
    const { rows } = await pool.query(`SELECT
      (SELECT COUNT(*)::integer FROM productos WHERE activo=TRUE AND stock_actual<=0) AS agotados,
      (SELECT COUNT(*)::integer FROM productos p WHERE p.activo=TRUE AND p.stock_actual<p.stock_minimo
        AND NOT EXISTS(SELECT 1 FROM pedidos ped WHERE ped.producto_id=p.id AND ped.estado IN ('pendiente','enviado'))) AS sin_pedido,
      (SELECT COUNT(*)::integer FROM pedidos WHERE estado IN ('pendiente','enviado') AND entrega_estimada<CURRENT_DATE) AS atrasados,
      (SELECT COUNT(*)::integer FROM pedidos WHERE estado='enviado' AND cantidad_recibida>0) AS parciales`);
    res.json(rows[0]);
  } catch (err) { next(err); }
});

router.get('/export/pedidos', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  try {
    const { values, where } = filtrosPedidos(req.query);
    const { rows } = await pool.query(`${pedidosSelect} ${where} ORDER BY ped.generado_en DESC,ped.id DESC LIMIT 10001`, values);
    if (rows.length > 10000) return res.status(400).json({ error: 'La exportación supera 10000 pedidos. Reduce el rango de fechas.' });
    const header = ['Pedido','Código','Producto','Proveedor','Solicitado','Recibido','Pendiente','Estado','Costo unitario','Costo total','Entrega estimada','Generado'];
    const lines = rows.map(p => [p.id,p.codigo,p.producto,p.proveedor,p.cantidad_sugerida,p.cantidad_recibida,p.cantidad_pendiente,p.estado,
      p.costo_unitario,p.costo_total,p.entrega_estimada ? new Date(p.entrega_estimada).toISOString().slice(0,10) : '',new Date(p.generado_en).toISOString()].map(csvCell).join(','));
    res.setHeader('Content-Type','text/csv; charset=utf-8');
    res.setHeader('Content-Disposition','attachment; filename="pedidos.csv"');
    res.send('\uFEFF' + [header.map(csvCell).join(','),...lines].join('\r\n'));
  } catch (err) { next(err); }
});

router.get('/pedidos/faltantes', permitirRoles('administrador', 'bodega'), async(req,res,next)=>{
  try {
    const agotados=req.query.alerta==='agotados';
    const {rows}=await pool.query(`SELECT p.id,p.codigo,p.nombre,p.stock_actual,p.stock_minimo FROM productos p
      WHERE p.activo=TRUE AND ${agotados ? 'p.stock_actual<=0' : `p.stock_actual<p.stock_minimo AND NOT EXISTS
        (SELECT 1 FROM pedidos ped WHERE ped.producto_id=p.id AND ped.estado IN ('pendiente','enviado'))`}
      ORDER BY p.stock_actual,p.id LIMIT 200`);
    res.json({productos:rows});
  }catch(err){next(err);}
});

/**
 * PATCH /api/reportes/pedidos/:id
 * Actualiza el estado de un pedido: pendiente → enviado → recibido | cancelado.
 */
router.post('/pedidos/generar', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    const pedidos = await generarPorFaltantes(client, null, req.usuario.id);
    await client.query('COMMIT');
    res.status(pedidos.length ? 201 : 200).json({ generados: pedidos.length, pedidos });
  } catch (err) {
    if (client) await client.query('ROLLBACK');
    next(err);
  } finally {
    if (client) client.release();
  }
});

router.patch('/pedidos/:id', permitirRoles('administrador', 'bodega'), async (req, res, next) => {
  const { estado } = req.body;

  if (!esEnteroPositivo(req.params.id)) return res.status(400).json({ error: 'El ID del pedido debe ser un número entero positivo' });

  if (!ESTADOS_PEDIDO.includes(estado)) {
    return res.status(400).json({ error: `Estado inválido. Use: ${ESTADOS_PEDIDO.join(', ')}` });
  }

  let client;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    const pedido = await actualizarEstado(client, req.params.id, estado, req.usuario.id);
    await client.query('COMMIT');
    res.json(pedido);
  } catch (err) {
    if (client) await client.query('ROLLBACK');
    next(err);
  } finally {
    if (client) client.release();
  }
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
