/**
 * api.js — Módulo base para todas las llamadas a la API REST.
 */
const API_BASE = '/api';

function getToken() {
  return localStorage.getItem('token');
}

async function apiFetch(ruta, opciones = {}) {
  const headers = { 'Content-Type': 'application/json', ...opciones.headers };
  const token = getToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const resp = await fetch(`${API_BASE}${ruta}`, { ...opciones, headers });

  // Token expirado → redirigir al login
  if (resp.status === 401) {
    localStorage.removeItem('token');
    localStorage.removeItem('usuario');
    window.location.reload();
    return;
  }

  const data = await resp.json();
  if (!resp.ok) throw new Error(data.error || `Error ${resp.status}`);
  return data;
}

const api = {
  get:    (ruta)          => apiFetch(ruta),
  post:   (ruta, body)    => apiFetch(ruta, { method: 'POST',  body: JSON.stringify(body) }),
  put:    (ruta, body)    => apiFetch(ruta, { method: 'PUT',   body: JSON.stringify(body) }),
  patch:  (ruta, body)    => apiFetch(ruta, { method: 'PATCH', body: JSON.stringify(body) }),
  delete: (ruta)          => apiFetch(ruta, { method: 'DELETE' }),

  // Subida de archivos (multipart)
  upload: (ruta, formData) => {
    const token = getToken();
    return fetch(`${API_BASE}${ruta}`, {
      method: 'POST',
      headers: token ? { 'Authorization': `Bearer ${token}` } : {},
      body: formData
    }).then(r => r.json());
  }
};
