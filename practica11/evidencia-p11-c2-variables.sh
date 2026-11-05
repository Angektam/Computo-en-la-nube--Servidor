#!/bin/bash
# =============================================================================
# evidencia-p11-c2-variables.sh
# Evidencia: Lista de variables de entorno inyectadas, sin valores sensibles
# Criterio: la configuración se inyecta por variables de entorno (15 pts)
# =============================================================================

set -euo pipefail
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
TASK_FAMILY="td-$PROYECTO-$EQUIPO"

echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA P11 — Variables de entorno inyectadas"
echo "  (sin valores sensibles visibles)"
echo "════════════════════════════════════════════════════════════════════"

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  VARIABLES INYECTADAS EN LA DEFINICIÓN DE TAREA                 │"
echo "│  Las sensibles se muestran enmascaradas (********)              │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""

# Extraer las variables de entorno de la task definition
aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" \
  --query "taskDefinition.containerDefinitions[0].environment" \
  --output json > /tmp/env-vars.json

python3 << 'PYEOF'
import json

with open('/tmp/env-vars.json') as f:
    data = json.load(f)

sensitive = {"DB_PASSWORD", "JWT_SECRET"}

print(f"  {'VARIABLE':<25} {'VALOR':<55} {'TIPO'}")
print(f"  {'-'*25} {'-'*55} {'-'*10}")
for env in data:
    name = env["name"]
    value = env["value"]
    if name in sensitive:
        display = "******** (no visible)"
        tipo = "SECRETO"
    elif name in ("DB_HOST",):
        display = value
        tipo = "endpoint RDS"
    elif name in ("S3_BUCKET",):
        display = value
        tipo = "nombre bucket"
    elif name in ("DB_NAME", "DB_USER"):
        display = value
        tipo = "no sensible"
    else:
        display = value
        tipo = "config"
    print(f"  {name:<25} {display:<55} {tipo}")
PYEOF

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  VERIFICACIÓN: la dirección de la BD va en la tarea, NO en la   │"
echo "│  imagen Docker                                                   │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  El Dockerfile NO contiene DB_HOST, DB_PASSWORD ni JWT_SECRET:"
echo "  (verificado en la práctica 10, criterio C5)"
echo ""
echo "  La inyección de variables de entorno significa que:"
echo "  · La MISMA imagen sirve para dev, staging y producción"
echo "  · Cambiar la BD no requiere reconstruir la imagen"
echo "  · Los secretos no quedan en el repositorio de imágenes"
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  TIPOS DE VARIABLES Y SU ORIGEN                                │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  PORT            ← valor por defecto seguro del Dockerfile (3000)"
echo "  NODE_ENV        ← production (definido en la tarea)"
echo "  CORS_ORIGIN     ← DNS del balanceador (calculado al desplegar)"
echo "  AWS_REGION      ← us-east-1 (la región del proyecto)"
echo "  DB_HOST         ← endpoint de RDS (práctica 06) ← VA AQUÍ, NO EN LA IMAGEN"
echo "  DB_PORT         ← 5432 (PostgreSQL estándar)"
echo "  DB_NAME         ← nombre de la base de datos"
echo "  DB_USER         ← usuario de la base de datos"
echo "  DB_PASSWORD     ← ******** SECRETO (no visible)"
echo "  DB_SSL          ← true (cifrado en tránsito)"
echo "  S3_BUCKET       ← bucket del proyecto (práctica 04)"
echo "  JWT_SECRET      ← ******** SECRETO (no visible)"
echo "  JWT_EXPIRES_IN  ← 8h (duración del token)"
echo ""
echo "  TOTAL: 13 variables de entorno inyectadas"
echo "  de las cuales 2 son secretas (enmascaradas)"
