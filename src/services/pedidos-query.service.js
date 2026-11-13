const { esEnteroPositivo } = require('../middleware/validation.middleware');
const bad = message => Object.assign(new Error(message), { status: 400 });
function filtrosPedidos(query) {
  const estados = ['pendiente', 'enviado', 'recibido', 'cancelado', 'todos', 'parcial'];
  const estado = estados.includes(query.estado) ? query.estado : 'pendiente';
  const page = query.page === undefined ? 1 : Number(query.page);
  const limit = query.limit === undefined ? 25 : Math.min(Number(query.limit), 100);
  if (query.page !== undefined && !esEnteroPositivo(query.page)) throw bad('La página debe ser un entero positivo');
  if (query.limit !== undefined && !esEnteroPositivo(query.limit)) throw bad('El límite debe ser un entero positivo');
  if (query.q !== undefined && (typeof query.q !== 'string' || query.q.length > 150)) throw bad('La búsqueda admite hasta 150 caracteres');
  if (query.alerta && !['agotado', 'atrasado', 'sin_pedido'].includes(query.alerta)) throw bad('Alerta inválida');
  const values = [];
  const where = [];
  const param = value => { values.push(value); return `$${values.length}`; };
  if (estado === 'parcial') where.push("ped.estado='enviado' AND ped.cantidad_recibida>0");
  else if (estado !== 'todos') where.push(`ped.estado=${param(estado)}`);
  if (query.q?.trim()) {
    const q = param('%' + query.q.trim().replace(/[\\%_]/g, '\\$&') + '%');
    where.push(`(p.nombre ILIKE ${q} OR p.codigo ILIKE ${q} OR ped.id::text ILIKE ${q} OR prov.nombre ILIKE ${q})`);
  }
  if (query.desde) where.push(`ped.generado_en >= ${param(query.desde)}::date`);
  if (query.hasta) where.push(`ped.generado_en < ${param(query.hasta)}::date + INTERVAL '1 day'`);
  if (query.alerta === 'atrasado') where.push("ped.estado IN ('pendiente','enviado') AND ped.entrega_estimada < CURRENT_DATE");
  if (query.alerta === 'agotado') where.push('p.stock_actual<=0 AND p.activo=TRUE');
  return { estado, page, limit, values, where: where.length ? 'WHERE ' + where.join(' AND ') : '' };
}
const from = 'FROM pedidos ped JOIN productos p ON p.id=ped.producto_id LEFT JOIN proveedores prov ON prov.id=ped.proveedor_id';
const select = `SELECT ped.*, p.codigo, p.nombre AS producto, p.stock_actual, p.stock_minimo,
  prov.nombre AS proveedor, GREATEST(ped.cantidad_sugerida-ped.cantidad_recibida,0) AS cantidad_pendiente,
  (ped.cantidad_sugerida*ped.costo_unitario) AS costo_total,
  (ped.estado IN ('pendiente','enviado') AND ped.entrega_estimada<CURRENT_DATE) AS atrasado ${from}`;
function csvCell(value) {
  let text = String(value ?? '');
  if (/^[\s]*[=+@-]/.test(text)) text = "'" + text;
  return '"' + text.replace(/"/g, '""') + '"';
}
module.exports = { filtrosPedidos, from, select, csvCell };
