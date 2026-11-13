const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');

let queries = 0;
require.cache[require.resolve('../src/db/connection')] = {
  exports: { query: async sql => {
    queries++;
    return { rows: /COUNT\(\*\)/.test(sql) ? [{ count: '0' }] : [] };
  } },
};
process.env.JWT_SECRET = 'validation-local-test-secret';
const app = express();
app.use('/api/movimientos', require('../src/routes/movimiento.routes'));
app.use('/api/reportes', require('../src/routes/reporte.routes'));
app.use('/api/productos', require('../src/routes/producto.routes'));

test('Entradas inválidas se rechazan antes de consultar la base de datos', async t => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}/api`;
  const headers = { Authorization: `Bearer ${jwt.sign({ rol: 'administrador' }, process.env.JWT_SECRET)}` };
  const invalid = [
    '/movimientos?limit=-1', '/movimientos?limit=0', '/movimientos?limit=1.5',
    '/movimientos?page=-1', '/movimientos?page=abc', '/movimientos?page=9999999999999999999999',
    '/movimientos?producto_id=abc', '/movimientos?producto_id=12abc',
    '/movimientos?desde=no-es-fecha', '/movimientos?desde=2026-02-30',
    '/movimientos?desde=2026-11-06&hasta=2026-11-01',
    '/reportes/gastos?desde=no-es-fecha', '/reportes/gastos?desde=2026-11-06&hasta=2026-11-01',
    '/reportes/corte-diario?fecha=2026-02-29', '/reportes/corte-diario?fecha=2026-13-01',
    '/reportes/movimientos?desde[]=2026-11-01',
    '/reportes/export/movimientos?hasta=invalid',
    '/productos/no-es-numero', '/productos/-1', '/productos/1.5', '/productos/2147483648',
  ];
  for (const route of invalid) {
    await t.test(route, async () => {
      const before = queries;
      const res = await fetch(base + route, { headers });
      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(typeof data.error, 'string');
      assert.doesNotMatch(data.error, /postgres|syntax|SELECT|integer/i);
      assert.equal(queries, before);
    });
  }
  for (const route of ['/movimientos?limit=1&page=1', '/movimientos?limit=201', '/reportes/pedidos?desde=2024-02-29', '/reportes/pedidos?desde=2026-11-01&hasta=2026-11-06']) {
    await t.test(`Consulta válida ${route}`, async () => {
      const res = await fetch(base + route, { headers });
      assert.equal(res.status, 200);
      const data = await res.json();
      if (route.includes('limit=201')) assert.equal(data.limit, 200);
    });
  }
  await t.test('Token requerido antes de validar filtros', async () => {
    const res = await fetch(base + '/movimientos?limit=-1');
    assert.equal(res.status, 401);
  });
});
