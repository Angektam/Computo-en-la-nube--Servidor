/**
 * movimientos.js — Listado con filtros, paginación y exportación CSV.
 */
const Movimientos = (() => {
  let paginaActual = 1;
  const LIMIT = 50;

  const tipoBadge = {
    entrada: `<span class="badge-ok">🟢 Entrada</span>`,
    salida:  `<span class="badge-alerta">🔴 Salida</span>`,
    ajuste:  `<span class="badge-warning">🟡 Ajuste</span>`,
  };

  function getFiltros() {
    return {
      tipo:  document.getElementById('filtro-tipo-mov')?.value || '',
      desde: document.getElementById('filtro-desde-mov')?.value || '',
      hasta: document.getElementById('filtro-hasta-mov')?.value || '',
    };
  }

  function buildQuery(page = 1) {
    const f = getFiltros();
    const params = new URLSearchParams({ page, limit: LIMIT });
    if (f.tipo)  params.set('tipo', f.tipo);
    if (f.desde) params.set('desde', f.desde);
    if (f.hasta) params.set('hasta', f.hasta);
    return params.toString();
  }

  function renderPaginacion(total, paginas, actual) {
    const c = document.getElementById('paginacion-mov');
    if (!c || paginas <= 1) { if (c) c.innerHTML = ''; return; }

    const inicio = (actual - 1) * LIMIT + 1;
    const fin    = Math.min(actual * LIMIT, total);

    let html = `<span class="pag-info">${inicio}–${fin} de ${total}</span>`;
    html += `<button ${actual === 1 ? 'disabled' : ''} onclick="Movimientos.irPagina(${actual - 1})">‹</button>`;

    // Botones de páginas (máx 7 visibles)
    const rango = 3;
    for (let i = 1; i <= paginas; i++) {
      if (i === 1 || i === paginas || (i >= actual - rango && i <= actual + rango)) {
        html += `<button class="${i === actual ? 'active' : ''}" onclick="Movimientos.irPagina(${i})">${i}</button>`;
      } else if (i === actual - rango - 1 || i === actual + rango + 1) {
        html += `<span style="padding:0 .25rem;color:var(--gris)">…</span>`;
      }
    }

    html += `<button ${actual === paginas ? 'disabled' : ''} onclick="Movimientos.irPagina(${actual + 1})">›</button>`;
    c.innerHTML = html;
  }

  function renderTabla(datos) {
    const c = document.getElementById('tabla-movimientos');
    if (!datos.length) {
      c.innerHTML = `<div class="empty-state" style="padding:2.5rem"><div class="empty-icon">↕️</div><p>Sin movimientos para los filtros seleccionados.</p></div>`;
      return;
    }

    c.innerHTML = `
      <div class="tabla-wrap">
        <table>
          <thead><tr>
            <th>Fecha</th><th>Tipo</th><th>Producto</th>
            <th>Cantidad</th><th>Stock antes</th><th>Stock después</th>
            <th>Usuario</th><th>Motivo</th>
          </tr></thead>
          <tbody>
            ${datos.map(m => `
              <tr>
                <td style="white-space:nowrap;color:var(--texto-sec)">${new Date(m.fecha).toLocaleString('es-MX',{dateStyle:'short',timeStyle:'short'})}</td>
                <td>${tipoBadge[m.tipo] || m.tipo}</td>
                <td><span class="td-code">${m.codigo}</span> ${m.producto}</td>
                <td><strong style="font-size:1rem">${m.cantidad}</strong></td>
                <td style="color:var(--texto-sec)">${m.stock_antes}</td>
                <td><strong>${m.stock_despues}</strong></td>
                <td style="color:var(--texto-sec)">${m.usuario}</td>
                <td style="color:var(--texto-sec)">${m.motivo || '<span style="color:var(--gris)">—</span>'}</td>
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
  }

  async function cargar(page = 1) {
    paginaActual = page;
    const c = document.getElementById('tabla-movimientos');
    if (!c) return;
    mostrarCargando('tabla-movimientos');
    try {
      const resp = await api.get(`/movimientos?${buildQuery(page)}`);
      // Soporte respuesta paginada { datos, total, paginas } o array simple (retrocompat.)
      const datos  = Array.isArray(resp) ? resp : resp.datos;
      const total  = Array.isArray(resp) ? resp.length : resp.total;
      const paginas = Array.isArray(resp) ? 1 : resp.paginas;

      renderTabla(datos);
      renderPaginacion(total, paginas, page);
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p>${err.message}</p></div>`;
      Toast.error('Error al cargar movimientos: ' + err.message);
    }
  }

  function irPagina(p) { cargar(p); }

  function exportarCSV() {
    const f     = getFiltros();
    const params = new URLSearchParams();
    if (f.tipo)  params.set('tipo', f.tipo);
    if (f.desde) params.set('desde', f.desde);
    if (f.hasta) params.set('hasta', f.hasta);
    const token = localStorage.getItem('token');
    // Descarga directa via link temporal con header de auth no es posible
    // Usamos fetch + blob
    const url = `/api/reportes/export/movimientos?${params.toString()}`;
    fetch(url, { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.blob())
      .then(blob => {
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = `movimientos-${new Date().toISOString().slice(0,10)}.csv`;
        a.click();
        URL.revokeObjectURL(a.href);
        Toast.success('CSV descargado');
      })
      .catch(() => Toast.error('Error al exportar'));
  }

  // ── Event listeners de filtros ─────────────────────────────
  document.getElementById('btn-filtrar-mov')?.addEventListener('click', () => cargar(1));
  document.getElementById('btn-limpiar-mov')?.addEventListener('click', () => {
    document.getElementById('filtro-tipo-mov').value  = '';
    document.getElementById('filtro-desde-mov').value = '';
    document.getElementById('filtro-hasta-mov').value = '';
    cargar(1);
  });
  document.getElementById('btn-export-mov')?.addEventListener('click', exportarCSV);

  // ── Formulario nuevo movimiento ────────────────────────────
  function formHTML(productos) {
    return `
      <div class="form-modal">
        <label>
          <span class="form-label">Producto *</span>
          <select id="m-producto">
            <option value="">— Seleccionar producto —</option>
            ${productos.map(p =>
              `<option value="${p.id}">${p.codigo} — ${p.nombre} (stock: ${p.stock_actual} ${p.unidad || 'pzs'})</option>`
            ).join('')}
          </select>
        </label>
        <label>
          <span class="form-label">Tipo de movimiento *</span>
          <select id="m-tipo">
            <option value="entrada">🟢 Entrada — Añadir al stock</option>
            <option value="salida">🔴 Salida — Restar del stock</option>
            <option value="ajuste">🟡 Ajuste — Establecer nuevo total</option>
          </select>
        </label>
        <label>
          <span class="form-label">Cantidad *</span>
          <input id="m-cantidad" type="number" min="1" value="1" required />
        </label>
        <label>
          <span class="form-label">Motivo</span>
          <input id="m-motivo" placeholder="Ej. Compra proveedor, venta cliente #42…" />
        </label>
        <div class="form-actions">
          <button class="btn-secondary" type="button" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-primary" id="btn-guardar-mov" type="button">✔ Registrar movimiento</button>
        </div>
        <p id="mov-error" class="error-msg hidden"></p>
      </div>`;
  }

  async function nuevo() {
    const productos = Productos.getTodos();
    Modal.abrir(formHTML(productos), '↕️ Registrar movimiento');

    document.getElementById('btn-guardar-mov').onclick = async (e) => {
      const btn    = e.currentTarget;
      const errEl  = document.getElementById('mov-error');
      errEl.classList.add('hidden');

      const producto_id = parseInt(document.getElementById('m-producto').value);
      const tipo        = document.getElementById('m-tipo').value;
      const cantidad    = parseInt(document.getElementById('m-cantidad').value);
      const motivo      = document.getElementById('m-motivo').value.trim();

      if (!producto_id) {
        errEl.textContent = 'Selecciona un producto';
        errEl.classList.remove('hidden'); return;
      }
      if (!cantidad || cantidad < 1) {
        errEl.textContent = 'La cantidad debe ser mayor a 0';
        errEl.classList.remove('hidden'); return;
      }

      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Registrando…';

      try {
        await api.post('/movimientos', { producto_id, tipo, cantidad, motivo });
        Modal.cerrar();
        Toast.success('Movimiento registrado correctamente');
        cargar(1);
        Productos.cargar();
        Dashboard.cargar();
        Pedidos.cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btn.disabled = false;
        btn.innerHTML = '✔ Registrar movimiento';
      }
    };
  }

  return { cargar, irPagina, nuevo, exportarCSV };
})();
