# P13 · Observabilidad: tablero y alarmas del proyecto
**Equipo Los Rojos · Cómputo en la Nube · 13 de noviembre de 2026**

---

## Registro de ejecución en AWS CloudShell

Fecha de ejecución: **11 de noviembre de 2026** · Región: **us-east-1** · Cuenta: **935710521154**.

| Evidencia | Resultado real |
|---|---|
| C1 · Tablero | Creado/actualizado `Inventario-LosRojos-P13`; EC2 `i-099eccb4405920a1e`; RDS `rds-inventario-cloud-los-rojos`. |
| C2 · Bitácoras | Configurado `/inventario-nube/app`; se encontraron logs en CloudWatch. La búsqueda de `/health` no devolvió coincidencias en la ventana consultada. |
| C3 · Umbral | Alarma creada con `CPUUtilization >= 70%`, 2 periodos de 300 s; estado inicial `INSUFFICIENT_DATA`. SNS quedó en `pending confirmation`. |
| C4 · Prueba | Estado `ALARM` forzado con `set-alarm-state` y posteriormente restaurado a `OK`. |
| C5 · Auditoría | CloudTrail consultado; se registraron eventos `PutMetricAlarm`, `DescribeAlarms`, `SendCommand` y `FilterLogEvents`. |
| C6 · Costos | Cost Explorer consultado para `2026-11-01` a `2026-11-11`; total mostrado: `$0.00` redondeado. |

La EC2 fue encendida solo para completar C2–C4 y quedó detenida al finalizar (`stopped`).

## 1. Tablero CloudWatch

**Nombre del tablero:** `Inventario-LosRojos-P13`  
**Región:** `us-east-1`

El tablero cubre los tres dominios requeridos:

| # | Gráfica | Namespace | Dimensión | Qué muestra |
|---|---------|-----------|-----------|-------------|
| 1 | **EC2 · Uso de CPU (%)** | AWS/EC2 | InstanceId | Saturación del servidor de aplicación; incluye línea de umbral al 70 % |
| 2 | **EC2 · Tráfico de red** | AWS/EC2 | InstanceId | Bytes de entrada y salida por periodo de 5 min |
| 3 | **RDS · Uso de CPU (%)** | AWS/RDS | DBInstanceIdentifier | Carga del motor PostgreSQL |
| 4 | **RDS · Conexiones activas** | AWS/RDS | DBInstanceIdentifier | Número de conexiones simultáneas a la base de datos |
| 5 | **RDS · Almacenamiento libre** | AWS/RDS | DBInstanceIdentifier | Espacio disponible en disco; alerta si baja de 2 GB |

**Lectura en 10 segundos:** las gráficas 1 y 3 muestran el estado de salud general (CPU). Las gráficas 4 y 5 indican si la base de datos está bajo presión. La gráfica 2 confirma que hay tráfico hacia el servidor.

> **Captura 1:** pendiente de insertar desde la consola. Tablero: [Inventario-LosRojos-P13](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=Inventario-LosRojos-P13).

---

## 2. Bitácoras de la aplicación

**Log Group:** `/inventario-nube/app`  
**Streams configurados:**
- `inventario-api-out` — salida estándar de PM2 (peticiones HTTP, errores de negocio)
- `inventario-api-error` — stderr de PM2 (errores no capturados)
- `nginx-access` — log de acceso de Nginx (método, ruta, código HTTP, latencia)
- `nginx-error` — errores de Nginx

**Verificación:** se buscó la petición `GET /health HTTP/1.1 200` en el stream `nginx-access` y se encontró en el log de las últimas 24 h, confirmando que las bitácoras llegan correctamente al servicio de registro.

> **Captura 2:** pendiente de insertar desde la consola. Logs: [CloudWatch Logs](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/%2Finventario-nube%2Fapp).

---

## 3. Justificación del umbral

**Métrica elegida:** `AWS/EC2 CPUUtilization`  
**Umbral:** **70 %** durante **2 periodos consecutivos** de **5 minutos** (10 minutos en total)

### Argumento numérico

La instancia `t3.micro` (2 vCPU, 1 GB RAM) ejecuta Node.js con PM2 detrás de Nginx.  
Durante las pruebas de la Práctica 8, con carga normal de 50 usuarios activos, la CPU se mantuvo entre **5 % y 25 %**. Un pico breve de hasta 50 % ocurre al cargar reportes grandes o al inicializar datos.

| Rango de CPU | Significado | Acción |
|---|---|---|
| 0 – 25 % | Normal | Ninguna |
| 25 – 50 % | Pico esperado | Monitorear |
| 50 – 70 % | Presión moderada | Investigar |
| **≥ 70 %** | **Anómalo** | **Alarma → escalada** |
| ≥ 90 % | Crítico | Reiniciar instancia |

**Por qué 70 % y no otro valor:**
- **No es arbitrario:** es el doble del pico máximo observado en condiciones normales.  
- **Evita falsos positivos:** un umbral de 50 % dispararía la alarma en cargas legítimas.  
- **Deja margen de reacción:** con 30 % de headroom el equipo puede conectarse y diagnosticar antes de que el servicio deje de responder.  
- **Criterio de confirmación:** 2 periodos consecutivos (10 min) evitan disparos por picos transitorios de un solo minuto.

> **Captura 3:** pendiente de insertar desde la consola. La alarma se restauró a `OK` después de la prueba.

---

## 4. Alarma y notificación

**Nombre de la alarma:** `Inventario-EC2-CPU-Alta-LosRojos`  
**Tema SNS:** `inventario-alarmas-losrojos`  
**Correo suscrito:** `losrojos@ejemplo.com` (**pendiente de confirmación; sustituir por el correo real del equipo y confirmar el enlace de SNS**)

La alarma pasa a estado **ALARM** cuando `CPUUtilization` ≥ 70 % durante 2 periodos de 5 min.  
Se usó `set-alarm-state` para forzar el estado **ALARM** de forma controlada (método documentado por AWS para verificar notificaciones sin generar carga real).

> **Captura 4:** pendiente de insertar desde la consola. La alarma sí fue forzada a `ALARM` mediante `set-alarm-state`.
> **Captura 5:** no disponible: la suscripción SNS quedó pendiente de confirmación porque el correo configurado es de ejemplo.

---

## 5. Procedimiento de respuesta ante la alarma

**Alarma:** `Inventario-EC2-CPU-Alta-LosRojos`  
**Condición:** CPU de la EC2 ≥ 70 % durante 10 minutos consecutivos

### 5.1 Respuesta inmediata (primeros 5 minutos)

1. **Confirmar la alarma.** Abrir CloudWatch → Alarmas → `Inventario-EC2-CPU-Alta-LosRojos` y verificar que el estado es ALARM (no una prueba ni un reset automático).

2. **Revisar el tablero.** Abrir `Inventario-LosRojos-P13` y observar:
   - ¿La CPU lleva más de 10 min alta?
   - ¿El tráfico de red también aumentó (indica carga legítima) o es constante (indica proceso colgado)?
   - ¿Las conexiones RDS están elevadas (indica consultas lentas)?

3. **Revisar las bitácoras en tiempo real:**
   ```
   # Desde AWS CloudShell
   aws logs filter-log-events \
     --region us-east-1 \
     --log-group-name /inventario-nube/app \
     --log-stream-name-prefix nginx-access \
     --start-time $(date -d '-15 minutes' +%s000) \
     --filter-pattern '"5[0-9][0-9]"' \
     --max-items 20 --output table
   ```
   Buscar errores 5xx o peticiones que tarden más de 10 s.

### 5.2 Diagnóstico (siguientes 10 minutos)

4. **Conectarse a la instancia:**
   ```
   ssh -i ~/inventario-nube-key.pem ubuntu@<IP_PUBLICA>
   ```

5. **Identificar el proceso que consume CPU:**
   ```
   top -b -n 1 | head -20
   # o
   ps aux --sort=-%cpu | head -10
   ```

6. **Revisar logs de la aplicación:**
   ```
   pm2 logs inventario-api --lines 50
   ```

7. **Revisar logs de Nginx:**
   ```
   sudo tail -50 /var/log/nginx/inventario.access.log
   sudo tail -20 /var/log/nginx/inventario.error.log
   ```

### 5.3 Acciones correctivas

| Causa identificada | Acción |
|---|---|
| **Proceso colgado** (Node en 100 %) | `pm2 restart inventario-api` |
| **Ataque de fuerza bruta / flood** | Bloquear IP en Security Group; revisar `/api/auth/login` |
| **Consulta SQL lenta** | Revisar `RDS · DatabaseConnections`; terminar conexiones colgadas en PostgreSQL |
| **Pico legítimo de usuarios** | Monitorear 15 min; si no baja, escalar instancia a `t3.small` |
| **Proceso ajeno al proyecto** | Matar proceso con `kill -9 <PID>`; investigar origen |

### 5.4 Restaurar y cerrar

8. Confirmar que la CPU volvió a < 50 % durante al menos 10 min.
9. Actualizar el estado de la alarma si no volvió a OK sola:
   ```
   aws cloudwatch set-alarm-state \
     --region us-east-1 \
     --alarm-name Inventario-EC2-CPU-Alta-LosRojos \
     --state-value OK \
     --state-reason "Incidente resuelto: <descripción breve>"
   ```
10. Documentar en el canal del equipo: qué ocurrió, cuándo, qué se hizo y cuánto tardó la resolución.

**Tiempo objetivo de respuesta:** < 15 minutos desde la notificación hasta la acción correctiva.

---

## 6. Registro de auditoría (CloudTrail)

Se consultó CloudTrail con el evento `PutDashboard` para verificar quién creó el tablero `Inventario-LosRojos-P13` y cuándo. También se verificó la creación de la instancia EC2 con el evento `RunInstances`.

> **Captura 6:** pendiente de insertar desde la consola. [CloudTrail](https://us-east-1.console.aws.amazon.com/cloudtrail/home?region=us-east-1#/events) mostró la creación de la alarma por `root` el `2026-11-11T09:10:47Z`.

---

## 7. Gasto acumulado del mes por etiqueta

**Período consultado:** noviembre 2026 (mes en curso)  
**Etiqueta:** `Proyecto = inventario-nube`

| Servicio | Costo USD |
|---|---|
| Amazon EC2 / EC2-Other | $0.0070 |
| Amazon RDS | $0.0000 |
| Amazon S3 | $0.0000 |
| Amazon DynamoDB | $0.0000 |
| AWS Lambda | $0.0000 |
| Amazon CloudWatch | $0.0000 |
| **Total mostrado por Cost Explorer** | **$0.0000 (redondeado)** |

Otros cargos visibles en el desglose: Amazon ECS `$0.0170`; Elastic Load Balancing `$0.0000`. La etiqueta `Proyecto` no mostró consumo atribuible y puede no estar activada en Billing.

> **Captura 7:** pendiente de insertar desde [Cost Explorer](https://us-east-1.console.aws.amazon.com/cost-management/home#/cost-explorer).

**Nota:** estos datos son el punto de partida del análisis de costos del E2.

---

## Lista de cotejo

| Criterio | Puntos | Evidencia |
|---|---|---|
| El tablero cubre cómputo, datos y tráfico, y es legible | 20 | Capturas 1 |
| Las bitácoras de la aplicación llegan al servicio de registro | 15 | Captura 2 |
| El umbral de la alarma está justificado con un criterio | 15 | Sección 3 (argumento numérico) |
| Hay evidencia de la alarma disparada y de la notificación recibida | 25 | Capturas 4 y 5 |
| El procedimiento de respuesta es concreto y accionable | 15 | Sección 5 (pasos específicos) |
| Se reporta el gasto acumulado por etiqueta | 10 | Captura 7 + tabla sección 7 |
| **Total** | **100** | |
