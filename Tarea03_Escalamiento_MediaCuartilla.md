# TAREA 3: Instancias en Pico y Valle

**Equipo:** Los Rojos | **Fecha:** 22 de octubre de 2026

---

## ¿Cuántos servidores necesito?

### VALLE (2 AM - 6 AM): 1 Instancia

**Demanda:** 2-3 usuarios concurrentes

**Cálculo:**
- Capacidad t3.micro: 8 usuarios cómodos por instancia
- Usuarios / Capacidad = 3 / 8 = 0.375
- Con margen 20%: 0.375 × 1.2 = 0.45 → **1 instancia mínimo**

**Justificación:** A las 2 AM hay pocos usuarios. Una sola instancia maneja la demanda. El health check la reemplaza en 60 segundos si falla. Aceptamos SLA 95% (downtime aceptable). **Costo: $0.01/hora.**

---

### PICO (8-10 AM, 4-6 PM): 4 Instancias

**Demanda:** 20-30 usuarios concurrentes

**Cálculo:**
- Usuarios / Capacidad = 30 / 8 = 3.75 instancias mínimo
- Margen 25% para ráfagas: 3.75 × 1.25 = 4.68
- Factor redundancia 1.5×: 3.75 × 1.25 × 1.5 = 7.03 → **4 máximo (ASG limit)**

**Justificación:** En pico hay 30 usuarios. 4 instancias = 32 usuarios máximo. Si falla 1, quedan 3 = 24 usuarios servidos. La 4ª es colchón para ráfagas. **Costo: $0.04/hora** (4 × $0.01).

---

## Resumen: Escalamiento Automático

| Período | Usuarios | Instancias | Costo/hora |
|---------|----------|-----------|-----------|
| **Valle** | 2-3 | 1 | $0.01 |
| **Normal** | 10 | 2 | $0.02 |
| **Pico** | 30 | 4 | $0.04 |

---

## Regla de Escalamiento

```
CPU Promedio > 60% → agregar instancia (cooldown 120s)
CPU Promedio < 30% → quitar instancia (cooldown 300s)
Min: 2 (redundancia)  |  Desired: varía  |  Max: 4
```

---

## Respuesta Final

**¿3 o cuántos?** 

→ **Entre 1 y 4, automáticamente.** El ASG escala según demanda real:
- 1 en valle (costo mínimo)
- 2-4 en pico (capacidad máxima)

**Beneficio:** 40% más barato que mantener 4 siempre.

**Costo estimado:** ~$18/mes (EC2 + ALB)
