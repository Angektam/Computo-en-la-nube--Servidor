/**
 * dashboard.js — Tarjetas de resumen y tabla de faltantes en el inicio.
 */
const Dashboard = (() => {

  async function cargar() {
    const puedeVerResumen = Auth.tieneRol('administrador', 'bodega');
    ['num-movimientos', 'num-pedidos'].forEach(id => {
      document.getElementById(id)?.closest('.tarjeta')?.classList.toggle('hidden', !puedeVerResumen);
    });
    // Mostrar skeleton en tarjetas
    ['num-productos','num-faltantes','num-movimientos','num-pedidos','valor-inventario'].forEach(id => {
      const el = document.getElementById(id);
      if (el) { el.textContent = '…'; el.style.opacity = '.4'; }
    });

    try {
      const hoy = new Date().toISOString().slice(0, 10);
      const [productos, faltantes, corte, pedidos, actividad] = await Promise.all([
        api.get('/productos'),
        api.get('/reportes/faltantes'),
        puedeVerResumen ? api.get('/reportes/corte-diario') : Promise.resolve(null),
        puedeVerResumen ? api.get('/reportes/pedidos') : Promise.resolve(null),
        puedeVerResumen ? api.get(`/reportes/movimientos?desde=${hoy}&hasta=${hoy}`) : Promise.resolve(null)
      ]);

      const set = (id, val) => {
        const el = document.getElementById(id);
        if (el) { el.textContent = val; el.style.opacity = '1'; }
      };

      set('num-productos',   productos.length);
      set('num-faltantes',   faltantes.total);
      const valorInventario = productos.reduce((total, producto) =>
        total + Number(producto.stock_actual || 0) * Number(producto.precio || 0), 0);
      set('valor-inventario', valorInventario.toLocaleString('es-MX', {
        style: 'currency', currency: 'MXN', maximumFractionDigits: 0
      }));
      if (puedeVerResumen) {
        set('num-movimientos', corte.resumen.total_movimientos || 0);
        set('num-pedidos', pedidos.total);
        const badge = document.getElementById('nav-badge-pedidos');
        if (badge) {
          badge.textContent = pedidos.total;
          badge.classList.toggle('visible', pedidos.total > 0);
        }
      }

      // Mejora #11: mostrar hora de última actualización
      const tsEl = document.getElementById('dashboard-actualizado');
      if (tsEl) {
        tsEl.textContent = `Actualizado: ${new Date().toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}`;
      }

      const estado = document.getElementById('dashboard-estado');
      const saludo = document.getElementById('dashboard-saludo');
      if (estado && saludo) {
        const problemas = faltantes.total + (pedidos?.total || 0);
        estado.textContent = problemas ? `● ${problemas} asunto${problemas === 1 ? '' : 's'} por revisar` : '● Sistema listo';
        estado.className = `dashboard-status ${problemas ? 'status-warning' : 'status-ok'}`;
        saludo.textContent = problemas ? 'Prioriza las alertas del inventario' : 'Todo bajo control';
      }

      const actividadEl = document.getElementById('dashboard-actividad');
      if (actividadEl) {
        const rows = actividad?.productos || [];
        actividadEl.innerHTML = rows.length ? `<div class="actividad-list">${rows.slice(0, 5).map(p => `
          <div class="actividad-item"><span class="actividad-dot"></span><div><strong>${escaparHtml(p.nombre)}</strong><small>${escaparHtml(p.codigo)} · ${Number(p.total_entradas || 0)} entradas · ${Number(p.total_salidas || 0)} salidas</small></div></div>`).join('')}</div>` : '<div class="empty-state compact-empty"><div class="empty-icon">🕘</div><p>No hay movimientos registrados hoy.</p></div>';
      }

      const recomendacion = document.getElementById('dashboard-recomendacion');
      if (recomendacion) {
        recomendacion.innerHTML = faltantes.total
          ? `<div class="recomendacion-icon">💡</div><div><strong>Recomendación</strong><p>Hay ${faltantes.total} producto${faltantes.total === 1 ? '' : 's'} bajo mínimo. Genera pedidos automáticos para evitar quiebres de stock.</p></div><button class="btn-primary btn-sm bodega-only hidden" onclick="Nav.ir('pedidos')">Atender ahora</button>`
          : `<div class="recomendacion-icon">✅</div><div><strong>Inventario saludable</strong><p>No se detectaron productos bajo mínimo. Mantén el ritmo revisando los movimientos del día.</p></div>`;
        const botonRecomendacion = recomendacion.querySelector?.('.bodega-only');
        if (botonRecomendacion) botonRecomendacion.classList.toggle('hidden', !puedeVerResumen);
      }

      // Actualizar color tarjeta faltantes
      const cardFaltantes = document.getElementById('card-faltantes');
      if (cardFaltantes) {
        cardFaltantes.classList.toggle('alerta', faltantes.total > 0);
      }

      // Tabla de faltantes en dashboard
      const c = document.getElementById('tabla-faltantes-dash');
      if (!faltantes.total) {
        c.innerHTML = `
          <div class="empty-state" style="padding:2rem 1rem">
            <div class="empty-icon">✅</div>
            <p class="status-ok">Todos los productos están sobre el mínimo.</p>
          </div>`;
        return;
      }

      c.innerHTML = `
        <div class="tabla-wrap">
          <table>
            <thead><tr>
              <th>Código</th>
              <th>Nombre</th>
              <th>Stock actual</th>
              <th>Mínimo</th>
              <th>Faltante</th>
            </tr></thead>
            <tbody>
              ${faltantes.productos.slice(0, 8).map(p => `
                <tr>
                  <td><span class="td-code">${escaparHtml(p.codigo)}</span></td>
                  <td>${escaparHtml(p.nombre)}</td>
                  <td><span class="badge-alerta">${p.stock_actual}</span></td>
                  <td style="color:var(--texto-sec)">${p.stock_minimo}</td>
                  <td><strong class="status-alerta">−${p.faltante}</strong></td>
                </tr>`).join('')}
            </tbody>
          </table>
        </div>
        ${faltantes.total > 8 ? `<p style="padding:.75rem 1rem;font-size:.8rem;color:var(--texto-sec)">… y ${faltantes.total - 8} más. Ve a <strong>Reportes → Faltantes</strong> para ver todos.</p>` : ''}`;

    } catch (err) {
      console.error('Dashboard error:', err.message);
      ['num-productos','num-faltantes','num-movimientos','num-pedidos','valor-inventario'].forEach(id => {
        const el = document.getElementById(id);
        if (el) { el.textContent = '?'; el.style.opacity = '1'; }
      });
    }
  }

  return { cargar };
})();
