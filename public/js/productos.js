/**
 * productos.js — Listado en cards con imagen, búsqueda, alta, edición y baja.
 */
const Productos = (() => {
  let todos = [];
  let vistaActual = 'cards'; // 'cards' | 'tabla'

  // ── Render Cards ────────────────────────────────────────────
  function renderCards(lista) {
    const c = document.getElementById('tabla-productos');
    if (!lista.length) {
      c.innerHTML = `<div class="empty-state" style="padding:3rem"><div class="empty-icon">🗂</div><p>No se encontraron productos.</p></div>`;
      return;
    }
    const puedeEditar  = Auth.tieneRol('administrador','bodega');
    const puedeEliminar = Auth.tieneRol('administrador');

    c.innerHTML = `<div class="productos-grid">${lista.map(p => `
      <div class="producto-card" onclick="Productos.verDetalle(${p.id})">
        <div class="producto-img">
          ${p.imagen_url
            ? `<img src="${p.imagen_url}" alt="${p.nombre}" loading="lazy" onerror="this.parentElement.innerHTML='<span class=\\'img-placeholder\\'>📦</span>'" />`
            : `<span class="img-placeholder">📦</span>`}
          ${p.stock_actual <= 0
            ? `<span class="img-badge red">Sin stock</span>`
            : p.stock_actual < p.stock_minimo
              ? `<span class="img-badge orange">⚠ Bajo</span>`
              : ''}
        </div>
        <div class="producto-card-body">
          <div class="producto-card-code">${p.codigo}</div>
          <div class="producto-card-name">${p.nombre}</div>
          ${p.categoria ? `<div class="producto-card-cat">${p.categoria}</div>` : ''}
          <div class="producto-card-footer">
            <span class="producto-card-price">$${Number(p.precio).toFixed(2)}</span>
            <span class="producto-card-stock ${p.stock_actual < p.stock_minimo ? 'low' : ''}">
              ${p.stock_actual} ${p.unidad || 'pzs'}
            </span>
          </div>
          ${(puedeEditar || puedeEliminar) ? `
          <div class="producto-card-actions" onclick="event.stopPropagation()">
            ${puedeEditar ? `<button class="btn-primary btn-sm" onclick="Productos.editar(${p.id})">✏️ Editar</button>` : ''}
            ${puedeEditar ? `<button class="btn-secondary btn-sm" onclick="Productos.subirImagen(${p.id},'${p.nombre.replace(/'/g,"\\'")}')">🖼 Imagen</button>` : ''}
            ${puedeEliminar ? `<button class="btn-danger btn-sm" onclick="Productos.eliminar(${p.id},'${p.nombre.replace(/'/g,"\\'")}')">🗑</button>` : ''}
          </div>` : ''}
        </div>
      </div>`).join('')}</div>`;
  }

  // ── Render Tabla ────────────────────────────────────────────
  function renderTabla(lista) {
    const c = document.getElementById('tabla-productos');
    if (!lista.length) {
      c.innerHTML = `<div class="empty-state" style="padding:2.5rem"><div class="empty-icon">🗂</div><p>No se encontraron productos.</p></div>`;
      return;
    }
    const puedeEditar   = Auth.tieneRol('administrador','bodega');
    const puedeEliminar = Auth.tieneRol('administrador');

    c.innerHTML = `
      <div class="tabla-wrap">
        <table>
          <thead><tr>
            <th style="width:56px"></th>
            <th>Código</th><th>Nombre</th><th>Categoría</th>
            <th>Precio</th><th>Stock</th><th>Mínimo</th><th>Estado</th>
            ${(puedeEditar||puedeEliminar) ? '<th style="text-align:center">Acciones</th>' : ''}
          </tr></thead>
          <tbody>
            ${lista.map(p => `
              <tr style="cursor:pointer" onclick="Productos.verDetalle(${p.id})">
                <td onclick="event.stopPropagation()" style="padding:.5rem .75rem">
                  <div class="tabla-img">
                    ${p.imagen_url
                      ? `<img src="${p.imagen_url}" alt="${p.nombre}" onerror="this.parentElement.innerHTML='📦'" />`
                      : '📦'}
                  </div>
                </td>
                <td><span class="td-code">${p.codigo}</span></td>
                <td><strong>${p.nombre}</strong>${p.descripcion ? `<br><small style="color:var(--texto-sec)">${p.descripcion}</small>` : ''}</td>
                <td>${p.categoria ? `<span class="badge-info">${p.categoria}</span>` : '<span style="color:var(--gris)">—</span>'}</td>
                <td>$${Number(p.precio).toFixed(2)}</td>
                <td><strong>${p.stock_actual}</strong> <small style="color:var(--texto-sec)">${p.unidad||'pzs'}</small></td>
                <td style="color:var(--texto-sec)">${p.stock_minimo}</td>
                <td>${p.stock_actual<=0 ? '<span class="badge-alerta">🚫 Sin stock</span>' : p.stock_actual<p.stock_minimo ? '<span class="badge-alerta">⚠ Bajo</span>' : '<span class="badge-ok">✓ OK</span>'}</td>
                ${(puedeEditar||puedeEliminar) ? `
                <td onclick="event.stopPropagation()">
                  <div style="display:flex;gap:.35rem;justify-content:center">
                    ${puedeEditar ? `<button class="btn-icon edit" onclick="Productos.editar(${p.id})">✏️</button>` : ''}
                    ${puedeEditar ? `<button class="btn-icon edit" style="background:#f0fdf4;color:#16a34a" onclick="Productos.subirImagen(${p.id},'${p.nombre.replace(/'/g,"\\'")}')">🖼</button>` : ''}
                    ${puedeEliminar ? `<button class="btn-danger btn-sm" onclick="Productos.eliminar(${p.id},'${p.nombre.replace(/'/g,"\\'")}')">🗑</button>` : ''}
                  </div>
                </td>` : ''}
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
  }

  function render(lista) {
    vistaActual === 'cards' ? renderCards(lista) : renderTabla(lista);
  }

  async function cargar() {
    const c = document.getElementById('tabla-productos');
    if (!c) return;
    c.innerHTML = `<div class="empty-state"><div class="empty-icon"><span class="spinner" style="width:1.5rem;height:1.5rem;border-color:rgba(0,0,0,.15);border-top-color:var(--rojo);display:inline-block"></span></div><p>Cargando productos…</p></div>`;
    try {
      todos = await api.get('/productos');
      render(todos);
    } catch (err) {
      c.innerHTML = `<div class="empty-state"><div class="empty-icon">❌</div><p>${err.message}</p></div>`;
      Toast.error('Error al cargar productos: ' + err.message);
    }
  }

  // Búsqueda en tiempo real
  document.getElementById('buscar-producto')?.addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase();
    render(todos.filter(p =>
      p.nombre.toLowerCase().includes(q) || p.codigo.toLowerCase().includes(q) ||
      (p.categoria && p.categoria.toLowerCase().includes(q))
    ));
  });

  // ── Toggle vista cards / tabla ──────────────────────────────
  function toggleVista(v) {
    vistaActual = v;
    document.getElementById('btn-vista-cards')?.classList.toggle('active', v === 'cards');
    document.getElementById('btn-vista-tabla')?.classList.toggle('active', v === 'tabla');
    const q = document.getElementById('buscar-producto')?.value.toLowerCase() || '';
    render(q ? todos.filter(p => p.nombre.toLowerCase().includes(q) || p.codigo.toLowerCase().includes(q)) : todos);
  }

  // ── Ver detalle producto ────────────────────────────────────
  function verDetalle(id) {
    const p = todos.find(x => x.id === id);
    if (!p) return;
    const puedeEditar = Auth.tieneRol('administrador','bodega');
    Modal.abrir(`
      <div style="display:flex;gap:1.5rem;flex-wrap:wrap">
        <div style="flex:0 0 160px">
          <div class="detalle-img-wrap">
            ${p.imagen_url
              ? `<img src="${p.imagen_url}" alt="${p.nombre}" style="width:160px;height:160px;object-fit:cover;border-radius:var(--radio)" onerror="this.parentElement.innerHTML='<div class=\\'detalle-img-placeholder\\'>📦</div>'" />`
              : `<div class="detalle-img-placeholder">📦</div>`}
          </div>
          ${puedeEditar ? `
          <button class="btn-secondary btn-sm" style="width:100%;margin-top:.6rem" onclick="Productos.subirImagen(${p.id},'${p.nombre.replace(/'/g,"\\'")}')">
            🖼 ${p.imagen_url ? 'Cambiar imagen' : 'Subir imagen'}
          </button>` : ''}
        </div>
        <div style="flex:1;min-width:200px">
          <div style="margin-bottom:1rem">
            <span class="td-code">${p.codigo}</span>
            ${p.categoria ? `<span class="badge-info" style="margin-left:.5rem">${p.categoria}</span>` : ''}
          </div>
          <h3 style="font-size:1.15rem;margin-bottom:.35rem">${p.nombre}</h3>
          ${p.descripcion ? `<p style="color:var(--texto-sec);font-size:.875rem;margin-bottom:.75rem">${p.descripcion}</p>` : ''}
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:.6rem;margin-top:.75rem">
            <div class="detalle-stat"><span class="detalle-stat-val">$${Number(p.precio).toFixed(2)}</span><span class="detalle-stat-lbl">Precio</span></div>
            <div class="detalle-stat"><span class="detalle-stat-val ${p.stock_actual < p.stock_minimo ? 'status-alerta' : 'status-ok'}">${p.stock_actual}</span><span class="detalle-stat-lbl">Stock actual (${p.unidad||'pzs'})</span></div>
            <div class="detalle-stat"><span class="detalle-stat-val">${p.stock_minimo}</span><span class="detalle-stat-lbl">Stock mínimo</span></div>
            <div class="detalle-stat">
              <span class="detalle-stat-val">
                ${p.stock_actual<=0 ? '<span class="badge-alerta">Sin stock</span>' : p.stock_actual<p.stock_minimo ? '<span class="badge-alerta">Bajo mínimo</span>' : '<span class="badge-ok">OK</span>'}
              </span>
              <span class="detalle-stat-lbl">Estado</span>
            </div>
          </div>
          ${puedeEditar ? `
          <div style="display:flex;gap:.6rem;margin-top:1.25rem">
            <button class="btn-primary btn-sm" onclick="Modal.cerrar();Productos.editar(${p.id})">✏️ Editar</button>
            <button class="btn-secondary btn-sm" onclick="Modal.cerrar();Nav.ir('movimientos')">↕️ Ver movimientos</button>
          </div>` : ''}
        </div>
      </div>`, `📦 ${p.nombre}`);
  }

  // ── Subir imagen ────────────────────────────────────────────
  function subirImagen(id, nombre) {
    Modal.abrir(`
      <div class="form-modal">
        <div id="preview-wrap" style="text-align:center;margin-bottom:1rem;display:none">
          <img id="img-preview" style="max-width:100%;max-height:200px;border-radius:var(--radio);object-fit:cover" />
        </div>
        <label class="upload-area" id="upload-area" for="img-file">
          <div class="upload-icon">🖼</div>
          <div class="upload-text">Arrastra una imagen o haz clic para seleccionar</div>
          <div class="upload-sub">JPG, PNG o WebP — máx. 5 MB</div>
          <input type="file" id="img-file" accept=".jpg,.jpeg,.png,.webp" style="display:none" />
        </label>
        <div class="form-actions">
          <button class="btn-secondary" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-primary" id="btn-upload-img" disabled>📤 Subir imagen</button>
        </div>
        <p id="upload-error" class="error-msg hidden"></p>
      </div>`, `🖼 Imagen — ${nombre}`);

    const input   = document.getElementById('img-file');
    const preview = document.getElementById('img-preview');
    const prevWrap = document.getElementById('preview-wrap');
    const area    = document.getElementById('upload-area');
    const btnUp   = document.getElementById('btn-upload-img');

    // Preview al seleccionar
    input.addEventListener('change', () => {
      const file = input.files[0];
      if (!file) return;
      if (file.size > 5 * 1024 * 1024) {
        document.getElementById('upload-error').textContent = 'El archivo supera 5 MB';
        document.getElementById('upload-error').classList.remove('hidden');
        return;
      }
      const reader = new FileReader();
      reader.onload = e => {
        preview.src = e.target.result;
        prevWrap.style.display = 'block';
        area.style.display = 'none';
        btnUp.disabled = false;
      };
      reader.readAsDataURL(file);
    });

    // Drag & drop
    area.addEventListener('dragover', e => { e.preventDefault(); area.classList.add('drag-over'); });
    area.addEventListener('dragleave', () => area.classList.remove('drag-over'));
    area.addEventListener('drop', e => {
      e.preventDefault();
      area.classList.remove('drag-over');
      input.files = e.dataTransfer.files;
      input.dispatchEvent(new Event('change'));
    });

    btnUp.onclick = async () => {
      const file   = input.files[0];
      const errEl  = document.getElementById('upload-error');
      if (!file) return;
      errEl.classList.add('hidden');
      btnUp.disabled = true;
      btnUp.innerHTML = '<span class="spinner"></span> Subiendo…';

      try {
        const formData = new FormData();
        formData.append('imagen', file);
        const result = await api.upload(`/storage/upload/${id}`, formData);
        if (result.error) throw new Error(result.error);
        Modal.cerrar();
        Toast.success('Imagen subida correctamente');
        cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btnUp.disabled = false;
        btnUp.innerHTML = '📤 Subir imagen';
      }
    };
  }

  // ── Helpers de formulario ────────────────────────────────────
  function categoriaOptions(selId = '') {
    const cats = typeof Categorias !== 'undefined' ? Categorias.getTodas() : [];
    return `<option value="">— Sin categoría —</option>` +
      cats.map(c => `<option value="${c.id}" ${c.id == selId ? 'selected' : ''}>${c.nombre}</option>`).join('');
  }

  function formHTML(p = {}) {
    return `
      <div class="form-modal">
        <div class="form-fila">
          <label>
            <span class="form-label">Código *</span>
            <input id="f-codigo" value="${p.codigo||''}" ${p.id?'readonly':'required'} placeholder="PROD-001" />
          </label>
          <label>
            <span class="form-label">Unidad</span>
            <input id="f-unidad" value="${p.unidad||'pieza'}" placeholder="pieza, kg, caja…" />
          </label>
        </div>
        <label>
          <span class="form-label">Nombre *</span>
          <input id="f-nombre" value="${p.nombre||''}" required placeholder="Nombre del producto" />
        </label>
        <label>
          <span class="form-label">Descripción</span>
          <textarea id="f-descripcion" rows="2" placeholder="Descripción opcional">${p.descripcion||''}</textarea>
        </label>
        <label>
          <span class="form-label">Categoría</span>
          <select id="f-categoria">${categoriaOptions(p.categoria_id)}</select>
        </label>
        <div class="form-fila">
          <label>
            <span class="form-label">Precio ($)</span>
            <input id="f-precio" type="number" min="0" step="0.01" value="${p.precio||0}" />
          </label>
          <label>
            <span class="form-label">Stock ${p.id?'(via movimientos)':'inicial'}</span>
            <input id="f-stock" type="number" min="0" value="${p.stock_actual||0}" ${p.id?'readonly':''} />
          </label>
        </div>
        <label>
          <span class="form-label">Stock mínimo</span>
          <input id="f-minimo" type="number" min="1" value="${p.stock_minimo||5}" />
        </label>
        <div class="form-actions">
          <button class="btn-secondary" type="button" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-primary" id="btn-guardar-producto" type="button">
            ${p.id ? '💾 Guardar cambios' : '✚ Crear producto'}
          </button>
        </div>
        <p id="form-error" class="error-msg hidden"></p>
      </div>`;
  }

  function nuevo() {
    Modal.abrir(formHTML(), '📦 Nuevo producto');
    document.getElementById('btn-guardar-producto').onclick = async (e) => {
      const btn = e.currentTarget;
      const errEl = document.getElementById('form-error');
      errEl.classList.add('hidden');
      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Guardando…';
      try {
        await api.post('/productos', {
          codigo:       document.getElementById('f-codigo').value.trim(),
          nombre:       document.getElementById('f-nombre').value.trim(),
          descripcion:  document.getElementById('f-descripcion').value.trim(),
          categoria_id: document.getElementById('f-categoria').value || null,
          precio:       parseFloat(document.getElementById('f-precio').value),
          stock_actual: parseInt(document.getElementById('f-stock').value),
          stock_minimo: parseInt(document.getElementById('f-minimo').value),
          unidad:       document.getElementById('f-unidad').value.trim(),
        });
        Modal.cerrar();
        Toast.success('Producto creado correctamente');
        cargar(); Dashboard.cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btn.disabled = false;
        btn.innerHTML = '✚ Crear producto';
      }
    };
  }

  async function editar(id) {
    const p = todos.find(x => x.id === id);
    if (!p) return;
    Modal.abrir(formHTML(p), '✏️ Editar producto');
    document.getElementById('btn-guardar-producto').onclick = async (e) => {
      const btn = e.currentTarget;
      const errEl = document.getElementById('form-error');
      errEl.classList.add('hidden');
      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Guardando…';
      try {
        await api.put(`/productos/${id}`, {
          nombre:       document.getElementById('f-nombre').value.trim(),
          descripcion:  document.getElementById('f-descripcion').value.trim(),
          categoria_id: document.getElementById('f-categoria').value || null,
          precio:       parseFloat(document.getElementById('f-precio').value),
          stock_minimo: parseInt(document.getElementById('f-minimo').value),
          unidad:       document.getElementById('f-unidad').value.trim(),
        });
        Modal.cerrar();
        Toast.success('Producto actualizado correctamente');
        cargar(); Dashboard.cargar();
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
        <p>¿Desactivar <strong>"${nombre}"</strong>?<br>Sus movimientos se conservarán.</p>
        <div class="confirm-actions">
          <button class="btn-secondary" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-danger" id="btn-confirm-del-prod">Sí, desactivar</button>
        </div>
      </div>`, '⚠️ Confirmar');

    document.getElementById('btn-confirm-del-prod').onclick = async () => {
      try {
        await api.delete(`/productos/${id}`);
        Modal.cerrar();
        Toast.success('Producto desactivado');
        cargar(); Dashboard.cargar();
      } catch (err) { Toast.error(err.message); Modal.cerrar(); }
    };
  }

  return { cargar, editar, nuevo, eliminar, subirImagen, verDetalle, toggleVista, getTodos: () => todos };
})();
