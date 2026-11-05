#!/bin/bash
# =============================================================================
# evidencia-p11-c1-tarea.sh
# Evidencia C1+C3+C4: Definición de la tarea con recursos, puerto y rol
# Criterios: servicio ejecuta la imagen del registro (20 pts)
#            configuración se inyecta por variables de entorno (15 pts)
#            el rol de la tarea tiene permisos acotados (10 pts)
# =============================================================================

set -euo pipefail
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"
TASK_FAMILY="td-$PROYECTO-$EQUIPO"
CLUSTER_NAME="ecs-$PROYECTO-$EQUIPO"
SERVICE_NAME="svc-$PROYECTO-$EQUIPO"
EXEC_ROLE_NAME="rol-ecs-exec-$EQUIPO"
TASK_ROLE_NAME="rol-ecs-task-$EQUIPO"

echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA P11 — Definición de la tarea con recursos y puerto"
echo "════════════════════════════════════════════════════════════════════"

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  DEFINICIÓN DE LA TAREA — $TASK_FAMILY"
echo "└─────────────────────────────────────────────────────────────────┘"
aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --query "taskDefinition.{Familia:family,Revision:revision,Imagen:containerDefinitions[0].image,CPU:cpu,Memoria:memory,Puerto:containerDefinitions[0].portMappings[0].containerPort,Red:networkMode,Compatibilidad:requiresCompatibilities[0]}" \
  --output table

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  ROL DE EJECUCIÓN — descargar imagen + enviar logs              │"
echo "└─────────────────────────────────────────────────────────────────┘"
aws iam list-attached-role-policies \
  --role-name "$EXEC_ROLE_NAME" \
  --query "AttachedPolicies[].{Politica:PolicyName,ARN:PolicyArn}" \
  --output table

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  ROL DE LA TAREA — permisos ACOTADOS (solo S3 del bucket)        │"
echo "└─────────────────────────────────────────────────────────────────┘"
aws iam list-role-policies \
  --role-name "$TASK_ROLE_NAME" \
  --query "PolicyNames" \
  --output text | while read POL; do
  echo "  Política inline: $POL"
  echo ""
  aws iam get-role-policy \
    --role-name "$TASK_ROLE_NAME" \
    --policy-name "$POL" \
    --query "PolicyDocument" \
    --output json | python3 -m json.tool
done

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  SERVICIO EN EJECUCIÓN — confirmando que corre la imagen         │"
echo "└─────────────────────────────────────────────────────────────────┘"
aws ecs describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].{Nombre:serviceName,Estado:status,TareasDeseadas:desiredCount,TareasCorriendo:runningCount,TipoLanzamiento:launchType,TareaARN:taskDefinition}" \
  --output table

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  TAREAS EN EJECUCIÓN — imagen, IP privada, estado                │"
echo "└─────────────────────────────────────────────────────────────────┘"
aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns" \
  --output text | tr '\t' '\n' | head -5 | while read TASK_ARN; do
  [ -z "$TASK_ARN" ] && continue
  aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query "tasks[0].{Tarea:taskArn,Imagen:containers[0].image,IP:attachments[0].details[?name=='privateIPv4Address'].value|[0],Estado:lastStatus,Salud:healthStatus}" \
    --output table
  echo ""
done

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  RESUMEN DE RECURSOS ASIGNADOS (anotar para la práctica 17)     │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  CPU asignada     : 256 (0.25 vCPU) — ¿sobra o es justo?"
echo "  Memoria asignada : 512 MB          — ¿sobra o es justo?"
echo "  Puerto expuesto  : 3000"
echo "  Imagen           : $TASK_FAMILY (revisión arriba)"
echo "  NAT Gateway      : permite descargar la imagen desde ECR"
echo ""
echo "  En la práctica 17 se evaluará si estos valores eran excesivos."
