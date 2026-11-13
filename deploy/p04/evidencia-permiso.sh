#!/bin/bash
# =============================================================================
# EVIDENCIA DE PERMISO — Práctica 02
# Ejecutar en AWS CloudShell con usuario administrador (usr-angel o root)
# =============================================================================

USUARIO="usr-kevin"
BUCKET="inventario-archivos-losrojos"
REGION="us-east-1"

echo "================================================"
echo "EVIDENCIA DE PERMISO — usr-kevin"
echo "================================================"
echo ""

# 1. Crear Access Key temporal para usr-kevin
echo "Paso 1: Creando Access Key temporal para $USUARIO..."
OUTPUT=$(aws iam create-access-key --user-name "$USUARIO")
KEY_ID=$(echo "$OUTPUT"     | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
KEY_SECRET=$(echo "$OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")
echo "✔ Key creada: $KEY_ID"
echo ""

# 2. Esperar propagación
echo "Paso 2: Esperando 10 segundos para propagación de credenciales..."
sleep 10

# 3. Subir un archivo de prueba al bucket (como admin, para que haya algo que listar)
echo "Paso 3: Subiendo archivo de prueba al bucket (como admin)..."
echo "Archivo de prueba - Practica 02 Los Rojos" > /tmp/prueba-practica02.txt
aws s3 cp /tmp/prueba-practica02.txt "s3://$BUCKET/prueba-practica02.txt" 2>/dev/null \
  && echo "✔ Archivo subido al bucket" \
  || echo "ℹ  El bucket aún no existe — la evidencia será el mensaje de 'NoSuchBucket' (que tampoco es AccessDenied)"
echo ""

# 4. Listar el bucket con credenciales de usr-kevin (acción SÍ permitida)
echo "Paso 4: Listando bucket con credenciales de $USUARIO..."
echo "        (esto DEBE funcionar — usr-kevin tiene s3:ListBucket)"
echo ""
echo "─── INICIO DE EVIDENCIA DE PERMISO ─────────────────────────"
AWS_ACCESS_KEY_ID="$KEY_ID" \
AWS_SECRET_ACCESS_KEY="$KEY_SECRET" \
AWS_DEFAULT_REGION="$REGION" \
aws s3 ls "s3://$BUCKET" 2>&1 || true
echo "─── FIN DE EVIDENCIA DE PERMISO ────────────────────────────"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
echo ""

# 5. También probar GetObject (descargar el archivo que subimos)
echo "Paso 5 (bonus): Descargando archivo con credenciales de $USUARIO..."
echo "─── INICIO DE EVIDENCIA GetObject ──────────────────────────"
AWS_ACCESS_KEY_ID="$KEY_ID" \
AWS_SECRET_ACCESS_KEY="$KEY_SECRET" \
AWS_DEFAULT_REGION="$REGION" \
aws s3 cp "s3://$BUCKET/prueba-practica02.txt" /tmp/descarga-kevin.txt 2>&1 \
  && cat /tmp/descarga-kevin.txt || true
echo "─── FIN DE EVIDENCIA GetObject ─────────────────────────────"
echo ""
echo "↑ CAPTURA OPCIONAL PERO REFUERZA LA EVIDENCIA ↑"
echo ""

# 6. Limpiar: eliminar Access Key temporal
echo "Paso 6: Eliminando Access Key temporal..."
aws iam delete-access-key \
  --user-name "$USUARIO" \
  --access-key-id "$KEY_ID"
echo "✔ Access Key eliminada."
