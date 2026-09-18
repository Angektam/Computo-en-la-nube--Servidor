/**
 * reportes.js — Faltantes, sobrantes, gastos acumulados y corte diario.
 */
const Reportes = (() => {

  const fmt = v => `$${Number(v || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}`;

  function cargando(id) {
    mostrarCargando(id);
  }

  function exportarFaltantes() {
    const token = localStorage.getItem('token');
    fetch('/api/reportes/export/faltantes', { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.blob())
      .then(blob => {
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = `faltantes-${new Date().toISOString().slice(0,10)}.csv`;
        a.click();
        URL.revokeObjectURL(a.href);
        Toast.success('CSV descargado');
      })
      .catch(() => Toast.error('Error al exportar'));
  }

  // ── Faltantes ──────────────────────────────────────────────
  async function cargarFaltantes() {
    cargando('reporte-faltantes');
    const c = document.getElementById('reporte-faltantes');
    try {
      const { total, productos } = await api.get('/reportes/faltantes');
      if (!total) {
        c.innerHTML = `
          <div class="empty-state" style="padding:2.5rem 1rem">
            <div class="empty-icon">✅</div>
            <p class="status-ok">Todos los productos están sobre el mínimo.</p>
          </div>`;
        return;
      }
      c.innerHTML = `
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:.9rem;flex-wrap:wrap;gap:.5rem">
          <span class="badge-alerta">⚠ ${total} productos bajo el mínimo</span>
          <button class="btn-secondary btn-sm" onclick="Reportes.exportarFaltantes()">⬇ Exportar CSV</button>
        </div>
        <div class="seccion">
          <div class="tabla-wrap">
            <table>
              <thead><tr>
                <th>Código</th><th>Nombre</th><th>Categoría</th>
                <th>Stock actual</th><th>Mínimo</th><th>Faltante</th>
              </tr></thead>
              <tbody>
                ${productos.map(p => `
                  <tr>
                    <td><span class="td-code">${p.codigo}</span></td>
                    <td>${p.nombre}</td>
                    <td style="color:var(--texto-sec)">${p.categoria || '—'}</td>
                    <td><span class="badge-alerta">${p.stock_actual}</span></td>
                    <td style="color:var(--texto-sec)">${p.stock_minimo}</td>
                    <td><strong class="status-alerta">−${p.faltante}</strong></td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
        </div>`;
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p class="status-alerta">${err.message}</p></div>`;
    }
  }

  // ── Sobrantes ──────────────────────────────────────────────
  async function cargarSobrantes() {
    cargando('reporte-sobrantes');
    const c = document.getElementById('reporte-sobrantes');
    try {
      const { total, productos, factor } = await api.get('/reportes/sobrantes');
      if (!total) {
        c.innerHTML = `
          <div class="empty-state" style="padding:2.5rem 1rem">
            <div class="empty-icon">📦</div>
            <p>Sin productos con exceso de stock (factor ×${factor}).</p>
          </div>`;
        return;
      }
      c.innerHTML = `
        <p style="margin-bottom:.9rem;font-size:.9rem">
          <span class="badge-info">📈 ${total} productos con exceso (factor ×${factor})</span>
        </p>
        <div class="seccion">
          <div class="tabla-wrap">
            <table>
              <thead><tr>
                <th>Código</th><th>Nombre</th><th>Categoría</th>
                <th>Stock actual</th><th>Mínimo</th><th>Sobrante</th>
              </tr></thead>
              <tbody>
                ${productos.map(p => `
                  <tr>
                    <td><span class="td-code">${p.codigo}</span></td>
                    <td>${p.nombre}</td>
                    <td style="color:var(--texto-sec)">${p.categoria || '—'}</td>
                    <td>${p.stock_actual}</td>
                    <td style="color:var(--texto-sec)">${p.stock_minimo}</td>
                    <td><strong class="status-ok">+${p.sobrante}</strong></td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
        </div>`;
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p class="status-alerta">${err.message}</p></div>`;
    }
  }

  // ── Gastos acumulados ──────────────────────────────────────
  async function cargarGastos() {
    const desde = document.getElementById('gastos-desde').value;
    const hasta = document.getElementById('gastos-hasta').value;
    const c     = document.getElementById('reporte-gastos');
    const btn   = document.getElementById('btn-gastos');

    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Consultando…';
    cargando('reporte-gastos');

    try {
      const url = `/reportes/gastos${desde ? `?desde=${desde}&hasta=${hasta}` : ''}`;
      const { totales, por_dia, top_productos, desde: d, hasta: h } = await api.get(url);

      c.innerHTML = `
        <p style="color:var(--texto-sec);font-size:.8rem;margin-bottom:1rem">
          📅 Período: <strong>${d}</strong> → <strong>${h}</strong>
        </p>

        <div class="resumen-gastos">
          <div class="tarjeta">
            <div class="tarjeta-icon red">💸</div>
            <div class="tarjeta-info">
              <span class="tarjeta-num" style="font-size:1.2rem">${fmt(totales.total_salidas)}</span>
              <span class="tarjeta-label">Total salidas</span>
            </div>
          </div>
          <div class="tarjeta">
            <div class="tarjeta-icon green">📦</div>
            <div class="tarjeta-info">
              <span class="tarjeta-num" style="font-size:1.2rem">${fmt(totales.total_entradas)}</span>
              <span class="tarjeta-label">Total entradas</span>
            </div>
          </div>
          <div class="tarjeta">
            <div class="tarjeta-icon blue">🔄</div>
            <div class="tarjeta-info">
              <span class="tarjeta-num" style="font-size:1.2rem">${totales.total_movimientos || 0}</span>
              <span class="tarjeta-label">Movimientos</span>
            </div>
          </div>
        </div>

        <div class="seccion" style="margin-bottom:1.25rem">
          <div class="seccion-header"><h3>🏆 Top 5 productos</h3></div>
          <div class="tabla-wrap">
            <table>
              <thead><tr>
                <th>#</th><th>Producto</th>
                <th>Unidades vendidas</th><th>Valor acumulado</th>
              </tr></thead>
              <tbody>
                ${top_productos.map((p, i) => `
                  <tr>
                    <td><strong>#${i + 1}</strong></td>
                    <td><span class="td-code">${p.codigo}</span> ${p.nombre}</td>
                    <td>${p.unidades_vendidas}</td>
                    <td><strong>${fmt(p.valor_acumulado)}</strong></td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <div class="seccion">
          <div class="seccion-header"><h3>📅 Desglose por día</h3></div>
          <div class="tabla-wrap">
            <table>
              <thead><tr>
                <th>Día</th><th>Movimientos</th>
                <th>Valor salidas</th><th>Valor entradas</th>
              </tr></thead>
              <tbody>
                ${por_dia.map(d => `
                  <tr>
                    <td style="color:var(--texto-sec)">${d.dia}</td>
                    <td>${d.movimientos}</td>
                    <td class="status-alerta">${fmt(d.valor_salidas)}</td>
                    <td class="status-ok">${fmt(d.valor_entradas)}</td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>
        </div>`;
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p class="status-alerta">${err.message}</p></div>`;
      Toast.error('Error al cargar gastos: ' + err.message);
    } finally {
      btn.disabled = false;
      btn.innerHTML = '🔍 Consultar';
    }
  }

  // ── Corte diario ───────────────────────────────────────────
  async function cargarCorte() {
    const fecha = document.getElementById('corte-fecha').value;
    const c     = document.getElementById('reporte-corte');
    const btn   = document.getElementById('btn-corte');

    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Consultando…';
    cargando('reporte-corte');

    try {
      const url = `/reportes/corte-diario${fecha ? `?fecha=${fecha}` : ''}`;
      const { fecha: f, resumen, alertas } = await api.get(url);

      c.innerHTML = `
        <p style="color:var(--texto-sec);font-size:.8rem;margin-bottom:1rem">
          📋 Corte del día: <strong>${f}</strong>
        </p>
        <div class="corte-grid">
          <div class="corte-card">
            <div class="num">${resumen.total_movimientos || 0}</div>
            <small>Movimientos</small>
          </div>
          <div class="corte-card">
            <div class="num" style="color:var(--ok)">${resumen.entradas || 0}</div>
            <small>Entradas</small>
          </div>
          <div class="corte-card">
            <div class="num" style="color:var(--alerta)">${resumen.salidas || 0}</div>
            <small>Salidas</small>
          </div>
          <div class="corte-card">
            <div class="num" style="font-size:1.3rem;color:var(--rojo)">${fmt(resumen.valor_salidas)}</div>
            <small>Valor salidas</small>
          </div>
          <div class="corte-card">
            <div class="num" style="color:var(--warning)">${alertas.productos_bajo_minimo}</div>
            <small>Bajo mínimo</small>
          </div>
          <div class="corte-card">
            <div class="num" style="color:var(--ok)">${alertas.pedidos_generados}</div>
            <small>Pedidos generados</small>
          </div>
        </div>`;
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p class="status-alerta">${err.message}</p></div>`;
      Toast.error('Error al cargar corte diario: ' + err.message);
    } finally {
      btn.disabled = false;
      btn.innerHTML = '🔍 Consultar';
    }
  }

  // ── Tabs de reportes ───────────────────────────────────────
  document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(t => t.classList.add('hidden'));
      btn.classList.add('active');
      document.getElementById(`tab-${btn.dataset.tab}`).classList.remove('hidden');
      if (btn.dataset.tab === 'faltantes') cargarFaltantes();
      if (btn.dataset.tab === 'sobrantes') cargarSobrantes();
    });
  });

  // Fechas por defecto
  const hoy    = new Date().toISOString().slice(0, 10);
  const hace30 = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  document.getElementById('gastos-desde').value = hace30;
  document.getElementById('gastos-hasta').value = hoy;
  document.getElementById('corte-fecha').value  = hoy;

  document.getElementById('btn-gastos').addEventListener('click', cargarGastos);
  document.getElementById('btn-corte').addEventListener('click', cargarCorte);

  function cargar() { cargarFaltantes(); }

  return { cargar, exportarFaltantes };
})();
