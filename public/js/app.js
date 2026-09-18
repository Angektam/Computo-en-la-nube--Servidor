/**
 * app.js — Punto de entrada principal. Gestiona navegación, topbar y arranque.
 */

// ── Toast Notifications ──────────────────────────────────────
const Toast = (() => {
  function mostrar(mensaje, tipo = 'default', duracion = 3500) {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${tipo}`;
    const iconos = { success: '✓', error: '✕', warning: '⚠', default: 'ℹ' };
    toast.innerHTML = `<span>${iconos[tipo] || iconos.default}</span><span>${mensaje}</span>`;
    container.appendChild(toast);
    setTimeout(() => {
      toast.style.animation = 'toastOut .25s ease forwards';
      setTimeout(() => toast.remove(), 250);
    }, duracion);
  }
  return {
    success: (msg) => mostrar(msg, 'success'),
    error:   (msg) => mostrar(msg, 'error'),
    warning: (msg) => mostrar(msg, 'warning'),
    info:    (msg) => mostrar(msg, 'default'),
  };
})();

// ── Modal ────────────────────────────────────────────────────
const Modal = (() => {
  const overlay   = document.getElementById('modal-overlay');
  const contenido = document.getElementById('modal-contenido');
  const titleEl   = document.getElementById('modal-title-text');

  document.getElementById('modal-cerrar').addEventListener('click', cerrar);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) cerrar(); });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !overlay.classList.contains('hidden')) cerrar();
  });

  function abrir(html, titulo = '') {
    contenido.innerHTML = html;
    titleEl.textContent = titulo;
    overlay.classList.remove('hidden');
    const primer = contenido.querySelector('input:not([readonly]), select, textarea');
    if (primer) setTimeout(() => primer.focus(), 50);
  }

  function cerrar() {
    overlay.classList.add('hidden');
    contenido.innerHTML = '';
    titleEl.textContent = '';
  }

  return { abrir, cerrar };
})();

// ── Topbar dinámico ──────────────────────────────────────────
const Topbar = (() => {
  const titulo   = document.getElementById('topbar-title');
  const acciones = document.getElementById('topbar-actions');

  const config = {
    dashboard:   { titulo: '🏠 Dashboard',     acciones: () => '' },
    productos: {
      titulo: '🗂 Productos',
      acciones: () => Auth.tieneRol('administrador','bodega')
        ? `<button class="btn-primary" id="btn-nuevo-producto">＋ Nuevo producto</button>` : ''
    },
    movimientos: {
      titulo: '↕️ Movimientos',
      acciones: () => Auth.tieneRol('administrador','bodega')
        ? `<button class="btn-primary" id="btn-nuevo-movimiento">＋ Registrar movimiento</button>` : ''
    },
    pedidos:     { titulo: '🛒 Pedidos automáticos', acciones: () => '' },
    reportes:    { titulo: '📊 Reportes',             acciones: () => '' },
    categorias: {
      titulo: '🏷 Categorías',
      acciones: () => Auth.tieneRol('administrador')
        ? `<button class="btn-primary" id="btn-nueva-categoria">＋ Nueva categoría</button>` : ''
    },
    usuarios: {
      titulo: '👥 Usuarios',
      acciones: () => Auth.tieneRol('administrador')
        ? `<button class="btn-primary" id="btn-nuevo-usuario">＋ Nuevo usuario</button>` : ''
    },
  };

  function set(vista) {
    const cfg = config[vista] || { titulo: vista, acciones: () => '' };
    titulo.textContent = cfg.titulo;
    acciones.innerHTML = cfg.acciones();

    // Re-enlazar botones inyectados
    document.getElementById('btn-nuevo-producto')?.addEventListener('click', () => Productos.nuevo());
    document.getElementById('btn-nuevo-movimiento')?.addEventListener('click', () => Movimientos.nuevo());
    document.getElementById('btn-nueva-categoria')?.addEventListener('click', () => Categorias.nueva());
    document.getElementById('btn-nuevo-usuario')?.addEventListener('click', () => Usuarios.nuevo());
  }

  return { set };
})();

// ── Navegación ───────────────────────────────────────────────
const Nav = (() => {
  const vistas = ['dashboard','productos','movimientos','pedidos','reportes','categorias','usuarios'];

  document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => ir(btn.dataset.vista));
  });

  function ir(vista) {
    document.querySelectorAll('.nav-btn').forEach(b =>
      b.classList.toggle('active', b.dataset.vista === vista)
    );
    vistas.forEach(v => {
      const el = document.getElementById(`vista-${v}`);
      if (el) el.classList.toggle('hidden', v !== vista);
    });

    Topbar.set(vista);

    if (vista === 'dashboard')   Dashboard.cargar();
    if (vista === 'productos')   { Categorias.cargar(); Productos.cargar(); }
    if (vista === 'movimientos') { Productos.cargar(); Movimientos.cargar(1); }
    if (vista === 'pedidos')     Pedidos.cargar('pendiente');
    if (vista === 'reportes')    Reportes.cargar();
    if (vista === 'categorias')  Categorias.cargar();
    if (vista === 'usuarios')    Usuarios.cargar();

    // Mejora #5: activar filtro de pedidos la primera vez que se abre la vista
    if (vista === 'pedidos') {
      const sel = document.getElementById('filtro-estado-pedido');
      const btn = document.getElementById('btn-filtrar-pedidos');
      if (btn && !btn._bound) {
        btn._bound = true;
        btn.addEventListener('click', () => Pedidos.cargar(sel?.value || 'pendiente'));
      }
    }
  }

  return { ir };
})();

// ── Cambio de contraseña ─────────────────────────────────────
document.getElementById('btn-cambiar-password')?.addEventListener('click', () => {
  const usuario = Auth.getUsuario();
  const esAdmin = Auth.tieneRol('administrador');

  // Mejora #8: advertir al admin que la sesión actual no refleja cambios de rol
  // hasta que el usuario afectado vuelva a iniciar sesión (el JWT no se invalida).
  Modal.abrir(`
    <div class="form-modal">
      ${!esAdmin ? `
      <label>
        <span class="form-label">Contraseña actual</span>
        <input id="pwd-actual" type="password" placeholder="••••••••" />
      </label>` : ''}
      <label>
        <span class="form-label">Nueva contraseña *</span>
        <input id="pwd-nueva" type="password" placeholder="Mínimo 6 caracteres" />
      </label>
      <label>
        <span class="form-label">Confirmar nueva contraseña *</span>
        <input id="pwd-confirmar" type="password" placeholder="Repite la contraseña" />
      </label>
      <div class="form-actions">
        <button class="btn-secondary" type="button" onclick="Modal.cerrar()">Cancelar</button>
        <button class="btn-primary" id="btn-guardar-pwd">🔑 Cambiar contraseña</button>
      </div>
      <p id="pwd-error" class="error-msg hidden"></p>
    </div>`, '🔑 Cambiar contraseña');

  document.getElementById('btn-guardar-pwd').onclick = async (e) => {
    const btn    = e.currentTarget;
    const errEl  = document.getElementById('pwd-error');
    const nueva  = document.getElementById('pwd-nueva').value;
    const conf   = document.getElementById('pwd-confirmar').value;
    const actual = document.getElementById('pwd-actual')?.value;

    errEl.classList.add('hidden');

    if (nueva.length < 6) {
      errEl.textContent = 'La contraseña debe tener al menos 6 caracteres';
      errEl.classList.remove('hidden'); return;
    }
    if (nueva !== conf) {
      errEl.textContent = 'Las contraseñas no coinciden';
      errEl.classList.remove('hidden'); return;
    }

    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Guardando…';

    try {
      await api.patch(`/usuarios/${usuario.id}/password`, {
        password_actual: actual,
        password_nueva:  nueva,
      });
      Modal.cerrar();
      Toast.success('Contraseña actualizada correctamente');
    } catch (err) {
      errEl.textContent = err.message;
      errEl.classList.remove('hidden');
      btn.disabled = false;
      btn.innerHTML = '🔑 Cambiar contraseña';
    }
  };
});

// ── Arranque principal ───────────────────────────────────────
const App = (() => {
  function iniciar() {
    const usuario = Auth.getUsuario();
    if (!usuario) return;

    document.getElementById('pantalla-login').classList.add('hidden');
    document.getElementById('pantalla-app').classList.remove('hidden');

    document.getElementById('usuario-nombre').textContent = usuario.nombre || usuario.correo || 'Usuario';
    document.getElementById('usuario-rol').textContent    = usuario.rol || '';

    const inicial = (usuario.nombre || usuario.correo || 'U').charAt(0).toUpperCase();
    document.getElementById('usuario-avatar').textContent = inicial;

    // Mostrar secciones de admin solo si corresponde
    if (Auth.tieneRol('administrador')) {
      document.querySelectorAll('.admin-only').forEach(el => el.style.display = '');
    }

    // Cargar pedidos para mostrar badge
    Pedidos.cargar('pendiente');

    Nav.ir('dashboard');
  }

  return { iniciar };
})();

// ── Iniciar si ya hay sesión activa ──────────────────────────
if (Auth.estaAutenticado()) {
  App.iniciar();
}
