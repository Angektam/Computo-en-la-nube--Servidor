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

// Mejora #1: CORS restringido al origen propio en producción
const allowedOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map(o => o.trim())
  : [];

app.use(cors({
  origin: (origin, callback) => {
    // Permitir peticiones sin origen (same-origin, curl, Postman)
    if (!origin) return callback(null, true);
    if (process.env.NODE_ENV !== 'production') return callback(null, true);
    if (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error(`CORS: origen no permitido — ${origin}`));
  },
  credentials: true,
}));

// Mejora #3: Rate limit general y específico para login
const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 200 });
app.use(limiter);

// Rate limit estricto solo para autenticación (10 intentos / 15 min)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: 'Demasiados intentos de inicio de sesión. Espera 15 minutos.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// ── Body parsers ───────────────────────────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Frontend estático ──────────────────────────────────────────
app.use(express.static(path.join(__dirname, '..', 'public')));

// ── API REST ───────────────────────────────────────────────────
app.use('/health',            healthRoutes);
app.use('/api/auth',          authLimiter, authRoutes);
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
const ERRORES_OPERACIONALES = new Set(['23505', '23503', '23502', '22P02']);

app.use((err, _req, res, _next) => {
  // Errores de cliente (status conocido o código de Postgres operacional)
  const esOperacional = err.status || ERRORES_OPERACIONALES.has(err.code);
  const status = err.status || (ERRORES_OPERACIONALES.has(err.code) ? 400 : 500);

  if (esOperacional) {
    console.warn('[Error cliente]', err.message);
    return res.status(status).json({ error: err.message });
  }

  // Error inesperado: loguear en detalle pero NO exponer internos al cliente
  console.error('[Error interno]', err.stack || err.message);
  res.status(500).json({ error: 'Error interno del servidor' });
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT} [${process.env.NODE_ENV}]`);
});

module.exports = app;
