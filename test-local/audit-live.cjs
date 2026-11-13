// Auditoría de solo lectura. Máximo cinco solicitudes concurrentes; sin escrituras.
const fs = require('node:fs');
const path = require('node:path');
const { performance } = require('node:perf_hooks');
const base = 'http://alb-inventario-cloud-los-rojos-727813269.us-east-1.elb.amazonaws.com';
const results = [];
const timings = [];
let requests = 0;
let active = 0;
let maxActive = 0;

async function request(route, { token, method = 'GET', body } = {}) {
  if (++requests > 100) throw new Error('Límite de 100 solicitudes alcanzado');
  const start = performance.now();
  active++;
  maxActive = Math.max(maxActive, active);
  try {
    const headers = {};
    if (token) headers.Authorization = `Bearer ${token}`;
    if (body) headers['Content-Type'] = 'application/json';
    const response = await fetch(base + route, {
      method, headers, body: body && JSON.stringify(body), signal: AbortSignal.timeout(15000),
    });
    const text = await response.text();
    let data;
    try { data = JSON.parse(text); } catch {}
    const ms = Math.round(performance.now() - start);
    timings.push(ms);
    return { status: response.status, headers: response.headers, text, data, ms };
  } finally { active--; }
}

async function check(name, route, options, verify, expectation) {
  try {
    const response = await request(route, options);
    const pass = !!verify(response);
    const result = { name, route, pass, status: response.status, ms: response.ms, expectation };
    results.push(result);
    console.log(`${pass ? 'PASS' : 'FAIL'} ${name}: HTTP ${response.status} (${response.ms} ms)`);
    return response;
  } catch (err) {
    results.push({ name, route, pass: false, expectation, error: err.name });
    console.log(`FAIL ${name}: ${err.name}`);
  }
}

async function main() {
  const page = await check('Página principal de inventario', '/index-1.html', {},
    r => r.status === 200 && r.text.includes('form-login'), '200 y formulario de login');
  if (page) {
    results.push({ name: 'Cabeceras de protección', pass: page.headers.get('x-content-type-options') === 'nosniff' && !!page.headers.get('content-security-policy'), expectation: 'nosniff y CSP presentes' });
    const assets = [...page.text.matchAll(/(?:src|href)="((?:js|css)\/[^"?#]+)(?:[^"\s]*)"/g)].map(m => m[1]);
    for (const asset of new Set(assets)) {
      await check(`Archivo ${asset}`, '/' + asset, {}, r => r.status === 200 && !r.text.startsWith('<!DOCTYPE'), '200 y contenido de recurso');
    }
  }
  await check('Salud de servidor y base de datos', '/health', {}, r => r.status === 200 && r.data?.db === 'ok', '200 y db=ok');
  for (const route of ['/api/productos', '/api/movimientos?limit=1', '/api/reportes/pedidos', '/api/usuarios', '/api/categorias', '/api/reportes/export/faltantes']) {
    await check(`Sin sesión: ${route}`, route, {}, r => r.status === 401 && !!r.data?.error, '401 JSON');
  }
  await check('Token manipulado', '/api/productos', { token: 'invalid.invalid.invalid' }, r => r.status === 401, '401');
  for (const route of ['/.env', '/.git/config']) {
    await check(`Archivo privado ${route}`, route, {}, r => !/(?:DB_PASSWORD\s*=|JWT_SECRET\s*=|\[core\])/.test(r.text), 'Ninguna configuración privada expuesta');
  }
  await check('Endpoint API inexistente', '/api/ruta-inexistente-auditoria', {}, r => r.status === 404 && !!r.data?.error, '404 con error JSON');

  const documentation = fs.readFileSync(path.join(__dirname, '..', 'COMANDOS.md'), 'utf8');
  const sessions = {};
  for (const role of ['admin', 'bodega', 'cajero']) {
    const row = documentation.split('\n').find(line => line.includes(role + '@empresa.com') && line.trim().startsWith('|'));
    if (!row) { results.push({ name: `Login ${role}`, pass: false, expectation: 'Credenciales documentadas disponibles' }); continue; }
    const fields = row.split('|').map(s => s.trim());
    const response = await check(`Login ${role}`, '/api/auth/login', {
      method: 'POST', body: { correo: fields[1], password: fields[2] },
    }, r => r.status === 200 && !!r.data?.token, '200 y token válido');
    if (response?.status === 200) sessions[role] = response.data.token;
  }
  for (const [role, token] of Object.entries(sessions)) {
    await check(`${role}: productos`, '/api/productos', { token }, r => r.status === 200 && Array.isArray(r.data), '200 y lista');
    await check(`${role}: categorías`, '/api/categorias', { token }, r => r.status === 200 && Array.isArray(r.data), '200 y lista');
    await check(`${role}: movimientos paginados`, '/api/movimientos?limit=5&page=1', { token }, r => r.status === 200 && Array.isArray(r.data?.datos) && r.data.datos.length <= 5, '200 y máximo cinco registros');
    await check(`${role}: usuarios`, '/api/usuarios', { token }, r => role === 'admin'
      ? r.status === 200 && Array.isArray(r.data) && r.data.every(u => !('password' in u))
      : r.status === 403, role === 'admin' ? '200 sin contraseñas' : '403');
    await check(`${role}: gastos`, '/api/reportes/gastos', { token }, r => r.status === (role === 'admin' ? 200 : 403), role === 'admin' ? '200' : '403');
    await check(`${role}: corte diario`, '/api/reportes/corte-diario', { token }, r => r.status === (role === 'cajero' ? 403 : 200), role === 'cajero' ? '403' : '200');
    for (const state of ['pendiente', 'enviado', 'recibido', 'cancelado']) {
      await check(`${role}: pedidos ${state}`, `/api/reportes/pedidos?estado=${state}`, { token }, r => role === 'cajero'
        ? r.status === 403
        : r.status === 200 && r.data?.estado === state && r.data?.total === r.data?.pedidos?.length && r.data.pedidos.every(p => p.estado === state), role === 'cajero' ? '403' : '200 y estado/total consistentes');
    }
  }

  if (sessions.admin) {
    const token = sessions.admin;
    for (const [name, route, expectation, verify] of [
      ['Producto inexistente', '/api/productos/2147483647', '404', r => r.status === 404],
      ['ID de producto inválido', '/api/productos/no-es-numero', '400 sin detalles SQL', r => r.status === 400 && !/integer|syntax|postgres/i.test(r.data?.error || '')],
      ['Paginación con límite negativo', '/api/movimientos?limit=-1', '400 o límite positivo normalizado', r => r.status === 400 || (r.status === 200 && r.data?.limit > 0)],
      ['Filtro de producto inválido', '/api/movimientos?producto_id=abc&limit=1', '400', r => r.status === 400],
      ['Fecha inválida en movimientos', '/api/movimientos?desde=no-es-fecha&limit=1', '400', r => r.status === 400],
      ['Fecha inválida en gastos', '/api/reportes/gastos?desde=no-es-fecha', '400', r => r.status === 400],
      ['Rango de fechas invertido', '/api/reportes/gastos?desde=2026-11-06&hasta=2026-11-01', '400', r => r.status === 400],
      ['Filtro de pedido desconocido', '/api/reportes/pedidos?estado=no-existe', '400 o pendiente normalizado', r => r.status === 400 || (r.status === 200 && r.data?.estado === 'pendiente')],
      ['Página alta sin resultados', '/api/movimientos?page=1000000&limit=1', '200 y lista vacía', r => r.status === 200 && r.data?.datos?.length === 0],
      ['Exportación faltantes', '/api/reportes/export/faltantes', '200 CSV', r => r.status === 200 && r.headers.get('content-type')?.includes('text/csv') && r.text.includes('Código')],
      ['Exportación movimientos', '/api/reportes/export/movimientos', '200 CSV', r => r.status === 200 && r.headers.get('content-type')?.includes('text/csv') && r.text.includes('Stock antes')],
    ]) await check(name, route, { token }, verify, expectation);

    // Tres rondas de cinco consultas ligeras. Sin búsquedas grandes ni escrituras.
    for (let round = 1; round <= 3; round++) {
      await Promise.all(Array.from({ length: 5 }, (_, i) => check(`Concurrencia ronda ${round}, consulta ${i + 1}`,
        '/api/movimientos?limit=1&page=1', { token }, r => r.status === 200 && Array.isArray(r.data?.datos), '200')));
    }
  }
  const health = await check('Salud después de las pruebas', '/health', {}, r => r.status === 200 && r.data?.db === 'ok', '200 y db=ok');
  const ordered = timings.toSorted((a, b) => a - b);
  const report = {
    timestamp: new Date().toISOString(), base, scope: 'HTTP y API; sin navegador; sin escrituras en datos de negocio',
    requests, maxConcurrency: maxActive, checks: results.length,
    passed: results.filter(r => r.pass).length, failed: results.filter(r => !r.pass).length,
    latencyMs: { median: ordered[Math.floor(ordered.length / 2)], p95: ordered[Math.ceil(ordered.length * 0.95) - 1], max: ordered.at(-1) },
    healthyAfter: health?.status === 200 && health?.data?.db === 'ok', results,
  };
  fs.writeFileSync(path.join(__dirname, 'aws-audit.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ ...report, results: undefined }, null, 2));
  process.exitCode = report.failed ? 1 : 0;
}
main().catch(err => { console.error(err.name, err.message); process.exitCode = 1; });
