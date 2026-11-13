const VERSION = '20261106-pedidos-operacion-v2';
async function upgradePedidos(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(74208611)');
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, aplicado_en TIMESTAMPTZ NOT NULL DEFAULT NOW())');
    const { rows } = await client.query('SELECT version FROM schema_migrations WHERE version=$1', [VERSION]);
    if (!rows.length) {
      await client.query(`
        CREATE TABLE IF NOT EXISTS proveedores (
          id SERIAL PRIMARY KEY, nombre VARCHAR(150) NOT NULL UNIQUE,
          contacto VARCHAR(150), correo VARCHAR(150), telefono VARCHAR(50),
          activo BOOLEAN NOT NULL DEFAULT TRUE, creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS cantidad_recibida INTEGER NOT NULL DEFAULT 0;
        ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS proveedor_id INTEGER REFERENCES proveedores(id);
        ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS costo_unitario NUMERIC(12,2);
        ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS entrega_estimada DATE;
        UPDATE pedidos SET cantidad_recibida=cantidad_sugerida WHERE estado='recibido' AND cantidad_recibida=0;
        CREATE TABLE IF NOT EXISTS pedido_eventos (
          id SERIAL PRIMARY KEY, pedido_id INTEGER NOT NULL REFERENCES pedidos(id),
          usuario_id INTEGER REFERENCES usuarios(id), tipo VARCHAR(40) NOT NULL,
          estado_anterior VARCHAR(20), estado_nuevo VARCHAR(20), cantidad INTEGER,
          detalle TEXT NOT NULL DEFAULT '', creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        CREATE TABLE IF NOT EXISTS pedido_recepciones (
          id SERIAL PRIMARY KEY, pedido_id INTEGER NOT NULL REFERENCES pedidos(id),
          usuario_id INTEGER NOT NULL REFERENCES usuarios(id), cantidad INTEGER NOT NULL CHECK(cantidad>0),
          movimiento_id INTEGER REFERENCES movimientos(id), creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
        INSERT INTO pedido_eventos (pedido_id,tipo,estado_nuevo,detalle,creado_en)
        SELECT id,'importado',estado,'Pedido anterior a la incorporación del historial; autor original no disponible',generado_en FROM pedidos;
        CREATE INDEX IF NOT EXISTS pedido_eventos_pedido_fecha ON pedido_eventos(pedido_id,creado_en,id);
        CREATE INDEX IF NOT EXISTS pedidos_estado_fecha ON pedidos(estado,generado_en DESC,id DESC);
      `);
      await client.query('INSERT INTO schema_migrations(version) VALUES ($1)', [VERSION]);
    }
    await client.query(`
      ALTER TABLE categorias ADD COLUMN IF NOT EXISTS abreviacion VARCHAR(10);
      UPDATE categorias
      SET abreviacion = CASE
        WHEN LOWER(nombre) = 'herramientas' THEN 'HER'
        WHEN LOWER(nombre) = 'electrónica' THEN 'ELEC'
        WHEN LOWER(nombre) = 'papelería' THEN 'PAP'
        ELSE UPPER(REGEXP_REPLACE(LEFT(nombre, 4), '[^A-Za-z]', '', 'g'))
      END
      WHERE abreviacion IS NULL OR abreviacion = '';

      UPDATE productos p
      SET categoria_id = c.id, actualizado_en = NOW()
      FROM categorias c
      WHERE p.activo = TRUE
        AND c.abreviacion IS NOT NULL
        AND p.codigo ~ ('^' || c.abreviacion || '-[0-9]+$')
        AND p.categoria_id IS DISTINCT FROM c.id;
    `);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally { client.release(); }
}
module.exports = { upgradePedidos };
