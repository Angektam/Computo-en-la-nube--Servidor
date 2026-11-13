// Validar antes de enviar entradas del cliente a PostgreSQL.
function esEnteroPositivo(value) {
  return typeof value === 'string' && /^\d+$/.test(value)
    && Number.isSafeInteger(Number(value)) && Number(value) > 0
    && Number(value) <= 2147483647;
}

function validarFechas(req, res, next) {
  for (const field of ['desde', 'hasta', 'fecha']) {
    const value = req.query[field];
    if (value === undefined) continue;
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return res.status(400).json({ error: `${field} debe ser una fecha válida con formato YYYY-MM-DD` });
    }
    const date = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
      return res.status(400).json({ error: `${field} debe ser una fecha válida con formato YYYY-MM-DD` });
    }
  }
  if (req.query.desde && req.query.hasta && req.query.desde > req.query.hasta) {
    return res.status(400).json({ error: 'La fecha inicial debe ser anterior o igual a la final' });
  }
  next();
}

function validarPaginacion(req, res, next) {
  for (const field of ['page', 'limit', 'producto_id']) {
    if (req.query[field] !== undefined && !esEnteroPositivo(req.query[field])) {
      return res.status(400).json({ error: `${field} debe ser un número entero positivo` });
    }
  }
  next();
}

module.exports = { esEnteroPositivo, validarFechas, validarPaginacion };
