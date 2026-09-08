const express  = require('express');
const router   = express.Router();
const bcrypt   = require('bcryptjs');
const jwt      = require('jsonwebtoken');
const pool     = require('../db/connection');

/**
 * POST /api/auth/login
 * Body: { correo, password }
 * Devuelve un JWT con los datos del usuario.
 */
router.post('/login', async (req, res, next) => {
  const { correo, password } = req.body;
  if (!correo || !password) {
    return res.status(400).json({ error: 'Correo y contraseña son obligatorios' });
  }

  try {
    const { rows } = await pool.query(
      'SELECT * FROM usuarios WHERE correo = $1 AND activo = TRUE',
      [correo]
    );
    const usuario = rows[0];
    if (!usuario) return res.status(401).json({ error: 'Credenciales inválidas' });

    const coincide = await bcrypt.compare(password, usuario.password);
    if (!coincide) return res.status(401).json({ error: 'Credenciales inválidas' });

    const token = jwt.sign(
      { id: usuario.id, nombre: usuario.nombre, rol: usuario.rol },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '8h' }
    );

    res.json({ token, usuario: { id: usuario.id, nombre: usuario.nombre, rol: usuario.rol } });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
