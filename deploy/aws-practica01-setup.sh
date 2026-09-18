#!/bin/bash
# =============================================================================
# PRÁCTICA 01 - Configuración inicial de cuenta AWS
# Pasos 06-10: Usuarios, grupos, región, presupuesto y etiquetas
#
# USO EN AWS CLOUDSHELL:
#   1. Abre CloudShell desde la consola AWS (ícono de terminal en la barra superior)
#   2. Edita las variables de la sección CONFIGURACIÓN justo abajo
#   3. Pega todo el script en CloudShell y presiona Enter
#      (CloudShell ya tiene tus credenciales activas, no necesitas aws configure)
#
# REQUISITOS PREVIOS (manuales, no se pueden automatizar con CLI):
#   - Paso 01: Correo del equipo ya creado
#   - Paso 02: Plan gratuito seleccionado al registrarse
#   - Paso 03: Validación de tarjeta completada
#   - Paso 04: Saldo de créditos anotado en la bitácora
#   - Paso 05: MFA en usuario raíz activado desde la consola
#              (Consola → IAM → Dashboard → "Add MFA for root user")
# =============================================================================

set -e  # Detener ante cualquier error

# =============================================================================
# CONFIGURACIÓN - Edita estos valores antes de ejecutar
# =============================================================================

# Nombre del proyecto (sin espacios, en minúsculas)
PROYECTO="inventario-cloud"
# Nombre del equipo (sin espacios)
EQUIPO="los-rojos"
# Ambiente (dev / staging / prod)
AMBIENTE="dev"
# Región de trabajo (una sola durante todo el semestre)
REGION="us-east-1"
# Correo del equipo para alertas de presupuesto
CORREO_ALERTAS="angek234122@gmail.com"
# Monto mensual del presupuesto en USD
PRESUPUESTO_USD="10"

# Integrantes del equipo: "usuario:rol-principal"
# Kevin tiene roles: documentacion + arquitectura  → grupo principal: documentacion
# Angel tiene roles: desarrollo + seguridad-costos → grupo principal: seguridad-costos
INTEGRANTES=(
  "usr-kevin:documentacion"
  "usr-angel:seguridad-costos"
)

# =============================================================================
# PASO 08 - Fijar región de trabajo
# =============================================================================
echo ""
echo "========================================"
echo "PASO 08 · Configurando región: $REGION"
echo "========================================"
aws configure set region "$REGION"
echo "✔ Región configurada: $REGION"
echo "  → Anota esta región en la bitácora. No cambiar durante el semestre."

# =============================================================================
# PASO 06 - Crear usuarios individuales (uno por integrante)
# =============================================================================
echo ""
echo "========================================"
echo "PASO 06 · Creando usuarios individuales"
echo "========================================"

for entrada in "${INTEGRANTES[@]}"; do
  USUARIO="${entrada%%:*}"
  ROL="${entrada##*:}"

  # Crear usuario si no existe
  if aws iam get-user --user-name "$USUARIO" &>/dev/null; then
    echo "  · Usuario $USUARIO ya existe, omitiendo creación."
  else
    aws iam create-user --user-name "$USUARIO" \
      --tags Key=proyecto,Value="$PROYECTO" \
             Key=equipo,Value="$EQUIPO" \
             Key=ambiente,Value="$AMBIENTE" \
             Key=rol,Value="$ROL"
    echo "  ✔ Usuario creado: $USUARIO (rol: $ROL)"
  fi

  # Crear perfil de acceso a la consola con contraseña temporal
  # El integrante deberá cambiarla en el primer inicio de sesión
  CONTRASENA_TEMP="Cambiar@$(date +%Y)01!"
  aws iam create-login-profile \
    --user-name "$USUARIO" \
    --password "$CONTRASENA_TEMP" \
    --password-reset-required 2>/dev/null || \
    echo "    (Perfil de consola ya existía para $USUARIO)"

  echo "    Contraseña temporal: $CONTRASENA_TEMP  ← Entregar en mano al integrante"
done

# =============================================================================
# PASO 07 - Crear grupos por rol y asignar permisos
# =============================================================================
echo ""
echo "========================================"
echo "PASO 07 · Creando grupos por rol"
echo "========================================"

# Definición: "grupo:política_aws"
# Todos los grupos arrancan con solo lectura, excepto seguridad-costos
declare -A GRUPOS=(
  ["grp-arquitectura"]="ReadOnlyAccess"
  ["grp-desarrollo"]="ReadOnlyAccess"
  ["grp-seguridad-costos"]="AdministratorAccess"
  ["grp-documentacion"]="ReadOnlyAccess"
)

for GRUPO in "${!GRUPOS[@]}"; do
  POLITICA="${GRUPOS[$GRUPO]}"

  if aws iam get-group --group-name "$GRUPO" &>/dev/null; then
    echo "  · Grupo $GRUPO ya existe, omitiendo creación."
  else
    aws iam create-group --group-name "$GRUPO"
    echo "  ✔ Grupo creado: $GRUPO"
  fi

  # Adjuntar política
  POLITICA_ARN="arn:aws:iam::aws:policy/$POLITICA"
  aws iam attach-group-policy \
    --group-name "$GRUPO" \
    --policy-arn "$POLITICA_ARN"
  echo "    Política aplicada: $POLITICA"
done

# Asignar cada usuario a su(s) grupo(s) correspondiente(s)
# Kevin  → grp-documentacion + grp-arquitectura
# Angel  → grp-seguridad-costos + grp-desarrollo
echo ""
echo "  Asignando usuarios a grupos..."

aws iam add-user-to-group --user-name "usr-kevin" --group-name "grp-documentacion"
echo "  ✔ usr-kevin → grp-documentacion  (Responsable de documentación)"

aws iam add-user-to-group --user-name "usr-kevin" --group-name "grp-arquitectura"
echo "  ✔ usr-kevin → grp-arquitectura   (Arquitectura de la solución)"

aws iam add-user-to-group --user-name "usr-angel" --group-name "grp-seguridad-costos"
echo "  ✔ usr-angel → grp-seguridad-costos  (Responsable de seguridad y costos)"

aws iam add-user-to-group --user-name "usr-angel" --group-name "grp-desarrollo"
echo "  ✔ usr-angel → grp-desarrollo        (Responsable de desarrollo)"

# =============================================================================
# PASO 09 - Configurar presupuesto mensual con alertas
# =============================================================================
echo ""
echo "========================================"
echo "PASO 09 · Configurando presupuesto"
echo "========================================"

# Obtener el ID de la cuenta
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  Account ID: $ACCOUNT_ID"

# Nombre del presupuesto
BUDGET_NAME="Presupuesto-Semestral-$EQUIPO"

# Calcular el primer día del mes actual y del siguiente
INICIO=$(date -u +"%Y-%m-01T00:00:00Z")

# Crear el presupuesto con alertas al 50% y 80%
aws budgets create-budget \
  --account-id "$ACCOUNT_ID" \
  --budget "{
    \"BudgetName\": \"$BUDGET_NAME\",
    \"BudgetLimit\": {
      \"Amount\": \"$PRESUPUESTO_USD\",
      \"Unit\": \"USD\"
    },
    \"TimeUnit\": \"MONTHLY\",
    \"BudgetType\": \"COST\",
    \"CostFilters\": {},
    \"CostTypes\": {
      \"IncludeTax\": true,
      \"IncludeSubscription\": true,
      \"UseBlended\": false,
      \"IncludeRefund\": false,
      \"IncludeCredit\": false,
      \"IncludeUpfront\": true,
      \"IncludeRecurring\": true,
      \"IncludeOtherSubscription\": true,
      \"IncludeSupport\": true,
      \"IncludeDiscount\": true,
      \"UseAmortized\": false
    }
  }" \
  --notifications-with-subscribers "[
    {
      \"Notification\": {
        \"NotificationType\": \"ACTUAL\",
        \"ComparisonOperator\": \"GREATER_THAN\",
        \"Threshold\": 50,
        \"ThresholdType\": \"PERCENTAGE\"
      },
      \"Subscribers\": [{
        \"SubscriptionType\": \"EMAIL\",
        \"Address\": \"$CORREO_ALERTAS\"
      }]
    },
    {
      \"Notification\": {
        \"NotificationType\": \"ACTUAL\",
        \"ComparisonOperator\": \"GREATER_THAN\",
        \"Threshold\": 80,
        \"ThresholdType\": \"PERCENTAGE\"
      },
      \"Subscribers\": [{
        \"SubscriptionType\": \"EMAIL\",
        \"Address\": \"$CORREO_ALERTAS\"
      }]
    }
  ]" && echo "  ✔ Presupuesto creado: $BUDGET_NAME (\$$PRESUPUESTO_USD/mes)" \
  || echo "  · El presupuesto ya existe o hubo un error. Verifica en la consola."

echo "  → Confirma que la alerta llegó a: $CORREO_ALERTAS"
echo "  → Revisa también la carpeta de no deseados"

# =============================================================================
# PASO 10 - Documentar esquema de etiquetas
# =============================================================================
echo ""
echo "========================================"
echo "PASO 10 · Esquema de etiquetas acordado"
echo "========================================"
echo ""
echo "  Las siguientes etiquetas deben aplicarse a TODOS los recursos:"
echo ""
echo "  ┌──────────────┬──────────────────────────────────────────┐"
echo "  │ Clave        │ Valor para este proyecto                 │"
echo "  ├──────────────┼──────────────────────────────────────────┤"
printf "  │ %-12s │ %-40s │\n" "proyecto"  "$PROYECTO"
printf "  │ %-12s │ %-40s │\n" "equipo"    "$EQUIPO"
printf "  │ %-12s │ %-40s │\n" "ambiente"  "$AMBIENTE"
echo "  └──────────────┴──────────────────────────────────────────┘"
echo ""
echo "  Ejemplo de uso en AWS CLI:"
echo "    --tags Key=proyecto,Value=$PROYECTO Key=equipo,Value=$EQUIPO Key=ambiente,Value=$AMBIENTE"
echo ""
echo "  Ejemplo en CloudFormation / SAM:"
echo "    Tags:"
echo "      proyecto: $PROYECTO"
echo "      equipo:   $EQUIPO"
echo "      ambiente: $AMBIENTE"

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo ""
echo "========================================"
echo "RESUMEN - Tareas que requieren consola"
echo "========================================"
echo ""
echo "  Equipo  : Los Rojos"
echo "  Materia : Computo en la Nube"
echo "  Maestra : Elizabeth Gaxiola Carrillo"
echo ""
echo "  Integrantes y grupos asignados:"
echo "  ┌──────────────────────────────────┬───────────────────────────────────────────────────┐"
echo "  │ Integrante                       │ Grupos IAM                                        │"
echo "  ├──────────────────────────────────┼───────────────────────────────────────────────────┤"
echo "  │ López Payán Kevin Ricardo        │ grp-documentacion, grp-arquitectura               │"
echo "  │ (usr-kevin)                      │ Permisos: ReadOnlyAccess                          │"
echo "  ├──────────────────────────────────┼───────────────────────────────────────────────────┤"
echo "  │ Flores Guevara Ángel Gabriel     │ grp-seguridad-costos, grp-desarrollo              │"
echo "  │ (usr-angel)                      │ Permisos: AdministratorAccess + ReadOnlyAccess    │"
echo "  └──────────────────────────────────┴───────────────────────────────────────────────────┘"
echo ""
echo "  Manual (no automatizable con CLI):"
echo "  [ ] Paso 05 → Activar MFA en usuario raíz:"
echo "      Consola AWS → IAM → Dashboard → 'Add MFA for root user'"
echo "  [ ] Paso 06 → Cada integrante activa su propio MFA al primer inicio de sesión"
echo "  [ ] Verificar saldo de créditos:"
echo "      Consola → Billing → Credits → anotar en la bitácora"
echo "  [ ] Cambiar CORREO_ALERTAS por el correo real del equipo si no lo hiciste"
echo ""
echo "  Automatizado en este script:"
echo "  [✔] Paso 06 · Usuarios: usr-kevin, usr-angel"
echo "  [✔] Paso 07 · Grupos: grp-documentacion, grp-arquitectura, grp-desarrollo, grp-seguridad-costos"
echo "  [✔] Paso 08 · Región configurada: $REGION"
echo "  [✔] Paso 09 · Presupuesto \$$PRESUPUESTO_USD/mes con alertas al 50% y 80%"
echo "  [✔] Paso 10 · Esquema de etiquetas: proyecto=$PROYECTO, equipo=$EQUIPO, ambiente=$AMBIENTE"
echo ""
echo "  Restricciones del plan gratuito (Paso 11 - anotar en reporte):"
echo "  [1] No permite Reserved Instances ni Savings Plans"
echo "  [2] No da acceso al AWS Marketplace de soluciones de terceros"
echo "  [3] Unirse a una AWS Organization cancela los créditos de inmediato"
echo ""
echo "========================================"
echo "Script completado. Toma capturas de pantalla de la consola como evidencia."
echo "========================================"
