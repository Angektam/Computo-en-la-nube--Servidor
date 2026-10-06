#!/bin/bash
# =============================================================================
# PRÁCTICA 04 - Almacenamiento de objetos y publicación del sitio del proyecto
# Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  Fecha: 30 sep 2026
# =============================================================================
# Ejecutar en AWS CloudShell (ya tiene credenciales de la cuenta del proyecto)
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"
BUCKET_NAME="sitio-$PROYECTO-$EQUIPO"

echo ""
echo "=============================================="
echo "  PRÁCTICA 04 — Sitio estático en S3"
echo "  Bucket : $BUCKET_NAME"
echo "  Región : $REGION"
echo "=============================================="
echo ""

# =============================================================================
# PASO 01 — Crear el bucket con etiquetas del esquema del equipo
# =============================================================================
echo "=== PASO 01: Crear bucket ==="

# Verificar si el bucket ya existe
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "· Bucket ya existe: $BUCKET_NAME"
else
  # us-east-1 no acepta LocationConstraint; otras regiones sí lo necesitan
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  echo "✔ Bucket creado: $BUCKET_NAME"
fi

# Aplicar etiquetas del esquema del equipo (criterio 1 - 10 pts)
aws s3api put-bucket-tagging --bucket "$BUCKET_NAME" --tagging \
  "TagSet=[
    {Key=proyecto,Value=$PROYECTO},
    {Key=equipo,Value=$EQUIPO},
    {Key=ambiente,Value=$AMBIENTE}
  ]"
echo "✔ Etiquetas aplicadas: proyecto=$PROYECTO | equipo=$EQUIPO | ambiente=$AMBIENTE"

# =============================================================================
# PASO 02 — Documentar y modificar bloqueo de acceso público (criterio 2 - 20 pts)
# =============================================================================
echo ""
echo "=== PASO 02: Estado INICIAL del bloqueo de acceso público ==="
echo "--- CAPTURAR ESTA SALIDA PARA EL REPORTE (estado antes de modificar) ---"
aws s3api get-public-access-block --bucket "$BUCKET_NAME" 2>/dev/null || \
  echo "· Sin configuración explícita — valores por defecto: todo bloqueado"

echo ""
echo "--- Desactivando únicamente lo necesario para website estático ---"
# BlockPublicAcls      = true   → bloqueamos ACLs públicas (no las usamos)
# IgnorePublicAcls     = true   → ignoramos cualquier ACL pública
# BlockPublicPolicy    = false  → PERMITIMOS política de bucket pública (necesario)
# RestrictPublicBuckets= false  → PERMITIMOS acceso público vía política
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false"
echo "✔ Bloqueo modificado:"
echo "  · BlockPublicAcls=true    (no usamos ACLs, usamos política)"
echo "  · IgnorePublicAcls=true   (ignorar ACLs existentes por seguridad)"
echo "  · BlockPublicPolicy=false (necesario para aplicar bucket policy pública)"
echo "  · RestrictPublicBuckets=false (permite lectura anónima vía policy)"

echo ""
echo "--- Estado FINAL del bloqueo ---"
aws s3api get-public-access-block --bucket "$BUCKET_NAME"

# =============================================================================
# PASO 03 — Subir el contenido del sitio
# =============================================================================
echo ""
echo "=== PASO 03: Subir contenido al bucket ==="
echo "ℹ  Este paso se ejecuta desde tu máquina local (NO desde CloudShell)"
echo "   porque los archivos están en tu repositorio local."
echo ""
echo "   Ejecuta desde la raíz del proyecto:"
echo "   aws s3 cp public/info.html s3://$BUCKET_NAME/index.html"
echo "   aws s3 cp public/css/styles.css s3://$BUCKET_NAME/css/styles.css"
echo "   aws s3 cp public/img/logo.png s3://$BUCKET_NAME/img/logo.png"
echo ""
echo "   O para subir todo el directorio public/ de una vez:"
echo "   aws s3 sync public/ s3://$BUCKET_NAME/ --exclude '*.js' --exclude 'app.js'"
echo "   (excluimos el JS de la SPA porque no aplica al sitio informativo)"
echo ""
echo "--- ANTES de aplicar la política, el objeto NO será accesible ---"
echo "--- Esa es la captura de 'acceso denegado' requerida en el reporte ---"
echo "   URL del objeto: https://$BUCKET_NAME.s3.$REGION.amazonaws.com/index.html"

# =============================================================================
# PASO 04 — Habilitar hospedaje de sitio estático
# =============================================================================
echo ""
echo "=== PASO 04: Habilitar static website hosting ==="
aws s3api put-bucket-website --bucket "$BUCKET_NAME" \
  --website-configuration '{
    "IndexDocument": {"Suffix": "index.html"},
    "ErrorDocument": {"Key": "error.html"}
  }'
echo "✔ Website hosting habilitado"
echo "  · Documento de inicio : index.html"
echo "  · Documento de error  : error.html"

WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"
echo ""
echo "  URL del sitio: $WEBSITE_URL"

# =============================================================================
# PASO 05 — Aplicar política de bucket (solo lectura, solo objetos públicos)
# Criterio 3 — 25 puntos: política otorga solo lectura, no permisos amplios
# =============================================================================
echo ""
echo "=== PASO 05: Aplicar política de bucket ==="

# Obtener el Account ID dinámicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# La política permite ÚNICAMENTE s3:GetObject (lectura) a cualquier
# principal (*). No permite ListBucket, PutObject, DeleteObject ni nada
# más. El Resource apunta exactamente a los objetos del bucket, no a
# operaciones sobre el bucket en sí.
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

echo "✔ Política aplicada. Explicación de cada parte:"
echo "  · Version: 2012-10-17  → versión estándar del lenguaje de políticas IAM"
echo "  · Sid     → identificador descriptivo del statement (ayuda a auditar)"
echo "  · Effect:Allow         → concede el permiso (en lugar de denegarlo)"
echo "  · Principal:*          → cualquier usuario/servicio puede leer (anónimo)"
echo "  · Action:s3:GetObject  → SOLO lectura de objetos; NO listar, subir ni borrar"
echo "  · Resource: arn:.../BUCKET/* → aplica a los objetos del bucket, no al bucket mismo"

# =============================================================================
# PASO 06 — Verificar que el sitio es accesible
# =============================================================================
echo ""
echo "=== PASO 06: Verificar acceso al sitio ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEBSITE_URL")
if [ "$HTTP_CODE" = "200" ]; then
  echo "✔ Sitio accesible — HTTP $HTTP_CODE"
  echo "  URL: $WEBSITE_URL"
  echo "  → CAPTURAR PANTALLA en el navegador para el reporte"
else
  echo "✗ Código HTTP: $HTTP_CODE"
  echo "  Revisa en orden: bloqueo de acceso público → política → nombre del index"
fi

# =============================================================================
# PASO 08 — Regla de ciclo de vida (criterio 6 - 10 pts)
# Mueve a S3 Standard-IA los objetos con más de 30 días sin acceso
# =============================================================================
echo ""
echo "=== PASO 08: Configurar regla de ciclo de vida ==="
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "mover-a-standard-ia-30dias",
        "Status": "Enabled",
        "Filter": {"Prefix": ""},
        "Transitions": [
          {
            "Days": 30,
            "StorageClass": "STANDARD_IA"
          }
        ]
      }
    ]
  }'
echo "✔ Regla de ciclo de vida configurada:"
echo "  · ID       : mover-a-standard-ia-30dias"
echo "  · Estado   : Enabled"
echo "  · Filtro   : todos los objetos (Prefix vacío)"
echo "  · Después de 30 días sin acceso → STANDARD_IA (menor costo de almacenamiento)"
echo "  → CAPTURAR PANTALLA de la consola S3 → Management → Lifecycle rules"

# =============================================================================
# EVIDENCIA FINAL — Resumen completo para el reporte
# =============================================================================
echo ""
echo "=============================================="
echo "  EVIDENCIA FINAL — PRÁCTICA 04"
echo "=============================================="
echo ""
echo "--- Bucket y etiquetas ---"
aws s3api get-bucket-tagging --bucket "$BUCKET_NAME"

echo ""
echo "--- Configuración de acceso público ---"
aws s3api get-public-access-block --bucket "$BUCKET_NAME"

echo ""
echo "--- Política del bucket ---"
aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --query Policy --output text | python3 -m json.tool

echo ""
echo "--- Website hosting config ---"
aws s3api get-bucket-website --bucket "$BUCKET_NAME"

echo ""
echo "--- Regla de ciclo de vida ---"
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME"

echo ""
echo "--- Objetos en el bucket ---"
aws s3 ls "s3://$BUCKET_NAME" --recursive --human-readable

echo ""
echo "=============================================="
echo "  URL DEL SITIO:"
echo "  $WEBSITE_URL"
echo "=============================================="
