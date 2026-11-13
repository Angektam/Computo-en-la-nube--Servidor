const Offline = (() => {
  const QUEUE_KEY = 'inventario-offline-queue';
  const CACHE_PREFIX = 'inventario-offline-cache:';
  const queue = () => { try { return JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]'); } catch { return []; } };
  const setQueue = value => { localStorage.setItem(QUEUE_KEY, JSON.stringify(value)); window.dispatchEvent(new CustomEvent('offline-queue-updated')); };
  function encolar(item) { const items = queue(); items.push({ ...item, id: crypto.randomUUID(), createdAt: new Date().toISOString() }); setQueue(items); }
  function guardar(ruta, data) { try { localStorage.setItem(CACHE_PREFIX + ruta, JSON.stringify({ savedAt: Date.now(), data })); } catch {} }
  function leer(ruta) { try { return JSON.parse(localStorage.getItem(CACHE_PREFIX + ruta))?.data; } catch { return null; } }
  function setEstado() {
    document.body.classList.toggle('offline', !navigator.onLine);
    const badge = document.getElementById('offline-status');
    if (badge) badge.textContent = navigator.onLine ? (queue().length ? `Con conexión · ${queue().length} pendiente(s)` : 'Con conexión') : 'Sin conexión · cambios guardados localmente';
  }
  async function sincronizar() {
    if (!navigator.onLine) return;
    const token = localStorage.getItem('token');
    if (!token) return;
    const pendientes = queue();
    const restantes = [];
    for (const item of pendientes) {
      try {
        const response = await fetch('/api' + item.ruta, {
          method: item.method,
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
          body: item.body == null ? undefined : JSON.stringify(item.body),
        });
        if (!response.ok) { restantes.push(item); break; }
      } catch { restantes.push(item); break; }
    }
    setQueue(restantes);
  }
  window.addEventListener('online', () => { setEstado(); sincronizar(); });
  window.addEventListener('offline', setEstado);
  window.addEventListener('offline-queue-updated', setEstado);
  window.addEventListener('load', () => { setEstado(); sincronizar(); });
  return { encolar, guardar, leer, pendientes: () => queue().length, setEstado };
})();
