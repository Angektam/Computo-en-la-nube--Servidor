/**
 * usuario.routes.js — Gestión de usuarios (solo administrador).
 */
const express  = require('express');
const router   = express.Router();
const bcrypt   = require('bcryptjs');
const pool     = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');

router.use(verificarToken);

/** GET /api/usuarios — Lista todos los usuarios */
router.get('/', permitirRoles('administrador'), async (_req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, nombre, correo, rol, activo, creado_en FROM usuarios ORDER BY nombre ASC'
    );
    res.json(rows);
  } catch (err) { next(err); }
});

/** POST /api/usuarios — Crea un usuario */
router.post('/', permitirRoles('administrador'), async (req, res, next) => {
  const { nombre, correo, password, rol } = req.body;
  if (!nombre || !correo || !password || !rol) {
    return res.status(400).json({ error: 'Nombre, correo, contraseña y rol son obligatorios' });
  }
  if (!['administrador', 'bodega', 'cajero'].includes(rol)) {
    return res.status(400).json({ error: 'Rol inválido' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      'INSERT INTO usuarios (nombre, correo, password, rol) VALUES ($1,$2,$3,$4) RETURNING id, nombre, correo, rol, activo, creado_en',
      [nombre.trim(), correo.trim().toLowerCase(), hash, rol]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'El correo ya está registrado' });
    next(err);
  }
});

/** PUT /api/usuarios/:id — Edita nombre, rol y estado */
router.put('/:id', permitirRoles('administrador'), async (req, res, next) => {
  const { nombre, rol, activo } = req.body;
  if (!nombre || !rol) return res.status(400).json({ error: 'Nombre y rol son obligatorios' });
  if (!['administrador', 'bodega', 'cajero'].includes(rol)) {
    return res.status(400).json({ error: 'Rol inválido' });
  }
  try {
    const { rows } = await pool.query(
      'UPDATE usuarios SET nombre=$1, rol=$2, activo=$3 WHERE id=$4 RETURNING id, nombre, correo, rol, activo, creado_en',
      [nombre.trim(), rol, activo !== undefined ? activo : true, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado' });
    res.json(rows[0]);
  } catch (err) { next(err); }
});

/** PATCH /api/usuarios/:id/password — Cambia contraseña */
router.patch('/:id/password', async (req, res, next) => {
  const { password_actual, password_nueva } = req.body;
  // Admin puede cambiar cualquiera; el usuario solo la suya
  const esAdmin = req.usuario.rol === 'administrador';
  const esPropietario = req.usuario.id === parseInt(req.params.id);

  if (!esAdmin && !esPropietario) {
    return res.status(403).json({ error: 'No puedes cambiar la contraseña de otro usuario' });
  }
  if (!password_nueva || password_nueva.length < 6) {
    return res.status(400).json({ error: 'La nueva contraseña debe tener al menos 6 caracteres' });
  }

  try {
    const { rows } = await pool.query('SELECT password FROM usuarios WHERE id=$1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado' });

    // Si no es admin, verificar contraseña actual
    if (!esAdmin) {
      if (!password_actual) return res.status(400).json({ error: 'Debes proporcionar tu contraseña actual' });
      const coincide = await bcrypt.compare(password_actual, rows[0].password);
      if (!coincide) return res.status(401).json({ error: 'Contraseña actual incorrecta' });
    }

    const hash = await bcrypt.hash(password_nueva, 10);
    await pool.query('UPDATE usuarios SET password=$1 WHERE id=$2', [hash, req.params.id]);
    res.json({ mensaje: 'Contraseña actualizada correctamente' });
  } catch (err) { next(err); }
});

/** DELETE /api/usuarios/:id — Desactiva usuario (borrado lógico) */
router.delete('/:id', permitirRoles('administrador'), async (req, res, next) => {
  if (req.usuario.id === parseInt(req.params.id)) {
    return res.status(400).json({ error: 'No puedes desactivar tu propia cuenta' });
  }
  try {
    await pool.query('UPDATE usuarios SET activo=FALSE WHERE id=$1', [req.params.id]);
    res.json({ mensaje: 'Usuario desactivado' });
  } catch (err) { next(err); }
});

module.exports = router;
