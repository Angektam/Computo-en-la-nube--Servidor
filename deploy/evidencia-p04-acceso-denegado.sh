#!/bin/bash
# =============================================================================
# EVIDENCIA FALTANTE — Práctica 04
# Dos capturas requeridas en el reporte:
#   A) Estado INICIAL del bloqueo (cuatro valores en true)
#   B) Error 403 / acceso denegado antes de aplicar la bucket policy
#
# Ejecutar en AWS CloudShell con las credenciales del proyecto.
# IMPORTANTE: correr este script ANTES de aws-practica04-s3-estatico.sh,
#             o bien después de eliminar el bucket y volver a crearlo limpio.
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
REGION="us-east-1"
BUCKET_NAME="sitio-$PROYECTO-$EQUIPO"
WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"
OBJECT_URL="https://$BUCKET_NAME.s3.$REGION.amazonaws.com/index.html"

echo ""
echo "=============================================="
echo "  EVIDENCIA P04 — Acceso denegado"
echo "  Bucket : $BUCKET_NAME"
echo "  Región : $REGION"
echo "=============================================="
echo ""

# =============================================================================
# PARTE A — Estado INICIAL del bloqueo de acceso público
# Muestra los cuatro valores en true (configuración por defecto de AWS).
# CAPTURAR ESTA SALIDA para el reporte.
# =============================================================================
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  A) ESTADO INICIAL — bloqueo de acceso público          ║"
echo "║     (cuatro valores en true, antes de modificar nada)   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Verifica que el bucket existe; si no, lo crea limpio para la demo
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "· Bucket no existe — creándolo limpio para reproducir el estado inicial..."
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  echo "✔ Bucket creado: $BUCKET_NAME"
  echo ""
fi

# Restablecer el bloqueo completo (estado inicial de AWS por defecto)
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "--- CAPTURAR LA SIGUIENTE SALIDA PARA EL REPORTE ---"
echo ""
aws s3api get-public-access-block --bucket "$BUCKET_NAME"
echo ""
echo "↑ Estado INICIAL: los cuatro valores deben estar en true ↑"
echo ""

# =============================================================================
# PARTE B — Error 403 antes de aplicar la bucket policy
# Sube el index.html con el website hosting habilitado pero SIN la policy.
# El objeto existe pero no es público → 403 Forbidden.
# =============================================================================
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  B) ACCESO DENEGADO — 403 antes de aplicar la policy    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Habilitar website hosting (sin policy todavía)
aws s3api put-bucket-website --bucket "$BUCKET_NAME" \
  --website-configuration '{
    "IndexDocument": {"Suffix": "index.html"},
    "ErrorDocument": {"Key": "error.html"}
  }'
echo "✔ Website hosting habilitado (sin policy aún)"
echo ""

# Subir un index.html mínimo para que el objeto exista
cat > /tmp/index-prueba.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>Los Rojos — Inventario Cloud</title></head>
<body><h1>Sitio de prueba — Práctica 04</h1></body>
</html>
EOF

aws s3 cp /tmp/index-prueba.html "s3://$BUCKET_NAME/index.html" \
  --content-type "text/html" \
  --no-progress
echo "✔ index.html subido al bucket"
echo ""

# Esperar un momento para que el objeto esté disponible
sleep 3

echo "--- CAPTURAR LA SIGUIENTE SALIDA PARA EL REPORTE ---"
echo ""
echo "▶ curl al endpoint del website (debe devolver 403 Forbidden):"
echo "  URL: $WEBSITE_URL"
echo ""
# -v muestra los headers completos; -s suprime la barra de progreso
# El || true evita que el script aborte si curl regresa código de error
curl -v -s "$WEBSITE_URL" 2>&1 | grep -E "^[<>*]|HTTP|403|Forbidden|AccessDenied" || true
echo ""
echo "▶ curl al endpoint de objeto directo (también debe negar con 403):"
echo "  URL: $OBJECT_URL"
echo ""
curl -v -s "$OBJECT_URL" 2>&1 | grep -E "^[<>*]|HTTP|403|Forbidden|AccessDenied" || true
echo ""
echo "↑ CAPTURAR ESTE BLOQUE COMPLETO PARA EL REPORTE ↑"
echo "  (la línea '< HTTP/1.1 403 Forbidden' o el cuerpo XML con <Code>AccessDenied</Code>)"
echo ""

# =============================================================================
# AHORA sí: desbloquear y aplicar la policy (estado final correcto)
# =============================================================================
echo "=============================================="
echo "  Aplicando configuración final del bucket..."
echo "=============================================="
echo ""

# Desbloquear solo lo necesario para website estático
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false"
echo "✔ Bloqueo ajustado (BlockPublicPolicy=false, RestrictPublicBuckets=false)"

# Aplicar bucket policy de solo lectura
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Sid\": \"PermitirLecturaSitioPublico\",
      \"Effect\": \"Allow\",
      \"Principal\": \"*\",
      \"Action\": \"s3:GetObject\",
      \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
    }
  ]
}"
echo "✔ Bucket policy aplicada (solo s3:GetObject)"

sleep 3

echo ""
echo "--- Estado FINAL del bloqueo (para contrastar con el inicial) ---"
aws s3api get-public-access-block --bucket "$BUCKET_NAME"
echo ""

# Verificar que ahora sí es accesible
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL")
echo "--- Verificación de acceso tras aplicar la policy ---"
if [ "$HTTP_CODE" = "200" ]; then
  echo "✔ Sitio accesible — HTTP $HTTP_CODE"
  echo "  URL: $WEBSITE_URL"
else
  echo "✗ HTTP $HTTP_CODE — Revisar: bloqueo → policy → nombre del index"
fi
echo ""
echo "=============================================="
echo "  RESUMEN DE EVIDENCIAS A INCLUIR EN EL REPORTE"
echo "=============================================="
echo "  Figura X: Salida de get-public-access-block con los 4 valores en true"
echo "            (estado inicial, antes de cualquier modificación)"
echo "  Figura Y: Salida de curl con HTTP 403 / AccessDenied"
echo "            (objeto existe pero no hay policy que lo haga público)"
echo "  Figura Z: Salida de get-public-access-block con BlockPublicPolicy=false"
echo "            y RestrictPublicBuckets=false (estado final)"
echo "  Figura W: Salida de curl con HTTP 200 (sitio accesible tras la policy)"
echo "=============================================="
