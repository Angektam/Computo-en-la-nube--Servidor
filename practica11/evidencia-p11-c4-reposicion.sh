#!/bin/bash
# =============================================================================
# evidencia-p11-c4-reposicion.sh
# Evidencia: Reposición automática con tiempo cronometrado
# Criterio: Se documenta la reposición automática con tiempo medido y
#           comparación con el tiempo de instancias EC2 (25 pts)
#
# QUÉ HACE:
#   1. Muestra el estado inicial del servicio (2 tareas RUNNING)
#   2. Detiene una tarea a propósito (stop-task)
#   3. Cronometra cuánto tarda ECS en crear una nueva tarea
#   4. Compara el tiempo de reposición de contenedores (ECS Fargate)
#      contra el tiempo de reposición de instancias (EC2 ASG, práctica 8)
# =============================================================================

set -euo pipefail
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"
CLUSTER_NAME="ecs-$PROYECTO-$EQUIPO"
SERVICE_NAME="svc-$PROYECTO-$EQUIPO"
DESIRED_COUNT=2

echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA P11 — Reposición automática con tiempo cronometrado"
echo "════════════════════════════════════════════════════════════════════"

# ── 1. Estado inicial ─────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  1. ESTADO INICIAL DEL SERVICIO                                  │"
echo "└─────────────────────────────────────────────────────────────────┘"
INITIAL_RUNNING=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].runningCount" --output text)
INITIAL_DESIRED=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].desiredCount" --output text)
echo "  Tareas corriendo: $INITIAL_RUNNING"
echo "  Tareas deseadas:  $INITIAL_DESIRED"
echo ""

# Listar tareas iniciales
echo "  Tareas iniciales:"
aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns" \
  --output text | tr '\t' '\n' | while read T; do
  echo "    · $(echo $T | cut -d'/' -f3)"
done

# ── 2. Detener una tarea a propósito ──────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  2. DETENER UNA TAREA A PROPÓSITO                                 │"
echo "└─────────────────────────────────────────────────────────────────┘"

# Obtener la primera tarea RUNNING
TASK_TO_STOP=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns[0]" --output text)

if [ -z "$TASK_TO_STOP" ] || [ "$TASK_TO_STOP" = "None" ]; then
  echo "  ⚠ No hay tareas RUNNING para detener."
  echo "  Asegúrate de que el servicio tenga tareas activas."
  exit 1
fi

TASK_SHORT=$(echo "$TASK_TO_STOP" | cut -d'/' -f3)
echo "  Deteniendo tarea: $TASK_SHORT"
echo ""

# Marcar el tiempo de inicio
echo "  ⏱  Iniciando cronómetro..."
START_TIME=$(date +%s)
echo "  Hora de inicio: $(date '+%H:%M:%S')"

# Detener la tarea
aws ecs stop-task \
  --cluster "$CLUSTER_NAME" \
  --task "$TASK_TO_STOP" \
  --reason "Prueba de reposición automática — práctica 11" \
  > /dev/null

echo "  ✔ Tarea detenida a propósito."
echo "  Esperando a que el servicio detecte la falla y reponga..."
echo ""

# ── 3. Cronometrar la reposición ──────────────────────────────────────────────
# El servicio debería detectar que falta una tarea y crear una nueva.
# Medimos el tiempo hasta que runningCount vuelva a ser igual a desiredCount.

RETRY=0
MAX_RETRIES=60  # máximo 10 minutos (60 × 10 s)
REPOUSED=false

while [ "$RETRY" -lt "$MAX_RETRIES" ]; do
  sleep 10
  RETRY=$((RETRY + 1))
  CURRENT_RUNNING=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query "services[0].runningCount" --output text 2>/dev/null) || true

  ELAPSED=$(( $(date +%s) - START_TIME ))

  # Buscar la tarea NUEVA (que no sea la que detuvimos)
  NEW_TASK=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --desired-status RUNNING \
    --query "taskArns" \
    --output text | tr '\t' '\n' | grep -v "$TASK_SHORT" | head -1) || true

  echo "  [${ELAPSED}s] Tareas RUNNING: $CURRENT_RUNNING / $DESIRED_COUNT  (intento $RETRY/$MAX_RETRIES)"

  if [ "$CURRENT_RUNNING" -ge "$DESIRED_COUNT" ] && [ -n "$NEW_TASK" ]; then
    REPOUSED=true
    break
  fi
done

END_TIME=$(date +%s)
REPOSITION_TIME=$(( END_TIME - START_TIME ))

echo ""
if [ "$REPOUSED" = true ]; then
  echo "  ✔ ¡Reposición automática completada!"
  echo "  Hora de fin: $(date '+%H:%M:%S')"
else
  echo "  ⚠ La reposición tardó más de lo esperado. Revisa manualmente."
  REPOSITION_TIME=0
fi

echo ""
echo "  ┌──────────────────────────────────────────────┐"
echo "  │  TIEMPO DE REPOSICIÓN (ECS Fargate)           │"
echo "  │                                                │"
echo "  │  Tarea detenida: $TASK_SHORT"
echo "  │  Tiempo total:   ${REPOSITION_TIME} segundos"
echo "  └──────────────────────────────────────────────┘"

# ── 4. Estado después de la reposición ────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  4. ESTADO DESPUÉS DE LA REPOSICIÓN                              │"
echo "└─────────────────────────────────────────────────────────────────┘"
FINAL_RUNNING=$(aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].runningCount" --output text)
echo "  Tareas corriendo: $FINAL_RUNNING"
echo "  Tareas deseadas:  $DESIRED_COUNT"
echo ""
echo "  Tareas actuales:"
aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns" \
  --output text | tr '\t' '\n' | while read T; do
  SHORT=$(echo $T | cut -d'/' -f3)
  STATUS=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$T" \
    --query "tasks[0].lastStatus" --output text 2>/dev/null) || true
  HEALTH=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$T" \
    --query "tasks[0].healthStatus" --output text 2>/dev/null) || true
  echo "    · $SHORT (estado: $STATUS, salud: $HEALTH)"
done

# ── 5. Comparación con la práctica 8 (instancias EC2) ─────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  5. COMPARACIÓN: CONTENEDORES (ECS) vs INSTANCIAS (EC2 ASG)     │"
echo "│     Datos de la práctica 8 para la comparación                  │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  ┌────────────────────┬───────────────────┬───────────────────────┐"
echo "  │ Métrica            │ ECS Fargate (P11) │ EC2 ASG (P08)        │"
echo "  ├────────────────────┼───────────────────┼───────────────────────┤"
echo "  │ Tiempo reposición   │ ${REPOSITION_TIME}s              │ ~120-180s (medir P8)  │"
echo "  │ Qué se reemplaza    │ Contenedor (tarea)│ Instancia EC2 completa│"
echo "  │ Descarga imagen     │ Sí (de ECR)       │ Sí (AMI de EBS)       │"
echo "  │ Inicia SO           │ No (Fargate)      │ Sí (boot de Linux)    │"
echo "  │ Inicia app          │ Sí (Node ~2s)     │ Sí (PM2/Nginx ~10s)  │"
echo "  │ Escala a cero       │ Sí (desired=0)    │ No (min=2 en P08)    │"
echo "  └────────────────────┴───────────────────┴───────────────────────┘"
echo ""
echo "  Tiempo medido en la práctica 8 (reponer una instancia EC2):"
echo "    Anotar el tiempo medido en evidencia-p08-c4-recuperacion.sh"
echo "    (típicamente 2-3 minutos por el arranque completo del SO)"
echo ""
echo "  La diferencia clave:"
echo "  · Un contenedor arranca en segundos porque NO inicia el sistema"
echo "    operativo: solo el proceso de la aplicación (Node.js)."
echo "  · Una instancia EC2 arranca en minutos porque debe iniciar el"
echo "    kernel, systemd, nginx, PM2 y luego la aplicación."
echo ""
echo "  Conclusión para el reporte:"
echo "  «El contenedor se repone en ${REPOSITION_TIME} segundos, frente a los"
echo "   ~___ segundos que medimos en la práctica 8 con instancias. La"
echo "   diferencia es de un factor de ___× a favor de los contenedores»"
echo ""
echo "  ↑ TOMA CAPTURA DE PANTALLA DE ESTA SALIDA COMPLETA ↑"
