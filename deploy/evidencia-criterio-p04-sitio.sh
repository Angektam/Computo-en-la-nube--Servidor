#!/bin/bash
# =============================================================================
# EVIDENCIA PRÁCTICA 04 — Criterios 3, 4 y 6
# · Criterio 3 (25 pts): Política de solo lectura, no permisos amplios
# · Criterio 4 (20 pts): Sitio accesible con información real del proyecto
# · Criterio 6 (10 pts): Regla de ciclo de vida configurada
# =============================================================================

BUCKET_NAME="sitio-inventario-cloud-los-rojos"
REGION="us-east-1"
WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"

echo "=============================================="
echo "  P04 · Criterio 3: Política del bucket"
echo "=============================================="
echo ""
echo "--- Política actual (texto completo) ---"
aws s3api get-bucket-policy --bucket "$BUCKET_NAME" \
  --query Policy --output text | python3 -m json.tool

echo ""
echo "--- Explicación de cada parte de la política ---"
echo ""
echo "  \"Version\": \"2012-10-17\""
echo "  → Versión del lenguaje de políticas IAM. La más reciente y requerida"
echo "    para usar variables de política y todas las funciones modernas."
echo ""
echo "  \"Sid\": \"PermitirLecturaSitioPublico\""
echo "  → Identificador del statement. No afecta el comportamiento, sirve"
echo "    para documentar y auditar qué hace cada regla."
echo ""
echo "  \"Effect\": \"Allow\""
echo "  → Concede el permiso. Si fuera Deny lo negaría explícitamente."
echo ""
echo "  \"Principal\": \"*\""
echo "  → Aplica a cualquier entidad (usuarios anónimos, otras cuentas AWS,"
echo "    servicios). Necesario para que el sitio sea público sin autenticación."
echo ""
echo "  \"Action\": \"s3:GetObject\""
echo "  → ÚNICA acción permitida: descargar/leer un objeto ya existente."
echo "    NO permite: s3:ListBucket (listar), s3:PutObject (subir),"
echo "    s3:DeleteObject (borrar), ni ninguna acción de administración."
echo ""
echo "  \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\""
echo "  → El /* al final significa 'todos los objetos dentro del bucket'."
echo "    NO da permisos sobre el bucket en sí (eso requeriría sin /*)"
echo "    y NO permite enumerar el contenido del bucket."

echo ""
echo "=============================================="
echo "  P04 · Criterio 4: Verificar sitio accesible"
echo "=============================================="
echo ""
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL")
echo "  HTTP Status: $HTTP_CODE"
echo "  URL        : $WEBSITE_URL"
[ "$HTTP_CODE" = "200" ] && echo "  ✔ SITIO EN LÍNEA" || echo "  ✗ Revisar configuración"

echo ""
echo "--- Objetos publicados ---"
aws s3 ls "s3://$BUCKET_NAME" --recursive --human-readable

echo ""
echo "=============================================="
echo "  P04 · Criterio 6: Ciclo de vida"
echo "=============================================="
echo ""
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME"
echo ""
echo "  Interpretación de la regla:"
echo "  · Después de 30 días sin acceso, los objetos pasan a STANDARD_IA."
echo "  · STANDARD_IA tiene ~58% menos costo de almacenamiento vs STANDARD."
echo "  · Tiene costo por recuperación, pero para un sitio poco visitado"
echo "    tras el parcial, el ahorro neto es positivo."
echo "  · Esta regla sustenta el apartado de análisis de costos del E2."
