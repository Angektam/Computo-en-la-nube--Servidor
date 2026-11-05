#!/bin/bash
# =============================================================================
# evidencia-p11-c5-cero-tareas.sh
# Evidencia: Servicio reducido a cero tareas al cierre
# Criterio: El servicio quedó en cero tareas al cierre (10 pts)
#
# NOTA: Este script reduce el servicio a 0 tareas y muestra la evidencia.
# Se ejecuta al final de la sesión para no acumular consumo.
# =============================================================================

set -euo pipefail
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"
CLUSTER_NAME="ecs-$PROYECTO-$EQUIPO"
SERVICE_NAME="svc-$PROYECTO-$EQUIPO"

echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA P11 — Reducir el servicio a cero tareas"
echo "════════════════════════════════════════════════════════════════════"

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  1. ESTADO ANTES DE REDUCIR                                      │"
echo "└─────────────────────────────────────────────────────────────────┘"
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].{Nombre:serviceName,Estado:status,Deseadas:desiredCount,Corriendo:runningCount}" \
  --output table

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  2. REDUCIENDO A CERO TAREAS                                     │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo "  Ajustando desiredCount a 0..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --desired-count 0 \
  --query "service.{Nombre:serviceName,NuevasDeseadas:desiredCount}" \
  --output table
echo "  ✔ desiredCount = 0"
echo ""

echo "  Esperando a que las tareas se detengan..."
sleep 15

echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  3. ESTADO DESPUÉS DE REDUCIR (debe mostrar 0 tareas)            │"
echo "└─────────────────────────────────────────────────────────────────┘"
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].{Nombre:serviceName,Estado:status,Deseadas:desiredCount,Corriendo:runningCount,Pendientes:pendingCount}" \
  --output table

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  4. CONFIRMACIÓN: NO HAY TAREAS EN EJECUCIÓN                    │"
echo "└─────────────────────────────────────────────────────────────────┘"
RUNNING=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns" \
  --output text)

if [ -z "$RUNNING" ] || [ "$RUNNING" = "None" ] || [ "$RUNNING" = "None" ]; then
  echo "  ✔ No hay tareas en ejecución. El servicio está en cero."
  echo "  ✔ El servicio y el clúster se conservan (no cuestan sin tareas)."
else
  echo "  ⚠ Aún hay tareas deteniéndose. Espera 30 s más y reintenta."
  echo "    Tareas: $RUNNING"
fi

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  5. COSTO DE DEJAR CORRIENDO (recordatorio)                      │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  El cómputo sin servidores para contenedores (Fargate) cobra por"
echo "  SEGUNDO de recursos asignados. Dejar 2 tareas corriendo el fin"
echo "  de semana cuesta:"
echo ""
echo "    2 tareas × 0.25 vCPU × \$0.04048/h × 48h = \$0.97"
echo "    2 tareas × 0.5 GB × \$0.004445/h × 48h = \$0.21"
echo "    NAT Gateway base:  \$0.045/h × 48h = \$2.16"
echo "    ─────────────────────────────────────────────"
echo "    Total fin de semana: ~\$3.34 USD"
echo ""
echo "  Por eso la reducción a cero NO es opcional."
echo "  El clúster y la definición de tarea NO cuestan sin tareas."
echo ""
echo "  ↑ TOMA CAPTURA DE PANTALLA DE ESTA SALIDA (desiredCount = 0) ↑"
echo ""
echo "  ⚠  Recuerda también eliminar el NAT Gateway para no acumular costo:"
echo "     bash practica11/parar-p11.sh"
