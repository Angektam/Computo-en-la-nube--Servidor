const router = require('express').Router();
const pool = require('../db/connection');
const { verificarToken, permitirRoles } = require('../middleware/auth.middleware');
const { esEnteroPositivo } = require('../middleware/validation.middleware');
const { actualizarEstado, bloquearPedido, registrarEvento } = require('../services/pedidos.service');
router.use(verificarToken, permitirRoles('administrador', 'bodega'));
const bad = message => Object.assign(new Error(message), { status: 400 });
router.param('id', (_req,res,next,id) => esEnteroPositivo(id) ? next() : res.status(400).json({error:'ID inválido'}));

async function transaccion(res, next, fn) {
  let client;
  try {
    client=await pool.connect(); await client.query('BEGIN');
    const result=await fn(client); await client.query('COMMIT'); res.json(result);
  } catch(err) { if(client) await client.query('ROLLBACK'); next(err); }
  finally { if(client) client.release(); }
}

function datosProveedor(body) {
  const data={};
  for(const [key,max] of [['nombre',150],['contacto',150],['correo',150],['telefono',50]]) {
    if(body[key]!==undefined && typeof body[key]!=='string') throw bad(`${key} debe ser texto`);
    data[key]=(body[key]||'').trim();
    if(data[key].length>max) throw bad(`${key} supera ${max} caracteres`);
  }
  if(!data.nombre) throw bad('El nombre del proveedor es obligatorio');
  if(data.correo && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.correo)) throw bad('Correo del proveedor inválido');
  if(body.activo!==undefined && typeof body.activo!=='boolean') throw bad('Estado de proveedor inválido');
  return {...data,activo:body.activo??true};
}

router.get('/proveedores', async (_req,res,next)=>{
  try { const {rows}=await pool.query('SELECT * FROM proveedores ORDER BY activo DESC,nombre,id'); res.json(rows); } catch(err){next(err);}
});
router.post('/proveedores', async (req,res,next)=>{
  try {
    const d=datosProveedor(req.body);
    const {rows}=await pool.query('INSERT INTO proveedores(nombre,contacto,correo,telefono,activo) VALUES($1,$2,$3,$4,$5) RETURNING *',[d.nombre,d.contacto,d.correo,d.telefono,d.activo]);
    res.status(201).json(rows[0]);
  }catch(err){ if(err.code==='23505') return res.status(409).json({error:'Ya existe un proveedor con ese nombre'}); next(err); }
});
router.put('/proveedores/:id', async (req,res,next)=>{
  try {
    const d=datosProveedor(req.body);
    const {rows}=await pool.query('UPDATE proveedores SET nombre=$1,contacto=$2,correo=$3,telefono=$4,activo=$5 WHERE id=$6 RETURNING *',[d.nombre,d.contacto,d.correo,d.telefono,d.activo,req.params.id]);
    if(!rows[0]) return res.status(404).json({error:'Proveedor no encontrado'}); res.json(rows[0]);
  }catch(err){ if(err.code==='23505') return res.status(409).json({error:'Ya existe un proveedor con ese nombre'}); next(err); }
});
router.get('/pedidos/:id/historial',async(req,res,next)=>{
  try {
    const {rows:pedidos}=await pool.query('SELECT id FROM pedidos WHERE id=$1',[req.params.id]);
    if(!pedidos[0]) return res.status(404).json({error:'Pedido no encontrado'});
    const {rows}=await pool.query(`SELECT e.*,u.nombre AS usuario FROM pedido_eventos e LEFT JOIN usuarios u ON u.id=e.usuario_id
      WHERE e.pedido_id=$1 ORDER BY e.creado_en,e.id LIMIT 1000`,[req.params.id]);
    res.json({eventos:rows});
  }catch(err){next(err);}
});
router.post('/pedidos/:id/recepciones', async(req,res,next)=>{
  const cantidad=req.body.cantidad, esperada=req.body.cantidad_recibida_esperada;
  if(!Number.isInteger(cantidad)||cantidad<=0||cantidad>2147483647||!Number.isInteger(esperada)||esperada<0) {
    return res.status(400).json({error:'La cantidad debe ser un entero positivo y el acumulado esperado debe ser válido'});
  }
  await transaccion(res,next,client=>actualizarEstado(client,req.params.id,'recibido',req.usuario.id,{cantidad,esperada}));
});
router.patch('/pedidos/:id/detalles',async(req,res,next)=>{
  await transaccion(res,next,async client=>{
    const {pedido}=await bloquearPedido(client,req.params.id);
    if(!['pendiente','enviado'].includes(pedido.estado)) throw Object.assign(new Error('El pedido está cerrado y ya no admite cambios'),{status:409});
    const {proveedor_id=null,costo_unitario=null,entrega_estimada=null}=req.body;
    if(proveedor_id!==null && !esEnteroPositivo(String(proveedor_id))) throw bad('Proveedor inválido');
    if(costo_unitario!==null && !/^\d{1,9}(\.\d{1,2})?$/.test(String(costo_unitario))) throw bad('El costo debe ser positivo o cero, con máximo dos decimales');
    if(entrega_estimada!==null) {
      if(typeof entrega_estimada!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(entrega_estimada)) throw bad('Fecha de entrega inválida');
      const date=new Date(entrega_estimada+'T00:00:00Z');
      if(Number.isNaN(date.getTime())||date.toISOString().slice(0,10)!==entrega_estimada) throw bad('Fecha de entrega inválida');
    }
    if(proveedor_id!==null) {
      const {rows}=await client.query('SELECT id FROM proveedores WHERE id=$1 AND activo=TRUE FOR KEY SHARE',[proveedor_id]);
      if(!rows[0]) throw bad('Selecciona un proveedor activo');
    }
    const {rows}=await client.query('UPDATE pedidos SET proveedor_id=$1,costo_unitario=$2,entrega_estimada=$3,actualizado_en=NOW() WHERE id=$4 RETURNING *',[proveedor_id,costo_unitario,entrega_estimada,req.params.id]);
    await registrarEvento(client,req.params.id,req.usuario.id,'detalles',pedido.estado,pedido.estado,null,
      JSON.stringify({antes:{proveedor_id:pedido.proveedor_id,costo_unitario:pedido.costo_unitario,entrega_estimada:pedido.entrega_estimada},despues:{proveedor_id,costo_unitario,entrega_estimada}}));
    return rows[0];
  });
});
module.exports=router;
