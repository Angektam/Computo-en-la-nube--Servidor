const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');

// Base de datos simulada: estas pruebas nunca consultan ni alteran producción.
const queries = [];
let rows = [];
const query = async (sql, params) => {
  queries.push({ sql, params });
  if (sql.includes('SELECT producto_id FROM pedidos')) return { rows: rows.map(r => ({ producto_id: 1 })) };
  if (sql.includes('SELECT id, stock_actual, activo FROM productos')) return { rows: [{ id: 1, stock_actual: 3, activo: true }] };
  if (sql.includes('SELECT COUNT(*)::integer AS total')) return { rows: [{ total: rows.length }] };
  if (sql.includes('SELECT * FROM pedidos')) return { rows: rows.map(r => ({ ...r, estado: 'enviado', cantidad_sugerida: 2 })) };
  return { rows };
};
require.cache[require.resolve('../src/db/connection')] = {
  exports: { query, connect: async () => ({ query, release() {} }) }
};
process.env.JWT_SECRET = 'pedidos-local-test-secret';
const app = express();
app.use(express.json());
app.use('/api/reportes', require('../src/routes/reporte.routes'));
app.use((err, _req, res, _next) => res.status(err.status || 500).json({ error: err.message }));

test('Pedidos: autenticación, permisos, filtros y actualización', async (t) => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}/api/reportes/pedidos`;
  async function request(rol, suffix = '', method = 'GET', body) {
    const headers = { 'Content-Type': 'application/json' };
    if (rol) headers.Authorization = `Bearer ${jwt.sign({ id: 1, rol }, process.env.JWT_SECRET)}`;
    return fetch(base + suffix, { method, headers, body: body && JSON.stringify(body) });
  }
  await t.test('sin sesión devuelve 401', async () => {
    assert.equal((await request()).status, 401);
  });
  for (const estado of ['pendiente', 'enviado', 'recibido', 'cancelado']) {
    await t.test(`Cajero no puede consultar ${estado}`, async () => {
      const before = queries.length;
      const res = await request('cajero', `?estado=${estado}`);
      assert.equal(res.status, 403);
      assert.equal((await res.json()).error, 'Acceso denegado: rol insuficiente');
      assert.equal(queries.length, before);
    });
  }
  await t.test('Cajero no puede modificar pedidos', async () => {
    const before = queries.length;
    assert.equal((await request('cajero', '/1', 'PATCH', { estado: 'recibido' })).status, 403);
    assert.equal(queries.length, before);
  });
  for (const rol of ['administrador', 'bodega']) {
    for (const estado of ['pendiente', 'enviado', 'recibido', 'cancelado']) {
      await t.test(`${rol} filtra ${estado}`, async () => {
        rows = [{ id: 1, estado }];
        const res = await request(rol, `?estado=${estado}`);
        assert.equal(res.status, 200);
        const body = await res.json();
        assert.equal(body.total, 1);
        assert.equal(body.estado, estado);
        assert.equal(body.page, 1);
        assert.equal(body.limit, 25);
        assert.equal(body.paginas, 1);
        assert.equal(body.pedidos.length, 1);
        assert.equal(body.pedidos[0].id, 1);
        assert.deepEqual(queries.at(-1).params, [estado, 25, 0]);
      });
    }
    await t.test(`${rol} actualiza un pedido`, async () => {
      rows = [{ id: 1, estado: 'recibido' }];
      const res = await request(rol, '/1', 'PATCH', { estado: 'recibido' });
      assert.equal(res.status, 200);
      assert.deepEqual(await res.json(), rows[0]);
      assert.deepEqual(queries.findLast(q => q.sql.includes('UPDATE pedidos')).params.slice(0, 2), ['recibido', '1']);
    });
  }
  await t.test('lista vacía y filtro omitido', async () => {
    rows = [];
    const res = await request('bodega');
    assert.deepEqual(await res.json(), { total: 0, pedidos: [], estado: 'pendiente', page: 1, limit: 25, paginas: 0 });
  });
  await t.test('filtro desconocido usa pendiente', async () => {
    const res = await request('bodega', '?estado=desconocido');
    assert.equal((await res.json()).estado, 'pendiente');
  });
  await t.test('estado de actualización inválido devuelve 400', async () => {
    assert.equal((await request('bodega', '/1', 'PATCH', { estado: 'desconocido' })).status, 400);
  });
  await t.test('pedido inexistente devuelve 404', async () => {
    rows = [];
    assert.equal((await request('bodega', '/999', 'PATCH', { estado: 'enviado' })).status, 404);
  });
});
