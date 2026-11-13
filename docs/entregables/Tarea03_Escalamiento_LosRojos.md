# TAREA 3: Cálculo de Instancias en Pico y Valle

**Equipo:** Los Rojos  
**Materia:** Cómputo en la Nube - Grupo 503  
**Fecha:** 22 de octubre de 2026  
**Entregable:** Tarea 3 - Análisis de Escalamiento

---

## Pregunta Central

**¿3 o cuántos servidores necesito?**

Respuesta: Depende del patrón de demanda. Necesitamos calcular:
- Usuarios en **pico** (hora de mayor uso)
- Usuarios en **valle** (hora de menor uso)
- Instancias requeridas en cada caso
- Estrategia de escalamiento

---

## 1. Análisis del Patrón de Demanda

### Supuestos del Proyecto (inventario-cloud)

Para una aplicación de gestión de inventario orientada a pequeñas/medianas empresas:

| Período | Hora Típica | Contexto |
|---------|-------------|----------|
| **Valle** | 2:00 - 6:00 AM | Cierre de operaciones, mantenimiento |
| **Pico** | 8:00 - 10:00 AM | Apertura de negocios, ingreso de datos |
| **Pico** | 4:00 - 6:00 PM | Cierre de turno, reconciliación |
| **Mantenimiento** | 11:00 PM - 1:00 AM | Backups, reportes nocturnos |

### Estimación de Usuarios Concurrentes

Basado en patrón típico para aplicación SaaS de inventario:

#### **PERÍODO DE VALLE (2 AM - 6 AM)**

| Métrica | Valor |
|---------|-------|
| Usuarios activos | 5-10 usuarios |
| Concurrentes simultáneamente | 2-3 usuarios |
| Operaciones por segundo (ops/s) | 0.5 - 1 ops/s |
| Tráfico promedio | Bajo (reportes automatizados) |

#### **PERÍODO DE PICO (8 AM - 10 AM y 4 PM - 6 PM)**

| Métrica | Valor |
|---------|-------|
| Usuarios activos | 50-100 usuarios |
| Concurrentes simultáneamente | 20-30 usuarios |
| Operaciones por segundo (ops/s) | 5 - 8 ops/s |
| Tráfico promedio | Alto (consultas + actualizaciones) |

---

## 2. Cálculo de Capacidad por Instancia

### Especificaciones t3.micro (la que usamos)

```
CPU:        1 vCPU (variable, hasta 25% baseline)
RAM:        1 GB
Ancho banda: 5 Mbps (hasta ráfagas de 2.048 Gbps)
IO:         Baseline bajo, burstable
```

### Capacidad Realista por Instancia t3.micro

**Con nginx + aplicación web simple:**

| Parámetro | Capacidad |
|-----------|-----------|
| Conexiones HTTP concurrentes | 100-150 |
| Solicitudes por segundo (RPS) | 20-30 RPS |
| CPU sostenible | ~30-40% |
| Latencia (p95) | 100-200 ms |
| Throughput | ~2-3 Mbps |

**Conclusión:** Una t3.micro puede manejar confortablemente **5-10 usuarios concurrentes** manteniendo latencia < 200ms.

---

## 3. Cálculo de INSTANCIAS EN VALLE

### Escenario Valle: 2-3 Usuarios Concurrentes

```
Usuarios concurrentes:     2-3
Usuarios por instancia:    ~8 (capacidad cómoda)
Margen de seguridad:       20%

Cálculo:
  Instancias = (Usuarios concurrentes / Usuarios por instancia) × (1 + Margen)
  Instancias = (3 / 8) × 1.20
  Instancias = 0.375 × 1.20
  Instancias = 0.45
  
  Redondeado: 1 INSTANCIA MÍNIMO
```

### Justificación Valle

- **1 instancia** es suficiente para 2-3 usuarios concurrentes
- **Margen de 20%** para picos momentáneos o fallos de health check
- **Sin redundancia** de disponibilidad (trade-off de costo aceptable a las 2 AM)
- **Costo:** ~$0.01/hora × 8 horas = $0.08/noche

### Estado en Valle

```
ASG Configuration:
  Min:     1  (mínimo para disponibilidad básica)
  Desired: 1  (actual)
  Max:     4  (para escalamiento rápido en caso de falla)
  
Instancias ejecutando: 1
Costo por hora: $0.0104 (t3.micro)
Costo por noche (8h): $0.08
```

---

## 4. Cálculo de INSTANCIAS EN PICO

### Escenario Pico: 20-30 Usuarios Concurrentes

```
Usuarios concurrentes:     30 (peor caso)
Usuarios por instancia:    ~8 (capacidad cómoda)
Margen de seguridad:       25% (picos son impredecibles)
Factor de redundancia:     1.5× (alta disponibilidad)

Cálculo:
  Instancias = (Usuarios concurrentes / Usuarios por instancia) 
               × (1 + Margen) 
               × (1 + Redundancia)
  
  Instancias = (30 / 8) × 1.25 × 1.5
  Instancias = 3.75 × 1.25 × 1.5
  Instancias = 7.03
  
  Redondeado: 4 INSTANCIAS MÁXIMO (límite ASG)
```

### Justificación Pico

- **30 usuarios** → 3.75 instancias mínimo
- **Margen 25%** para ráfagas de actividad (fin de mes, auditorías)
- **Redundancia 1.5×** para tolerar una falla sin degradación
- **4 instancias** = balance entre capacidad y costo
- **Costo:** $0.0104 × 4 × 2 horas = $0.083 (por turno pico)

### Estado en Pico

```
ASG Configuration:
  Min:     2  (redundancia obligatoria en pico)
  Desired: 4  (anticipar picos)
  Max:     4  (límite de escalamiento)
  
Instancias ejecutando: 4
Costo por hora: $0.0416 (4 × $0.0104)
Costo por período pico (2h × 2 turnos): $0.166/día
```

---

## 5. Tabla Resumen: Valle vs Pico

| Métrica | Valle (2-6 AM) | Pico (8-10 AM, 4-6 PM) |
|---------|-----------------|----------------------|
| **Usuarios concurrentes** | 2-3 | 20-30 |
| **Instancias mínimas** | 1 | 4 |
| **Instancias deseadas** | 1 | 4 |
| **Instancias máximas** | 4 | 4 |
| **Costo/hora** | $0.0104 | $0.0416 |
| **Disponibilidad** | Básica (SLA 95%) | Alta (SLA 99.9%) |
| **Latencia p95** | 100-150 ms | 100-150 ms |
| **Caché de ráfaga CPU** | Completo | Consumiéndose |

---

## 6. Razonamiento Detallado: ¿Por qué estos números?

### ¿Por qué 1 instancia en valle?

1. **Costo:** Ejecutar 2-4 instancias inútiles sería desperdiciar ~$0.02/hora
2. **Demanda real:** 2-3 usuarios no requieren redundancia completa
3. **Health check:** ASG lo reemplaza en 60 segundos si falla
4. **Decisión empresa:** Aceptar SLA 95% (4 horas downtime/mes) en valle

**Fórmula:**
```
Costo anual 1 vs 4 instancias valle:
  1 inst:  0.0104 × 8h × 365 = $30.37/año
  4 inst:  0.0416 × 8h × 365 = $121.47/año
  
Ahorro: $91.10/año (69% más barato)
```

### ¿Por qué 4 instancias en pico?

1. **Capacidad:** 30 usuarios / 8 usuarios/inst = 3.75 → redondeo a 4
2. **Redundancia:** Si falla 1, quedan 3 = 24 usuarios seguido atendidos
3. **Buffer:** 25% para ráfagas = 1 instancia extra de "colchón"
4. **Costo aceptable:** $0.04/hora × 4 horas/día = $0.16/día = $58/año

**Fórmula:**
```
Capacidad garantizada:
  4 instancias × 8 usuarios/inst = 32 usuarios
  - 1 instancia redundancia = 24 usuarios garantizados
  
Casos cubiertos:
  ✔ 30 usuarios normales
  ✔ 24 usuarios si falla 1 instancia
  ✔ Ráfagas de hasta 32 usuarios
  ✔ Health check + escalamiento automático
```

---

## 7. Estrategia de Escalamiento Automático

### Política de CPU Implementada: Umbral 60%

```
Evento              Acción                    Tiempo
──────────────────────────────────────────────────────
CPU > 60% × 2 min   Scale-out (agregar)       +120s cooldown
CPU < 30% × 5 min   Scale-in (reducir)        +300s cooldown
Falla health check  Reemplazar instancia      +60s grace period
```

### Tabla de Escalamiento Automático

| Carga | CPU Promedio | Acción | Resultado |
|-------|-------------|--------|-----------|
| Baja (5 usuarios) | 15% | Nada (min=1) | 1 inst |
| Normal (10 usuarios) | 35% | Nada | 1-2 inst |
| Media (15 usuarios) | 55% | Esperar | 2-3 inst |
| Alta (25 usuarios) | 65% | Scale-out | +1 inst |
| Pico (30 usuarios) | 75% | Scale-out | +1 inst |
| Saturado (35 usuarios) | 85% | Crítico | 4 inst max |

---

## 8. Decisión Final: ¿3 o más servidores?

### Respuesta Completa

**Depende de la hora del día:**

```
┌─────────────────────────────────────────────┐
│  CONFIGURACIÓN AUTOMÁTICA DEL ASG           │
├─────────────────────────────────────────────┤
│  Entre 2 AM - 6 AM (Valle)                  │
│  ├─ Min = 1                                 │
│  ├─ Desired = 1                             │
│  ├─ Max = 4                                 │
│  └─ Resultado: 1 instancia activa           │
│                                             │
│  Entre 8 AM - 10 AM (Pico)                  │
│  ├─ Min = 2                                 │
│  ├─ Desired = 4                             │
│  ├─ Max = 4                                 │
│  └─ Resultado: 4 instancias activas         │
│                                             │
│  Entre 4 PM - 6 PM (Pico)                   │
│  ├─ Min = 2                                 │
│  ├─ Desired = 4                             │
│  ├─ Max = 4                                 │
│  └─ Resultado: 4 instancias activas         │
│                                             │
│  Resto del día (Normal)                     │
│  ├─ Min = 2                                 │
│  ├─ Desired = 2                             │
│  ├─ Max = 4                                 │
│  └─ Resultado: 2 instancias activas         │
└─────────────────────────────────────────────┘
```

### Respuesta Corta

- **3 servidores:** Opción equilibrada (redundancia + costo moderado)
- **Mejor opción:** **4 servidores en pico, 1 en valle** (escalamiento automático)
- **Mínimo recomendado:** 2 servidores (redundancia obligatoria)
- **Máximo práctico:** 4 servidores (rendimientos decrecientes)

---

## 9. Costos Proyectados

### Escenario Valle Automático (1 instancia)

```
Período: 2 AM - 6 AM (4 horas/noche × 30 noches)
  Instancias: 1 t3.micro
  Costo: 0.0104 × 4 × 30 = $1.25/mes (valle)
```

### Escenario Pico Automático (4 instancias)

```
Período: 8-10 AM (2h) + 4-6 PM (2h) = 4 horas/día × 20 días laborales
  Instancias: 4 t3.micro
  Costo: 0.0104 × 4 × 4 × 20 = $3.33/mes (pico)
```

### Costo Total Estimado (ASG Automático)

```
Componente              Costo/mes
────────────────────────────────────
EC2 (t3.micro):         ~$2.50
ALB:                    ~$14.60 (16×24×30h)
Data Transfer:          ~$1.00
────────────────────────────────────
TOTAL:                  ~$18.10/mes

Comparación:
  ✔ Con escalamiento: $18/mes
  ✔ Sin escalamiento (4 siempre): $30/mes
  Ahorro: 40% con ASG
```

---

## 10. Conclusión: Recomendación Final

### Para Inventario-Cloud

**Configuración recomendada: ESCALAMIENTO AUTOMÁTICO**

```
Mínimo:     2 instancias (redundancia obligatoria)
Deseado:    Varía según demanda (1-4)
Máximo:     4 instancias (rendimiento sostenible)
Política:   CPU promedio 60%
Resultado:  Entre 1-4 instancias activas automáticamente
Costo:      ~$18/mes (40% más eficiente que fijo)
```

### Justificación

1. **Capacidad:** 1-4 instancias cubre desde 2 hasta 32 usuarios simultáneos
2. **Costo:** Escalamiento automático ahorra 40% vs. 4 fijas siempre
3. **Confiabilidad:** RTO de 82 segundos ante fallos (demostrado en P08)
4. **Simplicidad:** ASG maneja la lógica automáticamente
5. **Futuro-proof:** Fácil agregar políticas (tiempo, métrica personalizada, etc.)

---

**Documento preparado por:** Equipo Los Rojos  
**Fecha:** 22 de octubre de 2026  
**Referencia:** Para usar en Práctica 09 (Escalamiento Vertical vs Horizontal)
