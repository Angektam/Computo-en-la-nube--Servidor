#!/bin/bash
# =============================================================================
# EVIDENCIA DE DENEGACIÓN — Práctica 02
# Ejecutar en AWS CloudShell con usuario administrador (usr-angel o root)
# =============================================================================

USUARIO="usr-kevin"
REGION="us-east-1"

echo "================================================"
echo "EVIDENCIA DE DENEGACIÓN — usr-kevin"
echo "================================================"
echo ""

# 1. Crear Access Key temporal para usr-kevin
echo "Paso 1: Creando Access Key temporal para $USUARIO..."
OUTPUT=$(aws iam create-access-key --user-name "$USUARIO")
KEY_ID=$(echo "$OUTPUT"     | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
KEY_SECRET=$(echo "$OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")
echo "✔ Key creada: $KEY_ID"
echo ""

# 2. Esperar unos segundos a que AWS propague las credenciales
echo "Paso 2: Esperando 10 segundos para propagación de credenciales..."
sleep 10

# 3. Intentar crear un bucket (acción NO permitida para usr-kevin)
echo "Paso 3: Intentando crear bucket con credenciales de $USUARIO..."
echo "        (esto DEBE fallar con AccessDenied)"
echo ""
echo "─── INICIO DE EVIDENCIA DE DENEGACIÓN ──────────────────────"
AWS_ACCESS_KEY_ID="$KEY_ID" \
AWS_SECRET_ACCESS_KEY="$KEY_SECRET" \
AWS_DEFAULT_REGION="$REGION" \
aws s3api create-bucket \
  --bucket "bucket-no-autorizado-test-kevin" \
  --region "$REGION" 2>&1 || true
echo "─── FIN DE EVIDENCIA DE DENEGACIÓN ─────────────────────────"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
echo ""

# 4. Limpiar: eliminar la Access Key temporal
echo "Paso 4: Eliminando Access Key temporal..."
aws iam delete-access-key \
  --user-name "$USUARIO" \
  --access-key-id "$KEY_ID"
echo "✔ Access Key eliminada."
