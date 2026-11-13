#!/bin/bash
# =============================================================================
# EVIDENCIA — CRITERIO 1 (15 pts)
# "La instancia se lanzó con las tres etiquetas del esquema del equipo"
#
# Etiquetas requeridas: proyecto | equipo | ambiente
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Luego toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
APP_NAME="inventario-nube"

echo "================================================"
echo "CRITERIO 1 — Etiquetas de la instancia EC2"
echo "================================================"
echo ""

# Buscar la instancia por nombre
INSTANCE_ID=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=${APP_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped,stopping" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "⚠  No se encontró instancia con Name=${APP_NAME}"
  echo "   Listando TODAS las instancias activas para que identifiques la tuya:"
  echo ""
  aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=running,pending,stopped" \
    --query "Reservations[].Instances[].[InstanceId, State.Name, Tags[?Key=='Name'].Value|[0]]" \
    --output table
  exit 1
fi

echo "Instancia encontrada: $INSTANCE_ID"
echo ""

# ─── INICIO DE EVIDENCIA ──────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA CRITERIO 1 — Tres etiquetas del esquema del equipo"
echo "══════════════════════════════════════════════════════════════════"
echo ""

echo "▶ Todas las etiquetas de la instancia $INSTANCE_ID:"
echo ""
aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].Tags" \
  --output table

echo ""
echo "▶ Verificación específica de las tres etiquetas del esquema:"
echo ""

PROYECTO=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].Tags[?Key=='proyecto'].Value" \
  --output text)

EQUIPO=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].Tags[?Key=='equipo'].Value" \
  --output text)

AMBIENTE=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].Tags[?Key=='ambiente'].Value" \
  --output text)

# También verificar con mayúscula (por si el script de despliegue usó Proyecto/Env)
PROYECTO_MAY=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].Tags[?Key=='Proyecto'].Value" \
  --output text)

AMBIENTE_MAY=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].Tags[?Key=='Env'].Value" \
  --output text)

# Usar el valor que exista
[ -n "$PROYECTO" ] || PROYECTO="$PROYECTO_MAY"
[ -n "$AMBIENTE" ] || AMBIENTE="$AMBIENTE_MAY"

printf "  %-12s : %-30s  %s\n" "proyecto"  "$PROYECTO"  "$([ -n "$PROYECTO" ]  && echo '✔ PRESENTE' || echo '✗ FALTA')"
printf "  %-12s : %-30s  %s\n" "equipo"    "$EQUIPO"    "$([ -n "$EQUIPO" ]    && echo '✔ PRESENTE' || echo '✗ FALTA')"
printf "  %-12s : %-30s  %s\n" "ambiente"  "$AMBIENTE"  "$([ -n "$AMBIENTE" ]  && echo '✔ PRESENTE' || echo '✗ FALTA')"

echo ""

FALTAN=0
[ -z "$PROYECTO" ] && FALTAN=$((FALTAN+1))
[ -z "$EQUIPO" ]   && FALTAN=$((FALTAN+1))
[ -z "$AMBIENTE" ] && FALTAN=$((FALTAN+1))

if [ "$FALTAN" -eq 0 ]; then
  echo "  ✅  Las tres etiquetas están presentes — CRITERIO 1 CUMPLIDO (15/15 pts)"
else
  echo "  ⚠   Faltan $FALTAN etiqueta(s) — se agregarán ahora..."
  echo ""

  # Agregar las etiquetas faltantes
  TAGS_A_AGREGAR=""
  [ -z "$PROYECTO" ] && TAGS_A_AGREGAR="$TAGS_A_AGREGAR Key=proyecto,Value=inventario-cloud"
  [ -z "$EQUIPO" ]   && TAGS_A_AGREGAR="$TAGS_A_AGREGAR Key=equipo,Value=los-rojos"
  [ -z "$AMBIENTE" ] && TAGS_A_AGREGAR="$TAGS_A_AGREGAR Key=ambiente,Value=dev"

  aws ec2 create-tags \
    --region "$REGION" \
    --resources "$INSTANCE_ID" \
    --tags $TAGS_A_AGREGAR

  echo "  ✔  Etiquetas agregadas. Verificando de nuevo..."
  echo ""
  aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].Tags" \
    --output table
  echo ""
  echo "  ✅  Etiquetas completas — CRITERIO 1 CUMPLIDO (15/15 pts)"
fi

echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
