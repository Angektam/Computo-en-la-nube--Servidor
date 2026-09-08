/**
 * categorias.js — CRUD de categorías de productos.
 */
const Categorias = (() => {
  let todas = [];

  function renderTabla(lista) {
    const c = document.getElementById('tabla-categorias');
    if (!lista.length) {
      c.innerHTML = `
        <div class="empty-state" style="padding:2.5rem">
          <div class="empty-icon">🏷</div>
          <p>No hay categorías. Crea la primera para organizar tus productos.</p>
        </div>`;
      return;
    }

    c.innerHTML = `
      <div class="tabla-wrap">
        <table>
          <thead><tr>
            <th>ID</th><th>Nombre</th><th>Descripción</th>
            <th style="text-align:center">Productos</th>
            <th style="text-align:center">Acciones</th>
          </tr></thead>
          <tbody>
            ${lista.map(cat => `
              <tr>
                <td style="color:var(--texto-sec)">${cat.id}</td>
                <td><strong>${cat.nombre}</strong></td>
                <td style="color:var(--texto-sec)">${cat.descripcion || '<span style="color:var(--gris)">—</span>'}</td>
                <td style="text-align:center">
                  <span class="badge-info">${cat.total_productos}</span>
                </td>
                <td>
                  <div style="display:flex;gap:.4rem;justify-content:center">
                    <button class="btn-icon edit" title="Editar" onclick="Categorias.editar(${cat.id})">✏️</button>
                    <button class="btn-danger btn-sm" title="Eliminar" onclick="Categorias.eliminar(${cat.id},'${cat.nombre.replace(/'/g,"\\'")}')">🗑</button>
                  </div>
                </td>
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
  }

  async function cargar() {
    const c = document.getElementById('tabla-categorias');
    if (!c) return;
    c.innerHTML = `<div class="empty-state"><div class="empty-icon"><span class="spinner" style="width:1.5rem;height:1.5rem;border-color:rgba(0,0,0,.15);border-top-color:var(--rojo);display:inline-block"></span></div><p>Cargando…</p></div>`;
    try {
      todas = await api.get('/categorias');
      renderTabla(todas);
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p>${err.message}</p></div>`;
    }
  }

  function formHTML(cat = {}) {
    return `
      <div class="form-modal">
        <label>
          <span class="form-label">Nombre *</span>
          <input id="cat-nombre" value="${cat.nombre || ''}" required placeholder="Ej. Electrónicos, Ropa, Alimentos…" />
        </label>
        <label>
          <span class="form-label">Descripción</span>
          <textarea id="cat-desc" rows="2" placeholder="Descripción opcional">${cat.descripcion || ''}</textarea>
        </label>
        <div class="form-actions">
          <button class="btn-secondary" type="button" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-primary" id="btn-guardar-cat" type="button">
            ${cat.id ? '💾 Guardar cambios' : '✚ Crear categoría'}
          </button>
        </div>
        <p id="cat-error" class="error-msg hidden"></p>
      </div>`;
  }

  function nueva() {
    Modal.abrir(formHTML(), '🏷 Nueva categoría');
    document.getElementById('btn-guardar-cat').onclick = async (e) => {
      const btn   = e.currentTarget;
      const errEl = document.getElementById('cat-error');
      errEl.classList.add('hidden');
      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Guardando…';
      try {
        await api.post('/categorias', {
          nombre:      document.getElementById('cat-nombre').value.trim(),
          descripcion: document.getElementById('cat-desc').value.trim(),
        });
        Modal.cerrar();
        Toast.success('Categoría creada');
        cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btn.disabled = false;
        btn.innerHTML = '✚ Crear categoría';
      }
    };
  }

  function editar(id) {
    const cat = todas.find(x => x.id === id);
    if (!cat) return;
    Modal.abrir(formHTML(cat), '✏️ Editar categoría');
    document.getElementById('btn-guardar-cat').onclick = async (e) => {
      const btn   = e.currentTarget;
      const errEl = document.getElementById('cat-error');
      errEl.classList.add('hidden');
      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Guardando…';
      try {
        await api.put(`/categorias/${id}`, {
          nombre:      document.getElementById('cat-nombre').value.trim(),
          descripcion: document.getElementById('cat-desc').value.trim(),
        });
        Modal.cerrar();
        Toast.success('Categoría actualizada');
        cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btn.disabled = false;
        btn.innerHTML = '💾 Guardar cambios';
      }
    };
  }

  function eliminar(id, nombre) {
    Modal.abrir(`
      <div class="confirm-dialog">
        <div class="confirm-icon">🗑️</div>
        <p>¿Eliminar la categoría <strong>"${nombre}"</strong>?<br>
        Solo se puede eliminar si no tiene productos asignados.</p>
        <div class="confirm-actions">
          <button class="btn-secondary" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-danger" id="btn-confirm-del-cat">Sí, eliminar</button>
        </div>
      </div>`, '⚠️ Confirmar eliminación');

    document.getElementById('btn-confirm-del-cat').onclick = async () => {
      try {
        await api.delete(`/categorias/${id}`);
        Modal.cerrar();
        Toast.success('Categoría eliminada');
        cargar();
      } catch (err) {
        Toast.error(err.message);
        Modal.cerrar();
      }
    };
  }

  function getTodas() { return todas; }

  return { cargar, nueva, editar, eliminar, getTodas };
})();
