const express  = require('express');
const router   = express.Router();
const multer   = require('multer');
const path     = require('path');
const {
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const pool = require('../db/connection');
const s3   = require('../db/s3');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');

router.use(verificarToken);

const BUCKET = process.env.S3_BUCKET;
const REGION = process.env.AWS_REGION || 'us-east-1';

// Multer en memoria — no guarda archivos en disco de la VM
const upload = multer({
  storage: multer.memoryStorage(),
  // Mejora #2: alineado con el límite de 5 MB que avisa el frontend
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const permitidos = ['.jpg', '.jpeg', '.png', '.webp', '.pdf', '.xlsx', '.csv'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (!permitidos.includes(ext)) {
      return cb(new Error(`Tipo de archivo no permitido: ${ext}`));
    }
    cb(null, true);
  }
});

/**
 * POST /api/storage/upload/:productoId
 * Sube la imagen de un producto a S3.
 * Form-data: campo "imagen" con el archivo.
 */
router.post(
  '/upload/:productoId',
  permitirRoles('administrador', 'bodega'),
  upload.single('imagen'),
  async (req, res, next) => {
    if (!req.file) return res.status(400).json({ error: 'No se recibió ningún archivo' });

    const ext   = path.extname(req.file.originalname).toLowerCase();
    const clave = `productos/${req.params.productoId}${ext}`;

    try {
      // Subir a S3
      await s3.send(new PutObjectCommand({
        Bucket:      BUCKET,
        Key:         clave,
        Body:        req.file.buffer,
        ContentType: req.file.mimetype,
      }));

      // URL pública estándar virtual-hosted (funciona con bucket público)
      const urlPublica = `https://${BUCKET}.s3.${REGION}.amazonaws.com/${clave}`;

      // Guardar URL en la base de datos
      await pool.query(
        'UPDATE productos SET imagen_url=$1, actualizado_en=NOW() WHERE id=$2',
        [urlPublica, req.params.productoId]
      );

      res.json({ mensaje: 'Imagen subida correctamente', url: urlPublica });
    } catch (err) { next(err); }
  }
);

/**
 * GET /api/storage/url-firmada/:productoId
 * Genera una URL pre-firmada de S3 (válida 15 min) para acceso privado.
 */
router.get('/url-firmada/:productoId', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT imagen_url FROM productos WHERE id=$1',
      [req.params.productoId]
    );

    if (!rows[0] || !rows[0].imagen_url) {
      return res.status(404).json({ error: 'El producto no tiene imagen' });
    }

    // Extraer la clave del objeto desde la URL almacenada
    const urlObj = new URL(rows[0].imagen_url);
    // pathname = /productos/123.jpg  → quitar el "/"
    const clave = urlObj.pathname.replace(/^\//, '');

    const comando = new GetObjectCommand({ Bucket: BUCKET, Key: clave });
    const urlFirmada = await getSignedUrl(s3, comando, { expiresIn: 900 }); // 15 min

    res.json({ url: urlFirmada, expira_en: '15 minutos' });
  } catch (err) { next(err); }
});

/**
 * DELETE /api/storage/:productoId
 * Elimina el objeto de S3 y limpia la URL en la BD. Solo administrador.
 */
router.delete('/:productoId', permitirRoles('administrador'), async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT imagen_url FROM productos WHERE id=$1',
      [req.params.productoId]
    );

    if (!rows[0] || !rows[0].imagen_url) {
      return res.status(404).json({ error: 'El producto no tiene imagen' });
    }

    const urlObj = new URL(rows[0].imagen_url);
    const clave  = urlObj.pathname.replace(/^\//, '');

    await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: clave }));

    await pool.query(
      'UPDATE productos SET imagen_url=NULL, actualizado_en=NOW() WHERE id=$1',
      [req.params.productoId]
    );

    res.json({ mensaje: 'Imagen eliminada correctamente' });
  } catch (err) { next(err); }
});

module.exports = router;
