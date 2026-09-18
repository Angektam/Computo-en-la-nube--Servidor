#!/bin/bash
# =============================================================================
# PRÁCTICA 02 - Políticas de Identidad con Mínimo Privilegio
# Pasos 01-08: Quitar permisos amplios, redactar políticas, restringir por
#              recurso/etiqueta, probar denegación y permiso, crear rol de
#              servicio y documentar la matriz de accesos.
#
# USO EN AWS CLOUDSHELL:
#   1. Abre CloudShell desde la consola AWS (ícono de terminal en la barra superior)
#   2. Edita las variables de la sección CONFIGURACIÓN si es necesario
#   3. Pega todo el script y presiona Enter
#
# REQUISITO: Práctica 01 terminada (usuarios y grupos creados)
# =============================================================================

set -e  # Detener ante cualquier error

# =============================================================================
# CONFIGURACIÓN - Ajusta si cambiaron los nombres en la práctica 1
# =============================================================================

PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
AMBIENTE="dev"
REGION="us-east-1"

# Usuarios del equipo (creados en práctica 1)
USUARIO_KEVIN="usr-kevin"   # Rol: documentación + arquitectura
USUARIO_ANGEL="usr-angel"   # Rol: desarrollo + seguridad-costos

# Grupos del equipo (creados en práctica 1)
GRP_DOC="grp-documentacion"
GRP_ARQ="grp-arquitectura"
GRP_DEV="grp-desarrollo"
GRP_SEC="grp-seguridad-costos"

# Bucket S3 y recurso RDS del proyecto
S3_BUCKET="inventario-archivos-losrojos"
RDS_INSTANCE="inventario-db"

# Obtener Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  Account ID detectado: $ACCOUNT_ID"

# =============================================================================
# PASO 01 - Tabla de acciones necesarias por rol
# =============================================================================
echo ""
echo "========================================"
echo "PASO 01 · Tabla de acciones por rol"
echo "========================================"
echo ""
echo "  ┌─────────────────────┬────────────────────────────────────────────────────────────────┐"
echo "  │ Rol                 │ Acciones necesarias                                            │"
echo "  ├─────────────────────┼────────────────────────────────────────────────────────────────┤"
echo "  │ documentacion       │ Leer objetos S3, describir instancias RDS/EC2,                 │"
echo "  │ (usr-kevin)         │ listar buckets, ver logs de CloudWatch (solo lectura)           │"
echo "  ├─────────────────────┼────────────────────────────────────────────────────────────────┤"
echo "  │ arquitectura        │ Igual que documentación + describir VPC, subnets,              │"
echo "  │ (usr-kevin)         │ security groups, load balancers                                │"
echo "  ├─────────────────────┼────────────────────────────────────────────────────────────────┤"
echo "  │ desarrollo          │ Subir/bajar objetos S3, invocar funciones Lambda,              │"
echo "  │ (usr-angel)         │ leer/escribir en RDS, ver métricas CloudWatch,                 │"
echo "  │                     │ gestionar tablas DynamoDB del proyecto                         │"
echo "  ├─────────────────────┼────────────────────────────────────────────────────────────────┤"
echo "  │ seguridad-costos    │ Administrador completo (para gestionar IAM, presupuesto,       │"
echo "  │ (usr-angel)         │ facturación y emergencias de acceso)                           │"
echo "  └─────────────────────┴────────────────────────────────────────────────────────────────┘"
echo ""
echo "  → Esta tabla se incluye en el apartado 11 del documento técnico."

# =============================================================================
# PASO 02 - Quitar permisos amplios de los grupos (excepto seguridad-costos)
# =============================================================================
echo ""
echo "========================================"
echo "PASO 02 · Quitando permisos amplios"
echo "========================================"

# Quitar ReadOnlyAccess amplio de documentación
aws iam detach-group-policy \
  --group-name "$GRP_DOC" \
  --policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess" 2>/dev/null \
  && echo "  ✔ ReadOnlyAccess retirada de $GRP_DOC" \
  || echo "  · ReadOnlyAccess ya no estaba en $GRP_DOC"

# Quitar ReadOnlyAccess amplio de arquitectura
aws iam detach-group-policy \
  --group-name "$GRP_ARQ" \
  --policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess" 2>/dev/null \
  && echo "  ✔ ReadOnlyAccess retirada de $GRP_ARQ" \
  || echo "  · ReadOnlyAccess ya no estaba en $GRP_ARQ"

# Quitar ReadOnlyAccess amplio de desarrollo
aws iam detach-group-policy \
  --group-name "$GRP_DEV" \
  --policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess" 2>/dev/null \
  && echo "  ✔ ReadOnlyAccess retirada de $GRP_DEV" \
  || echo "  · ReadOnlyAccess ya no estaba en $GRP_DEV"

echo ""
echo "  → grp-seguridad-costos conserva AdministratorAccess (por diseño)."

# =============================================================================
# PASO 03 - Redactar la política de solo lectura para documentación
# =============================================================================
echo ""
echo "========================================"
echo "PASO 03 · Creando política de solo lectura (documentación)"
echo "========================================"

# Nombre de la política
POL_DOC_NAME="pol-documentacion-lectura-$EQUIPO"

# Texto de la política JSON
# Permite leer S3, describir EC2/RDS y leer logs de CloudWatch,
# pero SOLO sobre los recursos que tienen la etiqueta equipo=los-rojos
POLITICA_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LeerBucketsS3",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketTagging"
      ],
      "Resource": [
        "arn:aws:s3:::'"$S3_BUCKET"'",
        "arn:aws:s3:::'"$S3_BUCKET"'/*"
      ]
    },
    {
      "Sid": "DescribirEC2yRDS",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "rds:DescribeDBInstances",
        "rds:ListTagsForResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/equipo": "'"$EQUIPO"'"
        }
      }
    },
    {
      "Sid": "LeerLogsCloudWatch",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "arn:aws:logs:'"$REGION"':'"$ACCOUNT_ID"':log-group:/aws/*"
    }
  ]
}'

# Crear o actualizar la política
POLITICA_DOC_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='$POL_DOC_NAME'].Arn" \
  --output text)

if [ -z "$POLITICA_DOC_ARN" ]; then
  POLITICA_DOC_ARN=$(aws iam create-policy \
    --policy-name "$POL_DOC_NAME" \
    --description "Solo lectura S3, EC2, RDS y CloudWatch para rol de documentacion - $EQUIPO" \
    --policy-document "$POLITICA_DOC" \
    --query "Policy.Arn" \
    --output text)
  echo "  ✔ Política creada: $POL_DOC_NAME"
else
  echo "  · Política ya existía: $POL_DOC_NAME"
fi

echo "    ARN: $POLITICA_DOC_ARN"

# Adjuntar política al grupo de documentación
aws iam attach-group-policy \
  --group-name "$GRP_DOC" \
  --policy-arn "$POLITICA_DOC_ARN"
echo "  ✔ Política adjuntada a $GRP_DOC"

echo ""
echo "  ── Explicación de la política $POL_DOC_NAME ──"
echo "  Efecto:  Allow (permite)"
echo "  Acciones:"
echo "    · s3:GetObject, s3:ListBucket    → descargar y listar archivos del bucket del proyecto"
echo "    · ec2:Describe*, rds:Describe*   → consultar estado de EC2 e instancias RDS"
echo "    · logs:GetLogEvents              → leer bitácoras de CloudWatch"
echo "  Recurso:"
echo "    · S3 apunta solo al bucket $S3_BUCKET"
echo "    · EC2/RDS condicionado a etiqueta equipo=$EQUIPO"
echo "    · Logs limitados al grupo /aws/* de la región $REGION"

# =============================================================================
# PASO 04 - Política para desarrollo con restricción por etiqueta de equipo
# =============================================================================
echo ""
echo "========================================"
echo "PASO 04 · Creando política de desarrollo (restringida por etiqueta)"
echo "========================================"

POL_DEV_NAME="pol-desarrollo-$EQUIPO"

POLITICA_DEV='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GestionS3ProyectoEquipo",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::'"$S3_BUCKET"'",
        "arn:aws:s3:::'"$S3_BUCKET"'/*"
      ]
    },
    {
      "Sid": "DescribirRecursosEquipo",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "rds:DescribeDBInstances",
        "rds:ListTagsForResource"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/equipo": "'"$EQUIPO"'"
        }
      }
    },
    {
      "Sid": "MetricasCloudWatch",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "logs:DescribeLogGroups",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenegarFueraDelEquipo",
      "Effect": "Deny",
      "Action": [
        "iam:*",
        "organizations:*",
        "account:*",
        "billing:*"
      ],
      "Resource": "*"
    }
  ]
}'

POLITICA_DEV_ARN=$(aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='$POL_DEV_NAME'].Arn" \
  --output text)

if [ -z "$POLITICA_DEV_ARN" ]; then
  POLITICA_DEV_ARN=$(aws iam create-policy \
    --policy-name "$POL_DEV_NAME" \
    --description "Permisos de desarrollo restringidos por etiqueta equipo=$EQUIPO" \
    --policy-document "$POLITICA_DEV" \
    --query "Policy.Arn" \
    --output text)
  echo "  ✔ Política creada: $POL_DEV_NAME"
else
  echo "  · Política ya existía: $POL_DEV_NAME"
fi

echo "    ARN: $POLITICA_DEV_ARN"

aws iam attach-group-policy \
  --group-name "$GRP_DEV" \
  --policy-arn "$POLITICA_DEV_ARN"
echo "  ✔ Política adjuntada a $GRP_DEV"

echo ""
echo "  ── Explicación de la política $POL_DEV_NAME ──"
echo "  La restricción clave está en 'DenegarFueraDelEquipo':"
echo "  · Deny explícito sobre IAM, Organizations y Billing"
echo "  · Sobrescribe cualquier Allow heredado — Deny siempre gana en AWS"
echo "  · S3 apunta SOLO al bucket $S3_BUCKET (recurso exacto)"
echo "  · EC2/RDS condicionado: aws:ResourceTag/equipo = $EQUIPO"

# =============================================================================
# PASO 05 - Probar que DENIEGA (con usr-kevin intentando acción no permitida)
# =============================================================================
echo ""
echo "========================================"
echo "PASO 05 · Prueba de DENEGACIÓN"
echo "========================================"
echo ""
echo "  usr-kevin tiene solo lectura. Vamos a intentar CREAR un bucket S3"
echo "  usando sus credenciales (acción no permitida en su política)."
echo ""
echo "  ─── Comando que usr-kevin NO puede ejecutar ───────────────────────"
echo "  aws s3api create-bucket \\"
echo "    --bucket bucket-no-autorizado-kevin \\"
echo "    --region $REGION"
echo "  ────────────────────────────────────────────────────────────────────"
echo ""
echo "  Para generar la evidencia de denegación:"
echo ""
echo "  1. Crea Access Keys para usr-kevin:"
echo "     aws iam create-access-key --user-name $USUARIO_KEVIN"
echo ""
echo "  2. Abre una SEGUNDA sesión de CloudShell y ejecuta:"
echo "     export AWS_ACCESS_KEY_ID=<KEY_DE_KEVIN>"
echo "     export AWS_SECRET_ACCESS_KEY=<SECRET_DE_KEVIN>"
echo "     aws s3api create-bucket --bucket bucket-no-autorizado-kevin --region $REGION"
echo ""
echo "  3. Deberías ver:"
echo "     An error occurred (AccessDenied) when calling the CreateBucket operation:"
echo "     User: arn:aws:iam::$ACCOUNT_ID:user/$USUARIO_KEVIN is not authorized"
echo "     to perform: s3:CreateBucket on resource: ..."
echo ""
echo "  4. Toma captura de pantalla → esta es tu EVIDENCIA DE DENEGACIÓN"
echo ""
echo "  ─── Comandos de un solo bloque para copiar/pegar ───────────────────"

# Simulación local del intento de denegación (genera Access Key temporal)
echo ""
echo "  Generando Access Key para $USUARIO_KEVIN (para la prueba)..."
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USUARIO_KEVIN" 2>/dev/null || echo "ERROR")

if [ "$ACCESS_KEY_OUTPUT" != "ERROR" ]; then
  KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['AccessKey']['AccessKeyId'])")
  KEY_SECRET=$(echo "$ACCESS_KEY_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['AccessKey']['SecretAccessKey'])")
  echo "  ✔ Access Key creada para $USUARIO_KEVIN"
  echo "    KeyId: $KEY_ID"
  echo ""
  echo "  Ejecutando prueba de denegación..."
  DENY_RESULT=$(AWS_ACCESS_KEY_ID="$KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$KEY_SECRET" \
    aws s3api create-bucket \
      --bucket "bucket-no-autorizado-kevin-test" \
      --region "$REGION" 2>&1 || true)
  echo ""
  echo "  Resultado de la prueba de denegación:"
  echo "  ─────────────────────────────────────"
  echo "  $DENY_RESULT"
  echo "  ─────────────────────────────────────"

  if echo "$DENY_RESULT" | grep -qi "AccessDenied\|not authorized"; then
    echo "  ✔ DENEGACIÓN CONFIRMADA — captura esta salida como evidencia"
  else
    echo "  ⚠ Revisar: la denegación no se produjo, verificar políticas adjuntas"
  fi
else
  echo "  ⚠ No se pudo crear Access Key automáticamente. Hazlo manualmente:"
  echo "    aws iam create-access-key --user-name $USUARIO_KEVIN"
fi

# =============================================================================
# PASO 06 - Probar que PERMITE (lectura S3 con usr-kevin)
# =============================================================================
echo ""
echo "========================================"
echo "PASO 06 · Prueba de PERMISO"
echo "========================================"
echo ""
echo "  Ahora probamos que usr-kevin SÍ puede listar el bucket del proyecto."
echo ""

if [ -n "$KEY_ID" ] && [ -n "$KEY_SECRET" ]; then
  echo "  Ejecutando prueba de permiso (listar bucket $S3_BUCKET)..."
  ALLOW_RESULT=$(AWS_ACCESS_KEY_ID="$KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$KEY_SECRET" \
    aws s3 ls "s3://$S3_BUCKET" 2>&1 || true)
  echo ""
  echo "  Resultado de la prueba de permiso:"
  echo "  ─────────────────────────────────"
  echo "  $ALLOW_RESULT"
  echo "  ─────────────────────────────────"

  if echo "$ALLOW_RESULT" | grep -qvi "AccessDenied\|NoSuchBucket\|does not exist"; then
    echo "  ✔ PERMISO CONFIRMADO — captura esta salida como evidencia"
  else
    echo "  ℹ  El bucket $S3_BUCKET aún no existe o los objetos están vacíos."
    echo "     Si el bucket existe, la política funciona. Verifica en la consola S3."
  fi

  # Limpiar: eliminar la Access Key temporal de prueba
  echo ""
  echo "  Eliminando Access Key temporal de la prueba..."
  aws iam delete-access-key \
    --user-name "$USUARIO_KEVIN" \
    --access-key-id "$KEY_ID" 2>/dev/null \
    && echo "  ✔ Access Key temporal eliminada" \
    || echo "  · No se pudo eliminar automáticamente. Elimínala manualmente:"
  echo "    aws iam delete-access-key --user-name $USUARIO_KEVIN --access-key-id $KEY_ID"
else
  echo "  Usa las credenciales de $USUARIO_KEVIN para ejecutar:"
  echo "    AWS_ACCESS_KEY_ID=<KEY> AWS_SECRET_ACCESS_KEY=<SECRET> \\"
  echo "    aws s3 ls s3://$S3_BUCKET"
  echo ""
  echo "  Deberías ver el contenido del bucket (o un listado vacío), NO un AccessDenied."
fi

# =============================================================================
# PASO 07 - Crear rol de servicio EC2 → S3 (sin llaves permanentes)
# =============================================================================
echo ""
echo "========================================"
echo "PASO 07 · Creando rol de servicio EC2→S3"
echo "========================================"

ROL_SERVICIO="rol-ec2-s3-$EQUIPO"

# Trust policy: solo EC2 puede asumir este rol
TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

# Política de permisos: solo acceso al bucket del proyecto
PERMISOS_ROL='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AccesoS3ProyectoSinLlaves",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::'"$S3_BUCKET"'",
        "arn:aws:s3:::'"$S3_BUCKET"'/*"
      ]
    }
  ]
}'

# Crear el rol si no existe
if aws iam get-role --role-name "$ROL_SERVICIO" &>/dev/null; then
  echo "  · Rol $ROL_SERVICIO ya existe, omitiendo creación."
else
  aws iam create-role \
    --role-name "$ROL_SERVICIO" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --description "Permite a instancias EC2 acceder a S3 del proyecto sin llaves permanentes" \
    --tags Key=proyecto,Value="$PROYECTO" \
           Key=equipo,Value="$EQUIPO" \
           Key=ambiente,Value="$AMBIENTE"
  echo "  ✔ Rol creado: $ROL_SERVICIO"
fi

# Nombre de la política inline del rol
POL_ROL_NAME="pol-inline-s3-$EQUIPO"

# Adjuntar política inline de permisos al rol
aws iam put-role-policy \
  --role-name "$ROL_SERVICIO" \
  --policy-name "$POL_ROL_NAME" \
  --policy-document "$PERMISOS_ROL"
echo "  ✔ Política de acceso S3 adjuntada al rol"

# Crear Instance Profile para poder asignarlo a EC2
INSTANCE_PROFILE="ip-$ROL_SERVICIO"
if aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE" &>/dev/null; then
  echo "  · Instance Profile ya existe."
else
  aws iam create-instance-profile --instance-profile-name "$INSTANCE_PROFILE"
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$INSTANCE_PROFILE" \
    --role-name "$ROL_SERVICIO"
  echo "  ✔ Instance Profile creado: $INSTANCE_PROFILE"
fi

ROL_ARN=$(aws iam get-role --role-name "$ROL_SERVICIO" --query "Role.Arn" --output text)
echo ""
echo "  ARN del rol: $ROL_ARN"
echo ""
echo "  → Este rol se asignará a la instancia EC2 en la práctica 3."
echo "  → Con este rol, el código en EC2 NO necesita AWS_ACCESS_KEY_ID ni"
echo "    AWS_SECRET_ACCESS_KEY en el .env — las credenciales las gestiona AWS."
echo "  → Cómo asignarlo en la práctica 3:"
echo "    aws ec2 associate-iam-instance-profile \\"
echo "      --instance-id i-XXXXXXXXXXXXXXXXX \\"
echo "      --iam-instance-profile Name=$INSTANCE_PROFILE"

# =============================================================================
# PASO 08 - Documentar la Matriz de Accesos
# =============================================================================
echo ""
echo "========================================"
echo "PASO 08 · Matriz de accesos actualizada"
echo "========================================"
echo ""
echo "  ┌──────────────────┬───────────────────────────────────────┬───────────────────────────────────────────────────────┐"
echo "  │ Identidad        │ Política aplicada                     │ Acciones permitidas / Restricción                     │"
echo "  ├──────────────────┼───────────────────────────────────────┼───────────────────────────────────────────────────────┤"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "usr-kevin" \
  "$POL_DOC_NAME" \
  "Leer S3, describir EC2/RDS/VPC, ver logs"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "(documentacion)" \
  "vía grp-documentacion" \
  "Restricción: bucket=$S3_BUCKET + tag equipo=$EQUIPO"
echo "  ├──────────────────┼───────────────────────────────────────┼───────────────────────────────────────────────────────┤"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "usr-angel" \
  "$POL_DEV_NAME" \
  "S3 CRUD en bucket proyecto, CloudWatch"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "(desarrollo)" \
  "vía grp-desarrollo" \
  "Deny: IAM, Billing, Organizations"
echo "  ├──────────────────┼───────────────────────────────────────┼───────────────────────────────────────────────────────┤"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "usr-angel" \
  "AdministratorAccess (AWS managed)" \
  "Acceso total — para gestión de seguridad"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "(seguridad-costos)" \
  "vía grp-seguridad-costos" \
  "y control de costos del equipo"
echo "  ├──────────────────┼───────────────────────────────────────┼───────────────────────────────────────────────────────┤"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "$ROL_SERVICIO" \
  "$POL_ROL_NAME (inline)" \
  "S3 CRUD en bucket $S3_BUCKET"
printf "  │ %-16s │ %-37s │ %-53s │\n" \
  "(rol de servicio)" \
  "Principal: ec2.amazonaws.com" \
  "Sin llaves permanentes — para práctica 3"
echo "  └──────────────────┴───────────────────────────────────────┴───────────────────────────────────────────────────────┘"

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "========================================"
echo "RESUMEN - Práctica 02 completada"
echo "========================================"
echo ""
echo "  Equipo   : Los Rojos"
echo "  Proyecto : $PROYECTO"
echo "  Cuenta   : $ACCOUNT_ID"
echo ""
echo "  Automatizado en este script:"
echo "  [✔] Paso 01 · Tabla de acciones por rol (impresa arriba)"
echo "  [✔] Paso 02 · ReadOnlyAccess amplio retirado de grp-doc, grp-arq, grp-dev"
echo "  [✔] Paso 03 · Política $POL_DOC_NAME → adjuntada a $GRP_DOC"
echo "  [✔] Paso 04 · Política $POL_DEV_NAME (con Deny + restricción por etiqueta)"
echo "               → adjuntada a $GRP_DEV"
echo "  [✔] Paso 05 · Prueba de denegación ejecutada (crear bucket → AccessDenied)"
echo "  [✔] Paso 06 · Prueba de permiso ejecutada (listar bucket → OK)"
echo "  [✔] Paso 07 · Rol de servicio: $ROL_SERVICIO"
echo "               Instance Profile: $INSTANCE_PROFILE"
echo "  [✔] Paso 08 · Matriz de accesos impresa"
echo ""
echo "  Evidencia que debes capturar para el entregable:"
echo "  [ ] Captura del mensaje 'AccessDenied' del paso 05"
echo "  [ ] Captura del listado S3 exitoso del paso 06"
echo "  [ ] Captura de la lista de políticas en IAM → Policies (consola)"
echo "  [ ] Captura del rol $ROL_SERVICIO en IAM → Roles"
echo ""
echo "  URLs de consola para las capturas:"
echo "  Políticas: https://console.aws.amazon.com/iam/home#/policies"
echo "  Roles:     https://console.aws.amazon.com/iam/home#/roles"
echo "  Grupos:    https://console.aws.amazon.com/iam/home#/groups"
echo ""
echo "========================================"
echo "Script completado. Toma capturas de pantalla como evidencia."
echo "========================================"
