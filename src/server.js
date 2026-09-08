require('dotenv').config();
const express  = require('express');
const helmet   = require('helmet');
const cors     = require('cors');
const path     = require('path');
const rateLimit = require('express-rate-limit');

const authRoutes       = require('./routes/auth.routes');
const productoRoutes   = require('./routes/producto.routes');
const movimientoRoutes = require('./routes/movimiento.routes');
const reporteRoutes    = require('./routes/reporte.routes');
const storageRoutes    = require('./routes/storage.routes');
const healthRoutes     = require('./routes/health.routes');
const categoriaRoutes  = require('./routes/categoria.routes');
const usuarioRoutes    = require('./routes/usuario.routes');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Seguridad ──────────────────────────────────────────────────
// Relajar CSP para permitir que el frontend cargue sus propios scripts/estilos
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc:              ["'self'"],
      scriptSrc:               ["'self'", "'unsafe-inline'"],
      scriptSrcAttr:           ["'unsafe-inline'"],
      styleSrc:                ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc:                 ["'self'", "https://fonts.gstatic.com"],
      imgSrc:                  ["'self'", "data:", "https:", "http:"],
      upgradeInsecureRequests: null,
    }
  },
  strictTransportSecurity: false,
}));
app.use(cors());

// Limitar 200 peticiones por IP cada 15 minutos
const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 200 });
app.use(limiter);

// ── Body parsers ───────────────────────────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Frontend estático ──────────────────────────────────────────
app.use(express.static(path.join(__dirname, '..', 'public')));

// ── API REST ───────────────────────────────────────────────────
app.use('/health',            healthRoutes);
app.use('/api/auth',          authRoutes);
app.use('/api/productos',     productoRoutes);
app.use('/api/movimientos',   movimientoRoutes);
app.use('/api/reportes',      reporteRoutes);
app.use('/api/storage',       storageRoutes);
app.use('/api/categorias',    categoriaRoutes);
app.use('/api/usuarios',      usuarioRoutes);

// ── SPA fallback: cualquier ruta no-API devuelve el index ──────
app.get(/^(?!\/api).*/, (_req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// ── Manejo global de errores ───────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('[Error]', err.message);
  res.status(err.status || 500).json({ error: err.message || 'Error interno del servidor' });
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT} [${process.env.NODE_ENV}]`);
});

module.exports = app;
