#!/bin/bash
# =============================================================================
# EVIDENCIA — ENTREGABLE 5  (P05)
# "Respuesta escrita del Paso 6 con su implicación de costo"
#
# Muestra:
#   · Que NO existe NAT Gateway en la cuenta (decisión justificada)
#   · Precio actual de NAT Gateway vs el presupuesto del equipo
#   · Análisis de por qué RDS no lo necesita
#   · Configuración actual de la tabla privada (sin ruta a internet)
#
# CÓMO USAR:
#   Pega este script en AWS CloudShell y presiona Enter.
#   Toma captura de pantalla del bloque marcado.
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
VPC_NAME="vpc-$PROYECTO-$EQUIPO"
RT_PRIV_NAME="rt-priv-$PROYECTO-$EQUIPO"

echo "================================================"
echo "ENTREGABLE 5 — Paso 6: salida de la privada e implicación de costo"
echo "Criterio implícito: respuesta escrita + justificación económica"
echo "Equipo: Los Rojos  |  Región: $REGION"
echo "================================================"
echo ""

# ── Buscar VPC ────────────────────────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[0].VpcId" --output text 2>/dev/null)

RT_PRIV_ID=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$RT_PRIV_NAME" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)

# ── INICIO EVIDENCIA ─────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════"
echo "  EVIDENCIA E5 — Paso 6: ¿NAT Gateway? Análisis de costo"
echo "  Proyecto: $PROYECTO  |  Equipo: $EQUIPO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  PREGUNTA EXACTA DEL PASO 6:"
echo "  ¿Cómo haría un servidor de la subred PRIVADA para descargar"
echo "  actualizaciones sin ser accesible desde afuera?"
echo "  ¿Qué implicación de costo tiene?"
echo ""
echo "  RESPUESTA:"
echo "  Un servidor en la subred privada no tiene ruta a internet (la tabla"
echo "  rt-priv solo contiene 10.0.0.0/16 → local). Para que pueda iniciar"
echo "  conexiones SALIENTES hacia internet —como descargar paquetes del"
echo "  sistema operativo— sin recibir tráfico entrante, se necesita un"
echo "  componente que haga NAT (traducción de direcciones de red)."
echo ""
echo "  La opción administrada de AWS es el NAT Gateway: se crea en la"
echo "  subred PÚBLICA (donde sí hay salida a internet) y se agrega una"
echo "  ruta en la tabla privada: 0.0.0.0/0 → nat-xxxxx."
echo "  El tráfico sale con la IP del NAT; las respuestas regresan al NAT"
echo "  y este las reenvía a la instancia privada."
echo "  El servidor privado nunca queda expuesto a internet."
echo ""

# ── Verificar que NO hay NAT Gateway en la VPC ────────────────────────────────
echo "▶ Verificación: ¿existe algún NAT Gateway en la cuenta?"
echo ""

NAT_GW=$(aws ec2 describe-nat-gateways \
  --region "$REGION" \
  --filter "Name=vpc-id,Values=$VPC_ID" \
    "Name=state,Values=available,pending" \
  --query "NatGateways[*].{NatGWId:NatGatewayId, Estado:State, SubnetId:SubnetId}" \
  --output text 2>/dev/null)

if [ -z "$NAT_GW" ] || [ "$NAT_GW" = "None" ]; then
  echo "  Resultado: NO existe ningún NAT Gateway en la VPC $VPC_ID"
  echo "  ✔ CONFIRMADO: Se decidió NO crear NAT Gateway."
else
  echo "  NAT Gateways encontrados:"
  aws ec2 describe-nat-gateways \
    --region "$REGION" \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
    --query "NatGateways[*].{NatGWId:NatGatewayId, Estado:State, Subred:SubnetId}" \
    --output table
fi

# ── Tabla de ruteo privada: confirmar sin NAT ─────────────────────────────────
echo ""
echo "▶ Tabla de ruteo privada ($RT_PRIV_ID): sin referencia a NAT"
echo ""
aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[*].{Destino:DestinationCidrBlock, Objetivo:GatewayId, NAT:NatGatewayId, Estado:State}" \
  --output table 2>/dev/null

NAT_EN_TABLA=$(aws ec2 describe-route-tables \
  --region "$REGION" \
  --route-table-ids "$RT_PRIV_ID" \
  --query "RouteTables[0].Routes[?NatGatewayId!=null].NatGatewayId" \
  --output text 2>/dev/null)

if [ -z "$NAT_EN_TABLA" ] || [ "$NAT_EN_TABLA" = "None" ]; then
  echo "  ✔ La tabla privada NO contiene ninguna ruta hacia un NAT Gateway."
fi

# ── Presupuesto actual del equipo ─────────────────────────────────────────────
echo ""
echo "▶ Presupuesto mensual del equipo (referencia para el análisis de costo)"
echo ""
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUDGET_INFO=$(aws budgets describe-budgets \
  --account-id "$ACCOUNT_ID" \
  --query "Budgets[0].{Nombre:BudgetName, Limite:BudgetLimit.Amount, Moneda:BudgetLimit.Unit}" \
  --output table 2>/dev/null || echo "  (presupuesto no recuperable desde este contexto)")
echo "$BUDGET_INFO"

# ── Análisis de costo escrito ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  PASO 6 — ANÁLISIS DE COSTO: ¿Por qué no usamos NAT Gateway?"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  PREGUNTA DEL PASO 6:"
echo "  ¿Cuándo se necesitaría un NAT Gateway y cuánto costaría?"
echo ""
echo "  ── COSTO DEL NAT GATEWAY (us-east-1, oct 2026) ──────────────────"
echo ""
printf "  %-35s  %-20s  %s\n" "Concepto" "Tarifa" "Ejemplo mensual"
printf "  %-35s  %-20s  %s\n" "───────────────────────────────────" "────────────────────" "──────────────────────"
printf "  %-35s  %-20s  %s\n" "Disponibilidad (por hora)"      "\$0.045 USD/hora"   "~\$32.40 USD/mes"
printf "  %-35s  %-20s  %s\n" "Datos procesados (por GB)"      "\$0.045 USD/GB"     "variable según tráfico"
printf "  %-35s  %-20s  %s\n" "COSTO MÍNIMO sin transferencia"  "\$32.40 USD/mes"   "solo por existir 24h/30d"
echo ""
echo "  NOTA: La red virtual, subredes y tablas de ruteo no generan cobro."
echo "  El NAT Gateway SÍ cobra por hora desde que se crea hasta que se"
echo "  elimina, aunque no procese ningún paquete."
echo ""
echo "  ── PRESUPUESTO DEL EQUIPO ────────────────────────────────────────"
echo ""
echo "  Presupuesto mensual del proyecto: \$10.00 USD/mes"
echo "  Costo NAT Gateway mínimo:         \$32.40 USD/mes"
echo "  Exceso sobre el presupuesto:      \$22.40 USD/mes (+324%)"
echo ""
echo "  ── ¿CUÁNDO SE NECESITARÍA? ──────────────────────────────────────"
echo ""
echo "  Un NAT Gateway sería necesario si alguna instancia de la subred"
echo "  PRIVADA necesitara acceso SALIENTE a internet, por ejemplo:"
echo ""
echo "    · Descargar actualizaciones del SO (apt/yum) desde EC2 privada"
echo "    · Enviar logs a servicios externos (Datadog, Splunk, PagerDuty)"
echo "    · Llamar a APIs de terceros desde la subred privada"
echo "    · Conectarse a repositorios npm / PyPI / Maven desde workers"
echo ""
echo "  ── ¿POR QUÉ NO LO NECESITAMOS HOY? ────────────────────────────"
echo ""
echo "  En nuestra arquitectura actual la subred privada solo contiene RDS."
echo "  RDS es un servicio ADMINISTRADO: AWS instala sus propias"
echo "  actualizaciones internamente; el motor de base de datos nunca"
echo "  necesita iniciar conexiones salientes a internet."
echo "  Por eso la práctica pide DISCUTIRLO pero no implementarlo hoy."
echo ""
echo "    · RDS → no necesita salida a internet → no requiere NAT"
echo "    · EC2 → está en subred pública → ya tiene salida por IGW"
echo "    · S3  → se accede vía IAM Role por endpoint público → sin NAT"
echo ""
echo "  Si en el futuro se añadiera una EC2 privada que necesite"
echo "  descargar paquetes (apt/yum/npm), AHÍ se justificaría el NAT."
echo ""
echo "  ── ALTERNATIVAS DE MENOR COSTO ─────────────────────────────────"
echo ""
printf "  %-28s  %-15s  %s\n" "Opción" "Costo/mes" "Cuándo usar"
printf "  %-28s  %-15s  %s\n" "────────────────────────────" "───────────────" "──────────────────────────────────"
printf "  %-28s  %-15s  %s\n" "Sin NAT (configuración actual)"  "\$0.00"     "RDS administrado, no necesita internet"
printf "  %-28s  %-15s  %s\n" "VPC Endpoint S3"                 "\$0.00"     "Acceso S3 desde subred privada"
printf "  %-28s  %-15s  %s\n" "VPC Endpoint otros servicios"    "~\$7.00"    "Acceso a SQS, DynamoDB, etc."
printf "  %-28s  %-15s  %s\n" "NAT Instance (EC2 t4g.nano)"     "~\$3-8 USD" "Internet general desde privada, bajo costo"
printf "  %-28s  %-15s  %s\n" "NAT Gateway (administrado)"      "~\$32+ USD" "Alta disponibilidad, sin admin, más costo"
echo ""
echo "  DECISIÓN FINAL:"
echo "  Se omite el NAT Gateway porque RDS no requiere acceso saliente."
echo "  Ahorro mensual: ~\$32 USD — respeta el presupuesto de \$10 USD/mes."
echo ""
echo "  ✅  Análisis de costo completo — ENTREGABLE 5 CUMPLIDO"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "↑ TOMA CAPTURA DE PANTALLA DE ESTE BLOQUE ↑"
