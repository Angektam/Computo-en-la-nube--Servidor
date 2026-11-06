/**
 * usuarios.js — Gestión de usuarios (solo administrador).
 */
const Usuarios = (() => {
  let todos = [];

  const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[char]);

  const rolBadge = {
    administrador: `<span class="badge-rol">👑 Administrador</span>`,
    bodega:        `<span class="badge-info">📦 Bodega</span>`,
    cajero:        `<span class="badge-warning">🧾 Cajero</span>`,
  };

  const rolDescripcion = {
    administrador: 'Administra usuarios, roles y el sistema.',
    bodega: 'Gestiona productos, existencias y pedidos.',
    cajero: 'Consulta productos y movimientos.',
  };

  function renderTabla(lista) {
    const c = document.getElementById('tabla-usuarios');
    if (!lista.length) {
      c.innerHTML = `<div class="empty-state" style="padding:2.5rem"><div class="empty-icon">👥</div><p>No hay usuarios registrados.</p></div>`;
      return;
    }
    const miId = Auth.getUsuario()?.id;

    c.innerHTML = `
      <div class="tabla-wrap">
        <table>
          <thead><tr>
            <th>Nombre</th><th>Correo</th><th>Rol</th>
            <th>Estado</th><th>Creado</th>
            <th style="text-align:center">Acciones</th>
          </tr></thead>
          <tbody>
            ${lista.map(u => `
              <tr>
                <td>
                  <div style="display:flex;align-items:center;gap:.6rem">
                    <div style="width:32px;height:32px;border-radius:50%;background:var(--rojo-claro);color:var(--rojo);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:.8rem;flex-shrink:0">
                      ${escapeHtml(u.nombre.charAt(0).toUpperCase())}
                    </div>
                    <strong>${escapeHtml(u.nombre)}</strong>${u.id === miId ? ' <span class="badge-info" style="font-size:.65rem">Tú</span>' : ''}
                  </div>
                </td>
                <td style="color:var(--texto-sec)">${escapeHtml(u.correo)}</td>
                <td>${rolBadge[u.rol] || escapeHtml(u.rol)}</td>
                <td>${u.activo ? '<span class="badge-activo">● Activo</span>' : '<span class="badge-inactivo">● Inactivo</span>'}</td>
                <td style="color:var(--texto-sec);white-space:nowrap">${new Date(u.creado_en).toLocaleDateString('es-MX')}</td>
                <td>
                  <div style="display:flex;gap:.4rem;justify-content:center">
                    <button class="btn-icon edit" title="Editar usuario" onclick="Usuarios.editar(${u.id})">✏️</button>
                    ${u.id !== miId ? `
                    <button class="btn-danger btn-sm" title="${u.activo ? 'Desactivar' : 'Ya inactivo'}" onclick="Usuarios.toggleActivo(${u.id},this.dataset.nombre,${u.activo})" data-nombre="${escapeHtml(u.nombre)}" ${!u.activo ? 'disabled' : ''}>
                      ${u.activo ? '🚫' : '✓'}
                    </button>` : ''}
                  </div>
                </td>
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
  }

  async function cargar() {
    const c = document.getElementById('tabla-usuarios');
    if (!c) return;
    mostrarCargando('tabla-usuarios', 'Cargando usuarios…');
    try {
      todos = await api.get('/usuarios');
      renderTabla(todos);
    } catch (err) {
      c.innerHTML = '<div class="empty-state"><div class="empty-icon">❌</div><p></p></div>';
      c.querySelector('p').textContent = err.message;
    }
  }

  function formHTML(u = {}) {
    return `
      <form class="form-modal" id="form-usuario">
        <label>
          <span class="form-label">Nombre completo *</span>
          <input id="u-nombre" value="${escapeHtml(u.nombre)}" maxlength="100" required placeholder="Juan Pérez" />
        </label>
        <label>
          <span class="form-label">Correo electrónico *</span>
          <input id="u-correo" type="email" value="${escapeHtml(u.correo)}" maxlength="150" autocomplete="email" ${u.id ? 'readonly' : 'required'} placeholder="usuario@empresa.com" />
        </label>
        ${!u.id ? `
        <label>
          <span class="form-label">Contraseña * (mín. 6 caracteres)</span>
          <input id="u-password" type="password" minlength="6" autocomplete="new-password" required placeholder="Mínimo 6 caracteres" />
        </label>` : ''}
        <label>
          <span class="form-label">Rol *</span>
          <select id="u-rol" required>
            <option value="" disabled ${u.rol ? '' : 'selected'}>Selecciona un rol</option>
            <option value="cajero" ${u.rol === 'cajero' ? 'selected' : ''}>🧾 Cajero</option>
            <option value="bodega" ${u.rol === 'bodega' ? 'selected' : ''}>📦 Bodega</option>
            <option value="administrador" ${u.rol === 'administrador' ? 'selected' : ''}>👑 Administrador</option>
          </select>
          <small id="u-rol-descripcion" class="form-hint">${escapeHtml(rolDescripcion[u.rol] || 'Elige los permisos que tendrá este usuario.')}</small>
        </label>
        ${u.id ? `
        <label style="display:flex;flex-direction:row;align-items:center;gap:.6rem;cursor:pointer">
          <input type="checkbox" id="u-activo" ${u.activo ? 'checked' : ''} style="width:auto;accent-color:var(--rojo)" />
          <span class="form-label" style="margin:0">Usuario activo</span>
        </label>` : ''}
        <div class="form-actions">
          <button class="btn-secondary" type="button" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-primary" id="btn-guardar-user" type="submit">
            ${u.id ? '💾 Guardar cambios' : '✚ Crear usuario'}
          </button>
        </div>
        <p id="user-error" class="error-msg hidden"></p>
      </form>`;
  }

  function nuevo() {
    Modal.abrir(formHTML(), '👤 Nuevo usuario');
    const form = document.getElementById('form-usuario');
    const selectRol = document.getElementById('u-rol');
    selectRol.addEventListener('change', () => {
      document.getElementById('u-rol-descripcion').textContent = rolDescripcion[selectRol.value];
    });
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn   = document.getElementById('btn-guardar-user');
      const errEl = document.getElementById('user-error');
      errEl.classList.add('hidden');
      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Creando…';
      try {
        await api.post('/usuarios', {
          nombre:   document.getElementById('u-nombre').value.trim(),
          correo:   document.getElementById('u-correo').value.trim(),
          password: document.getElementById('u-password').value,
          rol:      document.getElementById('u-rol').value,
        });
        Modal.cerrar();
        Toast.success('Usuario creado correctamente');
        await cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btn.disabled = false;
        btn.innerHTML = '✚ Crear usuario';
      }
    });
  }

  function editar(id) {
    const u = todos.find(x => x.id === id);
    if (!u) return;
    Modal.abrir(formHTML(u), '✏️ Editar usuario');
    const form = document.getElementById('form-usuario');
    const selectRol = document.getElementById('u-rol');
    selectRol.addEventListener('change', () => {
      document.getElementById('u-rol-descripcion').textContent = rolDescripcion[selectRol.value];
    });
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn   = document.getElementById('btn-guardar-user');
      const errEl = document.getElementById('user-error');
      errEl.classList.add('hidden');
      btn.disabled = true;
      btn.innerHTML = '<span class="spinner"></span> Guardando…';
      try {
        await api.put(`/usuarios/${id}`, {
          nombre: document.getElementById('u-nombre').value.trim(),
          rol:    document.getElementById('u-rol').value,
          activo: document.getElementById('u-activo').checked,
        });
        Modal.cerrar();
        // Mejora #8: el JWT del usuario editado no se invalida automáticamente.
        // Su nuevo rol/estado entrará en vigor cuando su token actual expire (máx. 8h)
        // o cuando cierre y vuelva a iniciar sesión.
        Toast.success('Usuario actualizado. Los cambios de rol aplican en su próxima sesión.');
        cargar();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.classList.remove('hidden');
        btn.disabled = false;
        btn.innerHTML = '💾 Guardar cambios';
      }
    });
  }

  function toggleActivo(id, nombre, activo) {
    if (!activo) return; // ya inactivo
    Modal.abrir(`
      <div class="confirm-dialog">
        <div class="confirm-icon">🚫</div>
        <p>¿Desactivar a <strong>"${escapeHtml(nombre)}"</strong>?<br>
        El usuario no podrá iniciar sesión pero sus registros se conservarán.</p>
        <div class="confirm-actions">
          <button class="btn-secondary" onclick="Modal.cerrar()">Cancelar</button>
          <button class="btn-danger" id="btn-confirm-del-user">Sí, desactivar</button>
        </div>
      </div>`, '⚠️ Confirmar desactivación');

    document.getElementById('btn-confirm-del-user').onclick = async () => {
      try {
        await api.delete(`/usuarios/${id}`);
        Modal.cerrar();
        Toast.success('Usuario desactivado');
        cargar();
      } catch (err) {
        Toast.error(err.message);
        Modal.cerrar();
      }
    };
  }

  return { cargar, nuevo, editar, toggleActivo };
})();
