/**
 * dashboard.js — Tarjetas de resumen y tabla de faltantes en el inicio.
 */
const Dashboard = (() => {

  async function cargar() {
    // Mostrar skeleton en tarjetas
    ['num-productos','num-faltantes','num-movimientos','num-pedidos'].forEach(id => {
      const el = document.getElementById(id);
      if (el) { el.textContent = '…'; el.style.opacity = '.4'; }
    });

    try {
      const [productos, faltantes, corte, pedidos] = await Promise.all([
        api.get('/productos'),
        api.get('/reportes/faltantes'),
        api.get('/reportes/corte-diario'),
        api.get('/reportes/pedidos')
      ]);

      const set = (id, val) => {
        const el = document.getElementById(id);
        if (el) { el.textContent = val; el.style.opacity = '1'; }
      };

      set('num-productos',   productos.length);
      set('num-faltantes',   faltantes.total);
      set('num-movimientos', corte.resumen.total_movimientos || 0);
      set('num-pedidos',     pedidos.total);

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
                  <td><span class="td-code">${p.codigo}</span></td>
                  <td>${p.nombre}</td>
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
      ['num-productos','num-faltantes','num-movimientos','num-pedidos'].forEach(id => {
        const el = document.getElementById(id);
        if (el) { el.textContent = '?'; el.style.opacity = '1'; }
      });
    }
  }

  return { cargar };
})();
