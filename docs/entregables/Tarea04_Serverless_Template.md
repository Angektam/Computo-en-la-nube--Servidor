# TAREA 4: Funcionalidades Serverless para Inventario-Cloud

**Equipo:** Los Rojos | **Entrega:** Lunes 26 de octubre de 2026  
**Formato:** Individual, media cuartilla (a mano o digital)

---

## Objetivo

Identificar **3 funcionalidades** del proyecto de inventario que sean:
- **Breves:** se ejecutan en segundos
- **Esporádicas:** no continuamente activas
- **Disparadas por eventos:** no por horario fijo

Para cada una indicar:
1. **Funcionalidad**
2. **Evento que la dispara**
3. **Tiempo estimado**
4. **Servicio AWS** recomendado

---

## Ejemplo Completo (No usar, es solo referencia)

### Funcionalidad 1: Generación de Reporte Nocturno
- **Evento:** Horario 11 PM (EventBridge cron)
- **Acción:** Lambda comprime logs del día, guarda en S3
- **Tiempo:** 30 segundos
- **Servicio:** AWS Lambda + S3 + EventBridge

---

## Tu Tarea (Completa con 3 funcionalidades reales de inventario-cloud)

### Funcionalidad 1: 
- **Evento:** 
- **Acción:** 
- **Tiempo:** 
- **Servicio:** 

### Funcionalidad 2:
- **Evento:** 
- **Acción:** 
- **Tiempo:** 
- **Servicio:** 

### Funcionalidad 3:
- **Evento:** 
- **Acción:** 
- **Tiempo:** 
- **Servicio:** 

---

## Criterios de Evaluación

✔ Las 3 funcionalidades son del proyecto inventario-cloud  
✔ Cada evento es realista y específico  
✔ Los tiempos estimados son creíbles (< 5 min)  
✔ Son procesos **breves y esporádicos**, no continuos  
✔ Formato: media cuartilla máximo  
✔ Claridad en la redacción

---

## Sugerencias de Funcionalidades (Elige 3 distintas)

- Envío de alertas (stock bajo, producto vencido)
- Generación de reportes (diario, semanal)
- Validación de datos (integridad, duplicados)
- Limpieza de datos (archivos temporales, sesiones expiradas)
- Procesamiento de imágenes (thumbnails de productos)
- Sincronización (con API externa, backup)
- Notificaciones por email/SMS (pedidos, cambios)
- Cálculos pesados (proyecciones, análisis)

---

## Entrega

- **Formato:** .docx, .pdf, o foto legible a mano
- **Envío:** Por correo antes del lunes 26, 11:59 PM
- **Asunto:** "Tarea 4 - Serverless - [Tu Nombre]"
- **Nombre archivo:** Tarea04_Serverless_[TuNombre].docx

---

**Nota:** Esta es una tarea individual. Cada miembro del equipo entrega su versión.
