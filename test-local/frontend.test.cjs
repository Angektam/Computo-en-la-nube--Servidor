const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function entorno(rol = 'cajero') {
  const elements = new Map();
  const storage = new Map([['token', 'token-local'], ['usuario', '{}']]);
  const state = { reloads: 0, calls: [] };
  const document = {
    getElementById(id) {
      if (!elements.has(id)) {
        const classes = new Set();
        const element = {
          id, style: {}, value: '', textContent: '', innerHTML: '',
          classList: {
            add: value => classes.add(value), remove: value => classes.delete(value),
            contains: value => classes.has(value),
            toggle(value, on) { if (on) classes.add(value); else classes.delete(value); },
          },
          handlers: {}, closest() { return this; },
          addEventListener(event, handler) { this.handlers[event] = handler; },
        };
        elements.set(id, element);
      }
      return elements.get(id);
    },
    querySelectorAll: () => [], addEventListener() {},
  };
  const context = vm.createContext({
    document, console, URLSearchParams,
    localStorage: { getItem: key => storage.get(key), removeItem: key => storage.delete(key) },
    window: { location: { reload: () => state.reloads++ } },
    Auth: { tieneRol: (...roles) => roles.includes(rol) },
    fetch: async () => new Response('{}'),
    mostrarCargando() {}, Toast: { success() {}, error() {} },
  });
  function cargar(file, symbol) {
    vm.runInContext(fs.readFileSync(`public/js/${file}.js`, 'utf8') + `\nthis.subject = ${symbol};`, context);
    return context.subject;
  }
  return { context, document, state, storage, cargar };
}

test('Login inválido muestra error sin borrar sesión ni recargar', async () => {
  const e = entorno();
  e.context.fetch = async () => new Response(JSON.stringify({ error: 'Credenciales inválidas' }), { status: 401 });
  const api = e.cargar('api', 'api');
  await assert.rejects(api.post('/auth/login', {}), /Credenciales inválidas/);
  assert.equal(e.state.reloads, 0);
  assert.equal(e.storage.get('token'), 'token-local');
});

for (const tipo of ['get', 'upload', 'blob']) {
  test(`Sesión expirada en ${tipo} borra sesión y rechaza la operación`, async () => {
    const e = entorno();
    e.context.fetch = async () => new Response('{}', { status: 401 });
    const api = e.cargar('api', 'api');
    await assert.rejects(api[tipo]('/productos'), /sesión expiró/);
    assert.equal(e.state.reloads, 1);
    assert.equal(e.storage.has('token'), false);
    assert.equal(e.storage.has('usuario'), false);
  });
}

test('Exportación fallida nunca entrega un archivo', async () => {
  const e = entorno();
  e.context.fetch = async () => new Response(JSON.stringify({ error: 'Sin permiso' }), { status: 403 });
  await assert.rejects(e.cargar('api', 'api').blob('/reportes/export/faltantes'), /Sin permiso/);
});

test('Exportación válida devuelve CSV', async () => {
  const e = entorno();
  e.context.fetch = async () => new Response('Código,Nombre\nA,Producto', { headers: { 'Content-Type': 'text/csv' } });
  const blob = await e.cargar('api', 'api').blob('/reportes/export/faltantes');
  assert.match(await blob.text(), /A,Producto/);
});

test('Respuesta HTML inesperada produce un error legible', async () => {
  const e = entorno();
  e.context.fetch = async () => new Response('<html>Error</html>', { status: 502 });
  await assert.rejects(e.cargar('api', 'api').get('/productos'), /respuesta inesperada \(HTTP 502\)/);
});

test('Respuesta 204 no intenta interpretar JSON', async () => {
  const e = entorno();
  e.context.fetch = async () => new Response(null, { status: 204 });
  assert.equal(await e.cargar('api', 'api').delete('/productos/1'), null);
});

for (const rol of ['cajero', 'bodega', 'administrador']) {
  test(`Dashboard carga para ${rol} sin consultas prohibidas`, async () => {
    const e = entorno(rol);
    e.cargar('api', 'api');
    e.context.api = { async get(path) {
      e.state.calls.push(path);
      if (path === '/productos') return [];
      if (path === '/reportes/corte-diario') return { resumen: { total_movimientos: 2 } };
      return { total: 0, productos: [] };
    }};
    // Sustituir el módulo de red dentro del mismo contexto.
    vm.runInContext('api.get = (ruta) => this.api.get(ruta);', e.context);
    await e.cargar('dashboard', 'Dashboard').cargar();
    assert.equal(e.state.calls.includes('/reportes/pedidos'), rol !== 'cajero');
    assert.equal(e.state.calls.includes('/reportes/corte-diario'), rol !== 'cajero');
    assert.equal(e.document.getElementById('num-productos').textContent, 0);
    assert.equal(e.document.getElementById('num-pedidos').classList.contains('hidden'), rol === 'cajero');
  });
}

test('Al cambiar filtros rápido, una respuesta antigua no reemplaza la última', async () => {
  const e = entorno('bodega');
  e.context.escaparHtml = value => String(value);
  const pending = [];
  e.context.api = { get: () => new Promise(resolve => pending.push(resolve)) };
  const pedidos = e.cargar('pedidos', 'Pedidos');
  const first = pedidos.cargar('pendiente');
  const second = pedidos.cargar('recibido');
  pending[1]({ total: 0, pedidos: [] });
  await second;
  const html = e.document.getElementById('tabla-pedidos').innerHTML;
  pending[0]({ total: 5, pedidos: [{ id: 1 }] });
  await first;
  assert.equal(e.document.getElementById('tabla-pedidos').innerHTML, html);
  assert.match(html, /recibido/);
});

test('Doble clic en actualizar pedido envía una sola solicitud', async () => {
  const e = entorno('bodega');
  let complete;
  e.context.api = {
    patch: () => { e.state.calls.push('patch'); return new Promise(resolve => { complete = resolve; }); },
    get: async () => ({ total: 0, pedidos: [] }),
  };
  e.context.Dashboard = { cargar() {} };
  const pedidos = e.cargar('pedidos', 'Pedidos');
  const first = pedidos.cambiarEstado(1, 'enviado');
  await pedidos.cambiarEstado(1, 'enviado');
  assert.equal(e.state.calls.length, 1);
  complete();
  await first;
});

test('Cajero no puede abrir Pedidos, Usuarios ni Categorías por navegación directa', () => {
  const e = entorno();
  const source = fs.readFileSync('public/js/app.js', 'utf8');
  const start = source.indexOf('const Nav =');
  const end = source.indexOf('return { ir };', start) + 'return { ir };\n})();'.length;
  // Sin Topbar ni módulos de datos: cualquier navegación efectiva fallaría.
  vm.runInContext(source.slice(start, end) + '\nNav.ir("pedidos"); Nav.ir("usuarios"); Nav.ir("categorias");', e.context);
});

test('Gastos rechaza rangos invertidos antes de consultar la API', async () => {
  const e = entorno('administrador');
  const errors = [];
  e.context.Toast.error = message => errors.push(message);
  e.context.api = { get: async path => { e.state.calls.push(path); } };
  e.cargar('reportes', 'Reportes');
  e.document.getElementById('gastos-desde').value = '2026-11-06';
  e.document.getElementById('gastos-hasta').value = '2026-11-01';
  await e.document.getElementById('btn-gastos').handlers.click();
  assert.equal(e.state.calls.length, 0);
  assert.match(errors[0], /fecha inicial/);
});

test('Cajero no consulta gastos ni corte diario desde sus controles', async () => {
  const e = entorno();
  e.context.api = { get: async path => { e.state.calls.push(path); } };
  e.cargar('reportes', 'Reportes');
  await e.document.getElementById('btn-gastos').handlers.click();
  await e.document.getElementById('btn-corte').handlers.click();
  assert.equal(e.state.calls.length, 0);
});

test('Textos de productos se convierten en texto seguro para las tablas', () => {
  const e = entorno();
  const escapar = e.cargar('api', 'escaparHtml');
  assert.equal(escapar('<img src=x onerror="alert(1)">'), '&lt;img src=x onerror=&quot;alert(1)&quot;&gt;');
});

test('Generar pedidos actualiza pendientes y evita doble clic', async () => {
  const e = entorno('bodega');
  let complete;
  e.context.api = {
    post: async path => {
      e.state.calls.push(path);
      return new Promise(resolve => { complete = resolve; });
    },
    get: async () => ({ total: 0, pedidos: [] }),
  };
  e.context.Dashboard = { cargar() {} };
  const pedidos = e.cargar('pedidos', 'Pedidos');
  const first = pedidos.generar();
  await pedidos.generar();
  assert.equal(e.state.calls.length, 1);
  assert.equal(e.document.getElementById('btn-generar-pedidos').disabled, true);
  complete({ generados: 2 });
  await first;
  assert.equal(e.document.getElementById('btn-generar-pedidos').disabled, false);
  assert.equal(e.document.getElementById('filtro-estado-pedido').value, 'pendiente');
  assert.match(e.document.getElementById('tabla-pedidos').innerHTML, /Generar por faltantes/);
});

test('Recepción muestra confirmación antes de modificar el inventario', async () => {
  const e = entorno('bodega');
  e.context.escaparHtml = value => String(value);
  let dialog;
  e.context.Modal = { abrir(html) { dialog = html; }, cerrar() {} };
  e.context.api = {
    get: async () => ({ total: 1, pedidos: [{ id: 1, estado: 'enviado', cantidad_sugerida: 7, producto: 'Producto de prueba' }] }),
    patch: async () => e.state.calls.push('patch'),
  };
  const pedidos = e.cargar('pedidos', 'Pedidos');
  await pedidos.cargar('enviado');
  pedidos.solicitarCambio(1, 'recibido');
  assert.equal(e.state.calls.length, 0);
  assert.match(dialog, /entrada de hasta <strong>7<\/strong>/);
  assert.match(dialog, /Confirmar recepción/);
});
