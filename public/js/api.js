/**
 * api.js — Módulo base para todas las llamadas a la API REST.
 */
const API_BASE = '/api';

function getToken() {
  return localStorage.getItem('token');
}

async function apiFetch(ruta, opciones = {}) {
  const { blob = false, ...fetchOpciones } = opciones;
  const method = (fetchOpciones.method || 'GET').toUpperCase();
  const headers = { 'Content-Type': 'application/json', ...opciones.headers };
  const token = getToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;

  try {
    const resp = await fetch(`${API_BASE}${ruta}`, { ...fetchOpciones, headers });
    const result = await leerRespuesta(resp, ruta, blob);
    if (method === 'GET' && !blob && typeof Offline !== 'undefined') Offline.guardar(ruta, result);
    return result;
  } catch (error) {
    if (method === 'GET' && !blob && typeof Offline !== 'undefined') {
      const cached = Offline.leer(ruta);
      if (cached !== null && cached !== undefined) return cached;
    }
    if (method !== 'GET' && ruta !== '/auth/login' && typeof Offline !== 'undefined') {
      Offline.encolar({ ruta, method, body: fetchOpciones.body ? JSON.parse(fetchOpciones.body) : null });
      return { offlineQueued: true };
    }
    throw error;
  }
}

async function leerRespuesta(resp, ruta, comoBlob = false) {
  // Un login incorrecto debe mostrar el error sin recargar el formulario.
  if (resp.status === 401 && ruta !== '/auth/login') {
    localStorage.removeItem('token');
    localStorage.removeItem('usuario');
    window.location.reload();
    throw new Error('Tu sesión expiró. Inicia sesión nuevamente.');
  }

  if (resp.ok && comoBlob) return resp.blob();
  if (resp.status === 204) return null;
  const data = await resp.json().catch(() => {
    throw new Error(`El servidor devolvió una respuesta inesperada (HTTP ${resp.status}). Intenta nuevamente.`);
  });
  if (!resp.ok) throw new Error(data.error || `Error ${resp.status}`);
  return data;
}

const api = {
  get:    (ruta)          => apiFetch(ruta),
  post:   (ruta, body)    => apiFetch(ruta, { method: 'POST',  body: JSON.stringify(body) }),
  put:    (ruta, body)    => apiFetch(ruta, { method: 'PUT',   body: JSON.stringify(body) }),
  patch:  (ruta, body)    => apiFetch(ruta, { method: 'PATCH', body: JSON.stringify(body) }),
  delete: (ruta)          => apiFetch(ruta, { method: 'DELETE' }),
  blob:   (ruta)          => apiFetch(ruta, { blob: true }),

  // Subida de archivos (multipart)
  // Mejora #4: verificar r.ok antes de parsear para no silenciar errores HTTP
  upload: async (ruta, formData) => {
    const token = getToken();
    const r = await fetch(`${API_BASE}${ruta}`, {
      method: 'POST',
      headers: token ? { 'Authorization': `Bearer ${token}` } : {},
      body: formData,
    });
    return leerRespuesta(r, ruta);
  }
};

function escaparHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

// Mejora #6: helper centralizado para el spinner de carga (evita copypaste en todos los módulos)
function mostrarCargando(elementId, mensaje = 'Cargando…') {
  const el = document.getElementById(elementId);
  if (!el) return;
  el.innerHTML = `
    <div class="empty-state">
      <div class="empty-icon">
        <span class="spinner" style="width:1.5rem;height:1.5rem;border-color:rgba(0,0,0,.15);border-top-color:var(--rojo);display:inline-block"></span>
      </div>
      <p>${mensaje}</p>
    </div>`;
}
