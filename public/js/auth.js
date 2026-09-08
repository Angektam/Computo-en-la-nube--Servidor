/**
 * auth.js — Login / logout y estado de sesión.
 */
const Auth = (() => {
  function getUsuario() {
    try { return JSON.parse(localStorage.getItem('usuario')); } catch { return null; }
  }

  function estaAutenticado() {
    return !!localStorage.getItem('token');
  }

  async function login(correo, password) {
    const data = await api.post('/auth/login', { correo, password });
    localStorage.setItem('token', data.token);
    localStorage.setItem('usuario', JSON.stringify(data.usuario));
    return data.usuario;
  }

  function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('usuario');
    window.location.reload();
  }

  function tieneRol(...roles) {
    const u = getUsuario();
    return u && roles.includes(u.rol);
  }

  return { login, logout, estaAutenticado, getUsuario, tieneRol };
})();

// ── Formulario de login ──────────────────────────────────────
document.getElementById('form-login').addEventListener('submit', async (e) => {
  e.preventDefault();
  const correo   = document.getElementById('login-correo').value.trim();
  const password = document.getElementById('login-password').value;
  const errEl    = document.getElementById('login-error');
  const btnText  = document.getElementById('login-btn-text');
  const btn      = e.target.querySelector('button[type=submit]');

  errEl.classList.add('hidden');

  // Estado de carga
  btn.disabled = true;
  btnText.innerHTML = '<span class="spinner"></span> Ingresando…';

  try {
    await Auth.login(correo, password);
    App.iniciar();
  } catch (err) {
    errEl.textContent = '⚠ ' + err.message;
    errEl.classList.remove('hidden');
    btn.disabled = false;
    btnText.textContent = 'Iniciar sesión';
  }
});

document.getElementById('btn-logout').addEventListener('click', () => {
  Modal.abrir(`
    <div class="confirm-dialog">
      <div class="confirm-icon">🚪</div>
      <p>¿Cerrar sesión?</p>
      <div class="confirm-actions">
        <button class="btn-secondary" onclick="Modal.cerrar()">Cancelar</button>
        <button class="btn-primary" onclick="Auth.logout()">Sí, salir</button>
      </div>
    </div>`, 'Cerrar sesión');
});
