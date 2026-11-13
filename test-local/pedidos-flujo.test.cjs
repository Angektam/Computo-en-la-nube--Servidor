const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const jwt = require('jsonwebtoken');

let fixture;
let statements;
let released;
let failMovement;
let generated;
const query = async (sql, params) => {
  statements.push({ sql, params });
  if (sql.includes('SELECT producto_id FROM pedidos')) return { rows: fixture ? [{ producto_id: 9 }] : [] };
  if (sql.includes('SELECT id, stock_actual, activo FROM productos')) return { rows: [{ id: 9, stock_actual: 3, activo: fixture.activo ?? true }] };
  if (sql.includes('SELECT * FROM pedidos')) return { rows: fixture ? [{ id: 1, producto_id: 9, ...fixture }] : [] };
  if (sql.includes('INSERT INTO movimientos') && failMovement) throw new Error('Fallo simulado de escritura');
  if (sql.includes('UPDATE pedidos')) {
    fixture.estado = params[0];
    return { rows: [{ id: 1, producto_id: 9, ...fixture }] };
  }
  if (sql.includes('INSERT INTO pedidos')) return { rows: generated };
  return { rows: [] };
};
require.cache[require.resolve('../src/db/connection')] = {
  exports: { query, connect: async () => ({ query, release() { released++; } }) },
};
process.env.JWT_SECRET = 'pedidos-flow-local-secret';
const app = express();
app.use(express.json());
app.use('/api/reportes', require('../src/routes/reporte.routes'));
app.use((err, _req, res, _next) => res.status(err.status || 500).json({ error: err.message }));

test('Flujo de pedidos: generación y recepción transaccional', async t => {
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}/api/reportes/pedidos`;
  function reset(estado = 'enviado') {
    fixture = { estado, cantidad_sugerida: 7 };
    statements = []; released = 0; failMovement = false; generated = [];
  }
  const count = text => statements.filter(q => q.sql.includes(text)).length;
  const request = (rol, suffix, method, body) => fetch(base + suffix, {
    method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jwt.sign({ id: 4, rol }, process.env.JWT_SECRET)}` },
    body: JSON.stringify(body),
  });
  for (const role of ['administrador', 'bodega']) {
    await t.test(`${role} recibe, suma existencias y deja un movimiento`, async () => {
      reset();
      const res = await request(role, '/1', 'PATCH', { estado: 'recibido' });
      assert.equal(res.status, 200);
      assert.equal((await res.json()).estado, 'recibido');
      assert.deepEqual(statements.find(q => q.sql.includes('UPDATE productos')).params, [10, 9]);
      assert.deepEqual(statements.find(q => q.sql.includes('INSERT INTO movimientos')).params, [9, 4, 7, 3, 10, 'Recepción del pedido #1']);
      assert.equal(count('COMMIT'), 1);
      assert.equal(released, 1);
      const retry = await request(role, '/1', 'PATCH', { estado: 'recibido' });
      assert.equal(retry.status, 409);
      assert.equal(count('INSERT INTO movimientos'), 1);
      assert.equal(count('UPDATE productos'), 1);
      assert.equal(count('ROLLBACK'), 1);
    });
  }
  for (const [from, to] of [['pendiente', 'recibido'], ['recibido', 'enviado'], ['cancelado', 'recibido'], ['enviado', 'pendiente']]) {
    await t.test(`Bloquea transición ${from} → ${to}`, async () => {
      reset(from);
      assert.equal((await request('bodega', '/1', 'PATCH', { estado: to })).status, 409);
      assert.equal(count('UPDATE productos'), 0);
      assert.equal(count('UPDATE pedidos'), 0);
      assert.equal(count('ROLLBACK'), 1);
    });
  }
  for (const [from, to] of [['pendiente', 'enviado'], ['pendiente', 'cancelado'], ['enviado', 'cancelado']]) {
    await t.test(`Permite ${from} → ${to} sin alterar existencias`, async () => {
      reset(from);
      assert.equal((await request('bodega', '/1', 'PATCH', { estado: to })).status, 200);
      assert.equal(count('UPDATE productos'), 0);
      assert.equal(count('INSERT INTO movimientos'), 0);
    });
  }
  await t.test('Fallo al registrar entrada revierte toda la transacción', async () => {
    reset(); failMovement = true;
    assert.equal((await request('bodega', '/1', 'PATCH', { estado: 'recibido' })).status, 500);
    assert.equal(count('ROLLBACK'), 1);
    assert.equal(count('COMMIT'), 0);
    assert.equal(count('UPDATE pedidos'), 0);
    assert.equal(released, 1);
  });
  await t.test('No permite recibir un producto inactivo', async () => {
    reset(); fixture.activo = false;
    assert.equal((await request('bodega', '/1', 'PATCH', { estado: 'recibido' })).status, 409);
    assert.equal(count('UPDATE productos'), 0);
  });
  await t.test('Cantidad inválida no altera existencias', async () => {
    reset(); fixture.cantidad_sugerida = -7;
    assert.equal((await request('bodega', '/1', 'PATCH', { estado: 'recibido' })).status, 400);
    assert.equal(count('UPDATE productos'), 0);
  });
  await t.test('ID inválido no consulta la base de datos', async () => {
    reset();
    assert.equal((await request('bodega', '/abc', 'PATCH', { estado: 'recibido' })).status, 400);
    assert.equal(statements.length, 0);
  });
  await t.test('Cajero no puede generar pedidos', async () => {
    reset();
    assert.equal((await request('cajero', '/generar', 'POST', {})).status, 403);
    assert.equal(statements.length, 0);
  });
  await t.test('Generación devuelve pedidos creados y confirma transacción', async () => {
    reset(); generated = [{ id: 8, producto_id: 9, cantidad_sugerida: 7, estado: 'pendiente' }];
    const res = await request('bodega', '/generar', 'POST', {});
    assert.equal(res.status, 201);
    const data = await res.json();
    assert.equal(data.generados, 1);
    assert.deepEqual(data.pedidos, generated);
    assert.equal(count('COMMIT'), 1);
    assert.equal(released, 1);
  });
  await t.test('Sin faltantes nuevos devuelve cero pedidos', async () => {
    reset();
    const res = await request('administrador', '/generar', 'POST', {});
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { generados: 0, pedidos: [] });
  });
});
