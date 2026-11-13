/** Compras, recepciones, seguimiento y proveedores. */
const Pedidos = (() => {
  const etiquetas = {pendiente:'⏳ Pendiente',enviado:'📤 Enviado',recibido:'✅ Recibido',cancelado:'❌ Cancelado'};
  const estados = [...Object.keys(etiquetas),'parcial','todos'];
  let estadoActual='pendiente', pagina=1, ultimaCarga=0, visibles=[], generando=false;
  const actualizando=new Set();
  const el=id=>document.getElementById(id);
  const esc=value=>escaparHtml(value);
  const dinero=value=>value===null||value===undefined?'—':Number(value).toLocaleString('es-MX',{style:'currency',currency:'MXN'});
  const fecha=value=>value?new Date(value).toLocaleDateString('es-MX'):'—';
  const permitido=()=>Auth.tieneRol('administrador','bodega');
  function params(estado=estadoActual,page=pagina) {
    const result=new URLSearchParams({estado,page,limit:25});
    for(const [id,key] of [['pedido-buscar','q'],['pedido-desde','desde'],['pedido-hasta','hasta'],['pedido-alerta','alerta']]) {
      const value=el(id)?.value?.trim(); if(value) result.set(key,value);
    }
    return result;
  }
  function renderTabla(pedidos) {
    visibles=pedidos;
    const c=el('tabla-pedidos');
    if(!pedidos.length) {
      c.innerHTML=`<div class="empty-state"><div class="empty-icon">🛒</div><p>${estadoActual==='pendiente'
        ? 'No hay pedidos pendientes con estos filtros. Usa «Generar por faltantes» para revisar reposiciones.'
        : `No hay pedidos con estado "${esc(estadoActual)}" y los filtros seleccionados.`}</p></div>`;
      return;
    }
    c.innerHTML=`<div class="tabla-wrap"><table><thead><tr><th>Pedido / producto</th><th>Stock / mínimo</th><th>Solicitado / recibido</th>
      <th>Proveedor</th><th>Costo unitario / total</th><th>Entrega</th><th>Estado</th><th>Generado</th><th>Acciones</th></tr></thead><tbody>
      ${pedidos.map(p=>{
        const recibidas=Number(p.cantidad_recibida||0), abiertas=['pendiente','enviado'].includes(p.estado);
        return `<tr><td><strong>#${p.id}</strong> <span class="td-code">${esc(p.codigo)}</span><br>${esc(p.producto)}</td>
          <td><span class="${p.stock_actual<=0?'badge-alerta':''}">${p.stock_actual}</span> / ${p.stock_minimo}</td>
          <td>${p.cantidad_sugerida} / ${recibidas}<br><small>Pendientes: ${Number(p.cantidad_sugerida)-recibidas}</small></td>
          <td>${esc(p.proveedor||'Sin asignar')}</td><td>${dinero(p.costo_unitario)} / ${dinero(p.costo_total)}</td>
          <td>${fecha(p.entrega_estimada)}${p.atrasado?'<br><span class="badge-alerta">Atrasado</span>':''}</td>
          <td><span class="badge-${esc(p.estado)}">${etiquetas[p.estado]||esc(p.estado)}</span>${p.estado==='enviado'&&recibidas>0?'<br><small>Recepción parcial</small>':''}</td>
          <td>${fecha(p.generado_en)}</td><td><div class="pedido-acciones">
          <button class="btn-secondary btn-sm" onclick="Pedidos.historial(${p.id})">Historial</button>
          ${abiertas?`<button class="btn-secondary btn-sm" onclick="Pedidos.detalles(${p.id})">Proveedor / costo</button>`:''}
          ${p.estado==='pendiente'?`<button class="btn-primary btn-sm" data-pedido-id="${p.id}" onclick="Pedidos.solicitarCambio(${p.id},'enviado')">Marcar enviado</button>`:''}
          ${p.estado==='enviado'?`<button class="btn-primary btn-sm" data-pedido-id="${p.id}" onclick="Pedidos.solicitarCambio(${p.id},'recibido')">Recibir unidades</button>`:''}
          ${abiertas?`<button class="btn-secondary btn-sm" data-pedido-id="${p.id}" onclick="Pedidos.solicitarCambio(${p.id},'cancelado')">Cancelar</button>`:''}
          </div></td></tr>`;
      }).join('')}</tbody></table></div>`;
  }
  async function cargar(estado=estadoActual,page=1) {
    if(!permitido()) return;
    if(!estados.includes(estado)) estado='pendiente';
    const desde=el('pedido-desde')?.value,hasta=el('pedido-hasta')?.value;
    if(desde&&hasta&&desde>hasta) {Toast.error('La fecha inicial debe ser anterior o igual a la final.');return;}
    estadoActual=estado;pagina=page;
    if(el('filtro-estado-pedido')) el('filtro-estado-pedido').value=estado;
    const carga=++ultimaCarga;
    if(!el('tabla-pedidos')) return;
    mostrarCargando('tabla-pedidos','Cargando pedidos…');
    try {
      const data=await api.get(`/reportes/pedidos?${params(estado,page)}`);
      if(carga!==ultimaCarga) return;
      if(page>1&&!data.pedidos.length&&data.total>0) return cargar(estado,Math.max(1,data.paginas));
      renderTabla(data.pedidos);
      const pag=el('paginacion-pedidos');
      if(pag) pag.innerHTML=`<span>${data.total} pedidos · Página ${page} de ${Math.max(1,data.paginas||1)}</span>
        <button ${page===1?'disabled':''} onclick="Pedidos.irPagina(${page-1})">Anterior</button>
        <button ${page>=(data.paginas||1)?'disabled':''} onclick="Pedidos.irPagina(${page+1})">Siguiente</button>`;
      if(estado==='pendiente'&&el('nav-badge-pedidos')&&!el('pedido-buscar')?.value&&!el('pedido-alerta')?.value&&!desde&&!hasta) {
        el('nav-badge-pedidos').textContent=data.total;el('nav-badge-pedidos').classList.toggle('visible',data.total>0);
      }
    }catch(err){if(carga===ultimaCarga) el('tabla-pedidos').innerHTML=`<div class="empty-state"><p>${esc(err.message)}</p></div>`;}
  }
  async function cargarAlertas() {
    if(!permitido()||!el('pedido-alertas')) return;
    try {
      const a=await api.get('/reportes/pedidos/alertas');
      el('pedido-alertas').innerHTML=`<button class="pedido-alerta ${a.agotados?'urgente':''}" onclick="Pedidos.faltantes('agotados')">Agotados <strong>${a.agotados||0}</strong></button>
        <button class="pedido-alerta ${a.sin_pedido?'urgente':''}" onclick="Pedidos.faltantes('sin_pedido')">Faltantes sin pedido <strong>${a.sin_pedido||0}</strong></button>
        <button class="pedido-alerta ${a.atrasados?'urgente':''}" onclick="Pedidos.filtrarAlerta('atrasado')">Entregas atrasadas <strong>${a.atrasados||0}</strong></button>
        <button class="pedido-alerta" onclick="Pedidos.cargar('parcial')">Recepciones parciales <strong>${a.parciales||0}</strong></button>`;
    }catch(err){el('pedido-alertas').textContent='No se pudieron cargar las alertas: '+err.message;}
  }
  async function refrescar() {await cargar(estadoActual,pagina);await cargarAlertas();await Dashboard.cargar();}
  async function cambiarEstado(id,estado) {
    if(!permitido()||actualizando.has(id)) return;
    actualizando.add(id);
    document.querySelectorAll(`[data-pedido-id="${id}"]`).forEach(b=>{b.disabled=true;});
    try {await api.patch(`/reportes/pedidos/${id}`,{estado});Toast.success(`Pedido marcado como "${estado}"`);await refrescar();}
    catch(err){Toast.error(err.message);}
    finally{actualizando.delete(id);document.querySelectorAll(`[data-pedido-id="${id}"]`).forEach(b=>{b.disabled=false;});}
  }
  function solicitarCambio(id,estado) {
    const p=visibles.find(p=>p.id===id);
    if(!p||actualizando.has(id)||!permitido()) return;
    if(!['recibido','cancelado'].includes(estado)) return cambiarEstado(id,estado);
    if(estado==='recibido') return recibir(p);
    Modal.abrir(`<div class="confirm-dialog"><p>Se cancelará el pedido #${id}. Las unidades ya recibidas permanecerán en inventario.</p>
      <div class="confirm-actions"><button class="btn-secondary" onclick="Modal.cerrar()">Volver</button>
      <button class="btn-primary" id="btn-confirmar-pedido">Confirmar cancelación</button></div></div>`,'Cancelar pedido');
    el('btn-confirmar-pedido').onclick=()=>{Modal.cerrar();cambiarEstado(id,estado);};
  }
  function recibir(p) {
    const recibidas=Number(p.cantidad_recibida||0),restantes=Number(p.cantidad_sugerida)-recibidas;
    Modal.abrir(`<div class="form-modal"><p>${esc(p.producto)} · Recibidas ${recibidas} de ${p.cantidad_sugerida}.</p>
      <p>Se registrará una entrada de hasta <strong>${restantes}</strong> unidades. Elige la cantidad que llegó realmente.</p>
      <label>Unidades recibidas<input id="pedido-cantidad-recibir" type="number" min="1" max="${restantes}" step="1" value="${restantes}" /></label>
      <p id="pedido-recepcion-error" class="error-msg hidden" role="alert"></p><div class="form-actions">
      <button class="btn-secondary" onclick="Modal.cerrar()">Volver</button><button class="btn-primary" id="btn-confirmar-pedido">Confirmar recepción</button></div></div>`,`Recibir pedido #${p.id}`);
    el('btn-confirmar-pedido').onclick=async e=>{
      if(actualizando.has(p.id)) return;
      const cantidad=Number(el('pedido-cantidad-recibir').value),error=el('pedido-recepcion-error'),btn=e.currentTarget;
      if(!Number.isInteger(cantidad)||cantidad<1||cantidad>restantes){error.textContent=`Indica entre 1 y ${restantes} unidades enteras.`;error.classList.remove('hidden');return;}
      actualizando.add(p.id);btn.disabled=true;
      try{await api.post(`/compras/pedidos/${p.id}/recepciones`,{cantidad,cantidad_recibida_esperada:recibidas});Modal.cerrar();Toast.success(`Entrada registrada: ${cantidad} unidades`);await refrescar();}
      catch(err){error.textContent=err.message;error.classList.remove('hidden');btn.disabled=false;}
      finally{actualizando.delete(p.id);}
    };
  }
  async function generar() {
    if(generando||!permitido()) return;generando=true;
    const btn=el('btn-generar-pedidos');if(btn){btn.disabled=true;btn.textContent='Revisando faltantes…';}
    try{const {generados}=await api.post('/reportes/pedidos/generar',{});
      if(generados) Toast.success(`Pedidos generados: ${generados}`);else Toast.info('No hay faltantes sin un pedido pendiente o enviado.');
      limpiar(false);estadoActual='pendiente';pagina=1;await refrescar();
    }catch(err){Toast.error(err.message);}finally{generando=false;if(btn){btn.disabled=false;btn.textContent='＋ Generar por faltantes';}}
  }
  async function historial(id) {
    try{const {eventos}=await api.get(`/compras/pedidos/${id}/historial`);
      Modal.abrir(`<div class="pedido-historial">${eventos.length?eventos.map(e=>`<article><strong>${esc(e.tipo)} · ${esc(e.usuario||'Sistema / registro anterior')}</strong>
        <small>${esc(new Date(e.creado_en).toLocaleString('es-MX'))}</small><p>${esc(e.detalle)}</p>
        ${e.estado_nuevo?`<p>${esc(e.estado_anterior||'Inicio')} → ${esc(e.estado_nuevo)}</p>`:''}</article>`).join(''):'<p>No hay eventos disponibles.</p>'}</div>`,`Historial del pedido #${id}`);
    }catch(err){Toast.error(err.message);}
  }
  async function detalles(id) {
    const p=visibles.find(p=>p.id===id);if(!p) return;
    try{const proveedores=await api.get('/compras/proveedores');
      Modal.abrir(`<div class="form-modal"><label>Proveedor<select id="pedido-proveedor"><option value="">Sin asignar</option>
        ${proveedores.filter(v=>v.activo||v.id===p.proveedor_id).map(v=>`<option value="${v.id}" ${v.id===p.proveedor_id?'selected':''} ${!v.activo?'disabled':''}>${esc(v.nombre)}${!v.activo?' (inactivo)':''}</option>`).join('')}</select></label>
        <label>Costo unitario (MXN)<input id="pedido-costo" type="number" min="0" step="0.01" max="999999999.99" value="${esc(p.costo_unitario??'')}" /></label>
        <label>Entrega estimada<input id="pedido-entrega" type="date" value="${p.entrega_estimada?new Date(p.entrega_estimada).toISOString().slice(0,10):''}" /></label>
        <p id="pedido-detalle-error" class="error-msg hidden" role="alert"></p><div class="form-actions"><button class="btn-secondary" onclick="Modal.cerrar()">Volver</button>
        <button class="btn-primary" id="pedido-guardar-detalle">Guardar</button></div></div>`,`Datos del pedido #${id}`);
      el('pedido-guardar-detalle').onclick=async e=>{
        const btn=e.currentTarget;btn.disabled=true;
        try{await api.patch(`/compras/pedidos/${id}/detalles`,{proveedor_id:el('pedido-proveedor').value?Number(el('pedido-proveedor').value):null,
          costo_unitario:el('pedido-costo').value||null,entrega_estimada:el('pedido-entrega').value||null});Modal.cerrar();Toast.success('Datos de compra guardados');await refrescar();}
        catch(err){el('pedido-detalle-error').textContent=err.message;el('pedido-detalle-error').classList.remove('hidden');btn.disabled=false;}
      };
    }catch(err){Toast.error(err.message);}
  }
  async function proveedores() {
    try{const lista=await api.get('/compras/proveedores');
      Modal.abrir(`<div class="form-modal"><button class="btn-primary" onclick="Pedidos.editarProveedor()">＋ Nuevo proveedor</button><div class="pedido-historial">
        ${lista.map(p=>`<article><strong>${esc(p.nombre)} ${!p.activo?'(inactivo)':''}</strong><p>${esc(p.contacto)} · ${esc(p.correo)} · ${esc(p.telefono)}</p>
        <button class="btn-secondary btn-sm" id="proveedor-editar-${p.id}">Editar</button></article>`).join('')||'<p>Aún no hay proveedores.</p>'}</div></div>`,'Proveedores');
      lista.forEach(p=>{el(`proveedor-editar-${p.id}`).onclick=()=>editarProveedor(p);});
    }catch(err){Toast.error(err.message);}
  }
  function editarProveedor(p={}) {
    Modal.abrir(`<div class="form-modal">${[['nombre','Nombre',150],['contacto','Contacto',150],['correo','Correo',150],['telefono','Teléfono',50]].map(([k,label,max])=>
      `<label>${label}<input id="proveedor-${k}" type="${k==='correo'?'email':'text'}" maxlength="${max}" value="${esc(p[k]||'')}" ${k==='nombre'?'required':''} /></label>`).join('')}
      <label>Estado<select id="proveedor-activo"><option value="true" ${p.activo!==false?'selected':''}>Activo</option><option value="false" ${p.activo===false?'selected':''}>Inactivo</option></select></label>
      <p id="proveedor-error" class="error-msg hidden" role="alert"></p><div class="form-actions"><button class="btn-secondary" onclick="Pedidos.proveedores()">Volver</button>
      <button class="btn-primary" id="proveedor-guardar">Guardar proveedor</button></div></div>`,p.id?'Editar proveedor':'Nuevo proveedor');
    el('proveedor-guardar').onclick=async e=>{
      const btn=e.currentTarget;btn.disabled=true;
      const data=Object.fromEntries(['nombre','contacto','correo','telefono'].map(k=>[k,el('proveedor-'+k).value.trim()]));data.activo=el('proveedor-activo').value==='true';
      try{if(p.id) await api.put('/compras/proveedores/'+p.id,data);else await api.post('/compras/proveedores',data);Toast.success('Proveedor guardado');await proveedores();}
      catch(err){el('proveedor-error').textContent=err.message;el('proveedor-error').classList.remove('hidden');btn.disabled=false;}
    };
  }
  async function faltantes(alerta) {
    try{const {productos}=await api.get('/reportes/pedidos/faltantes?alerta='+alerta);
      Modal.abrir(`<div class="pedido-historial">${productos.map(p=>`<article><strong>${esc(p.codigo)} · ${esc(p.nombre)}</strong><p>Stock: ${p.stock_actual} · Mínimo: ${p.stock_minimo}</p></article>`).join('')||'<p>No hay productos con esta alerta.</p>'}</div>
        <p>Se muestran hasta 200 productos.</p><button class="btn-primary" id="alerta-generar-pedidos">Generar pedidos por faltantes</button>`,alerta==='agotados'?'Productos agotados':'Faltantes sin pedido');
      el('alerta-generar-pedidos').onclick=()=>{Modal.cerrar();generar();};
    }catch(err){Toast.error(err.message);}
  }
  async function exportar() {
    try{const blob=await api.blob(`/reportes/export/pedidos?${params()}`);const url=URL.createObjectURL(blob),a=document.createElement('a');
      a.href=url;a.download='pedidos.csv';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);Toast.success('Pedidos exportados');
    }catch(err){Toast.error(err.message);}
  }
  function limpiar(cargarAhora=true){for(const id of ['pedido-buscar','pedido-desde','pedido-hasta','pedido-alerta'])if(el(id))el(id).value='';if(cargarAhora)cargar('pendiente');}
  function filtrarAlerta(alerta){limpiar(false);el('pedido-alerta').value=alerta;cargar('todos');}
  return {cargar,cargarAlertas,cambiarEstado,solicitarCambio,generar,historial,detalles,proveedores,editarProveedor,faltantes,exportar,limpiar,filtrarAlerta,irPagina:p=>cargar(estadoActual,p)};
})();
