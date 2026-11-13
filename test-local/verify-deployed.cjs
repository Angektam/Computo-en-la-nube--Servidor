// Verificación posterior al despliegue, sin modificar datos de negocio.
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const base = 'http://alb-inventario-cloud-los-rojos-727813269.us-east-1.elb.amazonaws.com';
const results = [];
const digest = bytes => createHash('sha256').update(bytes).digest('hex');

async function check(name, route, verify, token) {
  const response = await fetch(base + route, {
    headers: token ? { Authorization: `Bearer ${token}` } : {}, signal: AbortSignal.timeout(15000),
  });
  const bytes = Buffer.from(await response.arrayBuffer());
  let data;
  try { data = JSON.parse(bytes.toString('utf8')); } catch {}
  const pass = !!verify(response.status, data, bytes);
  results.push({ name, route, pass, status: response.status });
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name}: HTTP ${response.status}`);
}

async function main() {
  for (const asset of ['index-1.html', 'js/api.js', 'js/app.js', 'js/dashboard.js', 'js/movimientos.js', 'js/pedidos.js', 'js/reportes.js']) {
    const local = fs.readFileSync(path.resolve(__dirname, '../public', asset));
    await check(`Contenido publicado coincide: ${asset}`, '/' + asset, (status, _data, bytes) => status === 200 && digest(bytes) === digest(local));
  }
  await check('Servidor y base de datos saludables', '/health', (status, data) => status === 200 && data?.db === 'ok');
  await check('Ruta API inexistente devuelve JSON', '/api/ruta-inexistente-auditoria', (status, data) => status === 404 && !!data?.error);
  await check('Pedidos requieren sesión', '/api/reportes/pedidos', status => status === 401);
  const doc = fs.readFileSync(path.resolve(__dirname, '../COMANDOS.md'), 'utf8');
  for (const role of ['admin', 'bodega']) {
    const row = doc.split('\n').find(line => line.includes(role + '@empresa.com') && line.trim().startsWith('|'));
    if (!row) throw new Error(`No se encontraron credenciales de prueba para ${role}`);
    const fields = row.split('|').map(s => s.trim());
    const response = await fetch(base + '/api/auth/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ correo: fields[1], password: fields[2] }), signal: AbortSignal.timeout(15000),
    });
    const data = await response.json();
    if (response.status !== 200 || !data.token) throw new Error(`Login ${role}: HTTP ${response.status}`);
    results.push({ name: `Login ${role}`, pass: true, status: response.status });
    for (const state of ['pendiente', 'enviado', 'recibido', 'cancelado']) {
      await check(`${role}: pedidos ${state}`, `/api/reportes/pedidos?estado=${state}`,
        (status, data) => status === 200 && Array.isArray(data?.pedidos) && data.estado === state, data.token);
    }
    if (role === 'admin') {
      for (const route of ['/api/productos/no-es-numero', '/api/movimientos?limit=-1',
        '/api/movimientos?desde=no-es-fecha', '/api/reportes/gastos?desde=no-es-fecha',
        '/api/reportes/gastos?desde=2026-11-06&hasta=2026-11-01']) {
        await check(`Validación: ${route}`, route,
          (status, data) => status === 400 && typeof data?.error === 'string' && !/postgres|syntax|integer/i.test(data.error), data.token);
      }
    }
  }
  const report = { timestamp: new Date().toISOString(), base, passed: results.filter(r => r.pass).length, failed: results.filter(r => !r.pass).length, results };
  fs.writeFileSync(path.join(__dirname, 'deployment-verification.json'), JSON.stringify(report, null, 2));
  if (report.failed) throw new Error(`${report.failed} comprobaciones fallaron`);
  const statePath = path.join(__dirname, 'deployment-state.json');
  const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  state.status = 'verified';
  state.verifiedAt = report.timestamp;
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  console.log(`Verificación completada: ${report.passed} comprobaciones aprobadas.`);
}
main().catch(err => { console.error(err.message); process.exitCode = 1; });
