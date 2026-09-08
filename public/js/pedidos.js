/**
 * pedidos.js — Vista y gestión de pedidos automáticos.
 */
const Pedidos = (() => {

  const estadoBadge = {
    pendiente: `<span class="badge-pendiente">⏳ Pendiente</span>`,
    enviado:   `<span class="badge-enviado">📤 Enviado</span>`,
    recibido:  `<span class="badge-recibido">✅ Recibido</span>`,
    cancelado: `<span class="badge-cancelado">❌ Cancelado</span>`,
  };

  // Transiciones válidas por estado
  const siguienteEstado = {
    pendiente: [{ val: 'enviado', label: '📤 Marcar enviado' }, { val: 'cancelado', label: '❌ Cancelar' }],
    enviado:   [{ val: 'recibido', label: '✅ Marcar recibido' }, { val: 'cancelado', label: '❌ Cancelar' }],
    recibido:  [],
    cancelado: [],
  };

  function renderTabla(pedidos) {
    const c = document.getElementById('tabla-pedidos');
    if (!pedidos.length) {
      c.innerHTML = `
        <div class="empty-state" style="padding:3rem">
          <div class="empty-icon">🛒</div>
          <p>No hay pedidos pendientes. ¡El inventario está en orden!</p>
        </div>`;
      return;
    }

    const puedeGestionar = Auth.tieneRol('administrador', 'bodega');

    c.innerHTML = `
      <div class="tabla-wrap">
        <table>
          <thead><tr>
            <th>ID</th><th>Producto</th><th>Stock actual</th>
            <th>Mínimo</th><th>Cant. sugerida</th><th>Estado</th>
            <th>Generado</th>${puedeGestionar ? '<th style="text-align:center">Acciones</th>' : ''}
          </tr></thead>
          <tbody>
            ${pedidos.map(p => `
              <tr>
                <td style="color:var(--texto-sec)">#${p.id}</td>
                <td>
                  <span class="td-code">${p.codigo}</span>
                  <span style="margin-left:.4rem">${p.producto}</span>
                </td>
                <td><span class="badge-alerta">${p.stock_actual}</span></td>
                <td style="color:var(--texto-sec)">${p.stock_minimo}</td>
                <td><strong>${p.cantidad_sugerida}</strong></td>
                <td>${estadoBadge[p.estado] || p.estado}</td>
                <td style="color:var(--texto-sec);white-space:nowrap">${new Date(p.generado_en).toLocaleString('es-MX', {dateStyle:'short',timeStyle:'short'})}</td>
                ${puedeGestionar ? `
                <td style="text-align:center">
                  <div style="display:flex;gap:.35rem;justify-content:center">
                    ${(siguienteEstado[p.estado] || []).map(s =>
                      `<button class="btn-primary btn-sm" onclick="Pedidos.cambiarEstado(${p.id},'${s.val}')">${s.label}</button>`
                    ).join('')}
                  </div>
                </td>` : ''}
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
  }

  async function cargar() {
    const c = document.getElementById('tabla-pedidos');
    if (!c) return;
    c.innerHTML = `<div class="empty-state"><div class="empty-icon"><span class="spinner" style="width:1.5rem;height:1.5rem;border-color:rgba(0,0,0,.15);border-top-color:var(--rojo);display:inline-block"></span></div><p>Cargando pedidos…</p></div>`;
    try {
      const { total, pedidos } = await api.get('/reportes/pedidos');
      renderTabla(pedidos);

      // Actualizar badge en sidebar
      const badge = document.getElementById('nav-badge-pedidos');
      if (badge) {
        badge.textContent = total;
        badge.classList.toggle('visible', total > 0);
      }
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p>${err.message}</p></div>`;
    }
  }

  async function cambiarEstado(id, nuevoEstado) {
    try {
      await api.patch(`/reportes/pedidos/${id}`, { estado: nuevoEstado });
      Toast.success(`Pedido marcado como "${nuevoEstado}"`);
      cargar();
      Dashboard.cargar();
    } catch (err) {
      Toast.error(err.message);
    }
  }

  return { cargar, cambiarEstado };
})();
