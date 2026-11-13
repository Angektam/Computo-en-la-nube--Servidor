#!/bin/bash
# =============================================================================
# PRÁCTICA 04 — Subir archivos del sitio estático desde la máquina LOCAL
# Ejecutar desde la raíz del proyecto con AWS CLI instalado localmente
# =============================================================================
# Requiere: aws configure (con credenciales de la cuenta del proyecto)
# =============================================================================

BUCKET_NAME="sitio-inventario-cloud-los-rojos"
REGION="us-east-1"
WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"

echo "=== Subiendo sitio informativo a S3 ==="
echo ""

# Subir página principal (renombrada como index.html en S3)
aws s3 cp public/info.html "s3://$BUCKET_NAME/index.html" \
  --content-type "text/html; charset=utf-8"
echo "✔ index.html subido"

# Subir hoja de estilos
aws s3 cp public/css/styles.css "s3://$BUCKET_NAME/css/styles.css" \
  --content-type "text/css"
echo "✔ css/styles.css subido"

# Crear y subir una imagen de logo representativa del proyecto
# (Si no tienes una, el sitio usa emojis SVG inline — funciona sin imagen)
if [ -f "public/img/logo.png" ]; then
  aws s3 cp public/img/logo.png "s3://$BUCKET_NAME/img/logo.png" \
    --content-type "image/png"
  echo "✔ img/logo.png subido"
else
  echo "· img/logo.png no encontrado — el sitio funciona sin él (usa SVG inline)"
fi

echo ""
echo "--- Verificando acceso ANTES de la política (debe dar 403) ---"
echo "    Captura esta pantalla para la evidencia del reporte:"
echo "    $WEBSITE_URL"
echo ""
HTTP_BEFORE=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL")
echo "    HTTP code actual: $HTTP_BEFORE"
if [ "$HTTP_BEFORE" = "403" ]; then
  echo "    ✔ Correcto — 403 Forbidden (bloqueo activo antes de política)"
fi

echo ""
echo "--- Objetos en el bucket ---"
aws s3 ls "s3://$BUCKET_NAME" --recursive --human-readable

echo ""
echo "  → Ahora ejecuta aws-practica04-s3-estatico.sh (paso 05 en adelante)"
echo "    para aplicar la política y hacer el sitio accesible."
echo "  → URL final: $WEBSITE_URL"
