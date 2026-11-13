// Todas las operaciones que generan pedidos bloquean primero el producto.
// Así una salida, una edición y una generación manual no duplican pedidos abiertos.
async function registrarEvento(client, pedidoId, usuarioId, tipo, anterior, nuevo, cantidad = null, detalle = '') {
  await client.query(`INSERT INTO pedido_eventos (pedido_id,usuario_id,tipo,estado_anterior,estado_nuevo,cantidad,detalle)
    VALUES ($1,$2,$3,$4,$5,$6,$7)`, [pedidoId, usuarioId ?? null, tipo, anterior, nuevo, cantidad, detalle]);
}

async function generarPorFaltantes(client, productoId = null, usuarioId = null) {
  await client.query(`
    SELECT id FROM productos
    WHERE activo = TRUE AND stock_actual < stock_minimo
      AND ($1::integer IS NULL OR id = $1)
    ORDER BY id FOR UPDATE
  `, [productoId]);
  const { rows } = await client.query(`
    INSERT INTO pedidos (producto_id, cantidad_sugerida)
    SELECT p.id, LEAST(p.stock_minimo::bigint * 2, 2147483647) - p.stock_actual
    FROM productos p
    WHERE p.activo = TRUE AND p.stock_actual < p.stock_minimo
      AND ($1::integer IS NULL OR p.id = $1)
      AND NOT EXISTS (
        SELECT 1 FROM pedidos ped
        WHERE ped.producto_id = p.id AND ped.estado IN ('pendiente', 'enviado')
      )
    RETURNING *
  `, [productoId]);
  for (const pedido of rows) await registrarEvento(client, pedido.id, usuarioId, 'creado', null, 'pendiente', pedido.cantidad_sugerida, 'Generado por existencias bajo el mínimo');
  return rows;
}

const transiciones = {
  pendiente: ['enviado', 'cancelado'],
  enviado: ['recibido', 'cancelado'],
  recibido: [],
  cancelado: [],
};

async function bloquearPedido(client, id) {
  const { rows: referencias } = await client.query('SELECT producto_id FROM pedidos WHERE id=$1', [id]);
  if (!referencias[0]) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });

  // Mismo orden de bloqueo que la generación: producto antes que pedido.
  const { rows: productos } = await client.query(
    'SELECT id, stock_actual, activo FROM productos WHERE id=$1 FOR UPDATE', [referencias[0].producto_id]
  );
  const { rows: pedidos } = await client.query('SELECT * FROM pedidos WHERE id=$1 FOR UPDATE', [id]);
  const pedido = pedidos[0];
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  return { pedido, producto: productos[0] };
}

async function actualizarEstado(client, id, estado, usuarioId, recepcion = null) {
  const { pedido, producto } = await bloquearPedido(client, id);
  if (!transiciones[pedido.estado]?.includes(estado)) {
    throw Object.assign(new Error(`No se puede cambiar un pedido de "${pedido.estado}" a "${estado}". Actualiza la lista.`), { status: 409 });
  }

  let totalRecibido = Number(pedido.cantidad_recibida || 0);
  let cantidad = null;
  let siguiente = estado;
  if (estado === 'recibido') {
    if (!producto?.activo) throw Object.assign(new Error('No se puede recibir un pedido de un producto inactivo'), { status: 409 });
    const pendiente = Number(pedido.cantidad_sugerida) - totalRecibido;
    cantidad = recepcion ? recepcion.cantidad : pendiente;
    if (recepcion && recepcion.esperada !== totalRecibido) {
      throw Object.assign(new Error('El pedido recibió otra entrada. Actualiza la lista antes de continuar.'), { status: 409 });
    }
    if (cantidad > pendiente) throw Object.assign(new Error('La cantidad supera las unidades pendientes del pedido'), { status: 400 });
    const stockNuevo = Number(producto.stock_actual) + cantidad;
    if (!Number.isSafeInteger(cantidad) || cantidad <= 0 || stockNuevo > 2147483647) {
      throw Object.assign(new Error('La cantidad del pedido no permite una recepción válida'), { status: 400 });
    }
    await client.query('UPDATE productos SET stock_actual=$1, actualizado_en=NOW() WHERE id=$2', [stockNuevo, producto.id]);
    const { rows: movimientos } = await client.query(`
      INSERT INTO movimientos (producto_id, usuario_id, tipo, cantidad, stock_antes, stock_despues, motivo)
      VALUES ($1,$2,'entrada',$3,$4,$5,$6) RETURNING id
    `, [producto.id, usuarioId, cantidad, producto.stock_actual, stockNuevo, `Recepción del pedido #${id}`]);
    await client.query(`INSERT INTO pedido_recepciones (pedido_id,usuario_id,cantidad,movimiento_id) VALUES ($1,$2,$3,$4)`, [id, usuarioId, cantidad, movimientos[0]?.id ?? null]);
    totalRecibido += cantidad;
    siguiente = totalRecibido === Number(pedido.cantidad_sugerida) ? 'recibido' : 'enviado';
  }

  const { rows } = await client.query(`
    UPDATE pedidos SET estado=$1, actualizado_en=NOW(), cantidad_recibida=$3 WHERE id=$2 RETURNING *
  `, [siguiente, id, totalRecibido]);
  await registrarEvento(client, id, usuarioId, estado === 'recibido' ? 'recepcion' : 'estado', pedido.estado, siguiente, cantidad,
    estado === 'recibido' ? `Recibidas ${cantidad} unidades; acumulado ${totalRecibido} de ${pedido.cantidad_sugerida}` : 'Cambio de estado');
  return rows[0];
}

module.exports = { generarPorFaltantes, actualizarEstado, bloquearPedido, registrarEvento };
