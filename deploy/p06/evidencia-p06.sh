#!/bin/bash
# =============================================================================
# EVIDENCIA — PRÁCTICA 06
# "Base de datos del proyecto en subred privada"
# Equipo: Los Rojos  |  Fecha: 13 oct 2026
#
# ESTRUCTURA DE CAPTURAS QUE GENERA ESTE SCRIPT:
#   E1 — Base desplegada: sin IP pública y cifrado activo
#   E2 — Intento FALLIDO de conexión desde fuera de la red (local → RDS)
#   E3 — Conexión EXITOSA desde el servidor EC2
#   E4 — Esquema creado y consulta con resultados
#   E5 — Periodo de retención de respaldos y su implicación
#   E6 — Detener el servidor y la base al finalizar
#
# DÓNDE EJECUTAR CADA PARTE:
#   E1, E5, E6 → AWS CloudShell (tiene credenciales de la cuenta)
#   E2         → Tu equipo local (Windows/Mac) — debe FALLAR
#   E3, E4     → Dentro del servidor EC2 vía SSH
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
DB_IDENTIFIER="rds-$PROYECTO-$EQUIPO"
EC2_NAME="ec2-$PROYECTO-$EQUIPO"
SG_RDS_NAME="rds-$PROYECTO-$EQUIPO"
SG_EC2_NAME="ec2-$PROYECTO-$EQUIPO"

# =============================================================================
# ██████████████████████████████████████████████████████████████████████████
# PARTE A — Ejecutar en AWS CloudShell
# ██████████████████████████████████████████████████████████████████████████
# =============================================================================

mostrar_e1_base_desplegada() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "  EVIDENCIA 1 — Base desplegada: sin acceso público y cifrado activo"
  echo "  Criterio lista de cotejo: 25 pts (subred privada) + 10 pts (cifrado)"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""

  # Datos generales de la instancia
  aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].{
      Identificador:DBInstanceIdentifier,
      Motor:Engine,
      Version:EngineVersion,
      Clase:DBInstanceClass,
      Estado:DBInstanceStatus,
      IP_Publica:PubliclyAccessible,
      Cifrado:StorageEncrypted,
      AZ:AvailabilityZone,
      Puerto:Endpoint.Port,
      Endpoint:Endpoint.Address
    }" \
    --output table

  echo ""
  echo "  Verificación de criterios:"
  IP_PUB=$(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].PubliclyAccessible" --output text)

  CIFRADO=$(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].StorageEncrypted" --output text)

  SUBNET_GRP=$(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].DBSubnetGroup.DBSubnetGroupName" --output text)

  if [ "$IP_PUB" = "False" ]; then
    echo "  ✔ PubliclyAccessible = False  → Sin IP pública, fuera del alcance de internet"
  else
    echo "  ✗ PubliclyAccessible = True   → REVISAR: la base NO debería ser pública"
  fi

  if [ "$CIFRADO" = "True" ]; then
    echo "  ✔ StorageEncrypted = True     → Cifrado en reposo activo (AES-256, AWS KMS)"
  else
    echo "  ✗ StorageEncrypted = False    → REVISAR: el cifrado no está activo"
  fi

  echo "  · DB Subnet Group: $SUBNET_GRP"
  echo ""

  # Subredes del DB Subnet Group
  echo "  Subredes incluidas en el grupo:"
  aws rds describe-db-subnet-groups \
    --region "$REGION" \
    --db-subnet-group-name "$SUBNET_GRP" \
    --query "DBSubnetGroups[0].Subnets[*].{SubnetId:SubnetIdentifier,AZ:SubnetAvailabilityZone.Name,Estado:SubnetStatus}" \
    --output table

  echo ""

  # Grupo de seguridad: confirmar que no hay 0.0.0.0/0 en el puerto 5432
  VPC_ID=$(aws ec2 describe-vpcs \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=vpc-$PROYECTO-$EQUIPO" \
    --query "Vpcs[0].VpcId" --output text)

  SG_RDS_ID=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=group-name,Values=$SG_RDS_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text)

  SG_EC2_ID=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=group-name,Values=$SG_EC2_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text)

  echo "  Reglas de entrada del SG de RDS ($SG_RDS_ID):"
  aws ec2 describe-security-groups \
    --region "$REGION" \
    --group-ids "$SG_RDS_ID" \
    --query "SecurityGroups[0].IpPermissions[].{
      Puerto:FromPort,
      Protocolo:IpProtocol,
      Origen_SG:UserIdGroupPairs[0].GroupId,
      Origen_CIDR:IpRanges[0].CidrIp
    }" \
    --output table

  ORIGEN=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --group-ids "$SG_RDS_ID" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\`].UserIdGroupPairs[0].GroupId" \
    --output text)

  if [ "$ORIGEN" = "$SG_EC2_ID" ]; then
    echo "  ✔ Puerto 5432 permite SOLO al grupo $SG_EC2_ID (EC2)"
    echo "  ✔ 0.0.0.0/0 NO aparece → criterio 20 pts cumplido"
  else
    echo "  ✗ REVISAR: el origen del puerto 5432 no es el SG de EC2"
  fi

  echo ""
  echo "↑ TOMA CAPTURA — EVIDENCIA 1 ↑"
  echo "════════════════════════════════════════════════════════════════════"
}

mostrar_e5_respaldos() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "  EVIDENCIA 5 — Periodo de retención de respaldos y RPO"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""

  aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].{
      Instancia:DBInstanceIdentifier,
      Retencion_dias:BackupRetentionPeriod,
      Ventana_respaldo:PreferredBackupWindow,
      Ventana_mantenimiento:PreferredMaintenanceWindow,
      Estado:DBInstanceStatus
    }" \
    --output table

  echo ""
  echo "  Análisis del RPO (Recovery Point Objective):"
  echo ""
  echo "  · Retención configurada  : 7 días"
  echo "  · Ventana de respaldo    : 05:00–06:00 UTC (fuera de horario laboral)"
  echo "  · Frecuencia             : Automática, una vez al día"
  echo ""
  echo "  · RPO resultante         : ~24 horas"
  echo "    → En el peor caso, si la base falla justo antes del respaldo,"
  echo "      se pierden hasta 24 h de transacciones."
  echo "    → Para la miscelánea es aceptable: los movimientos del día"
  echo "      se pueden reconstruir a partir de notas físicas en caja."
  echo ""
  echo "  · Implicación para práctica 15 (punto de restauración):"
  echo "    Con 7 días de retención se puede restaurar a cualquier punto"
  echo "    dentro de esa ventana usando Point-in-Time Recovery (PITR)."
  echo "    Esto supera el RPO de 24 h del respaldo diario."
  echo ""
  echo "↑ TOMA CAPTURA — EVIDENCIA 5 ↑"
  echo "════════════════════════════════════════════════════════════════════"
}

mostrar_e6_detener() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "  EVIDENCIA 6 — Detener recursos al terminar (control de costos)"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""

  # Detener servidor EC2
  EC2_ID=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=$EC2_NAME" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" --output text)

  if [ "$EC2_ID" != "None" ] && [ -n "$EC2_ID" ]; then
    aws ec2 stop-instances --region "$REGION" --instance-ids "$EC2_ID" \
      --query "StoppingInstances[0].{ID:InstanceId,Estado_anterior:PreviousState.Name,Estado_nuevo:CurrentState.Name}" \
      --output table
    echo "  ✔ Servidor EC2 detenido: $EC2_ID"
  else
    echo "  · EC2 no encontrado en estado 'running' con nombre $EC2_NAME"
  fi

  echo ""

  # Detener instancia RDS
  DB_STATUS=$(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null || echo "NotFound")

  if [ "$DB_STATUS" = "available" ]; then
    aws rds stop-db-instance \
      --region "$REGION" \
      --db-instance-identifier "$DB_IDENTIFIER" \
      --query "DBInstance.{ID:DBInstanceIdentifier,Estado:DBInstanceStatus}" \
      --output table
    echo "  ✔ RDS detenida: $DB_IDENTIFIER"
    echo ""
    echo "  Nota sobre RDS db.t3.micro:"
    echo "  · Puede permanecer detenida hasta 7 días consecutivos."
    echo "  · Pasados los 7 días, AWS la reinicia automáticamente."
    echo "  · No se cobra por instancia detenida, pero sí por el almacenamiento."
  else
    echo "  · RDS en estado '$DB_STATUS' — verifica manualmente si ya está detenida."
  fi

  echo ""
  echo "↑ TOMA CAPTURA — EVIDENCIA 6 ↑"
  echo "════════════════════════════════════════════════════════════════════"
}

# =============================================================================
# ██████████████████████████████████████████████████████████████████████████
# PARTE B — Ejecutar en tu EQUIPO LOCAL (Windows/Mac)
#           Este bloque debe FALLAR — eso es la evidencia E2
# ██████████████████████████████████████████████████████████████████████████
# =============================================================================

mostrar_instrucciones_e2() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "  EVIDENCIA 2 — Intento FALLIDO desde fuera de la red (paso 5 P06)"
  echo "  EJECUTAR EN TU EQUIPO LOCAL, NO en CloudShell ni en EC2"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""

  # Obtener el endpoint de la base
  DB_ENDPOINT=$(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null)

  echo "  El endpoint de tu base es:"
  echo "  $DB_ENDPOINT"
  echo ""
  echo "  ─────────────────────────────────────────────────────────────────"
  echo "  OPCIÓN A — Con psql instalado en tu equipo:"
  echo ""
  echo "    psql -h $DB_ENDPOINT -U postgres -d inventario -p 5432"
  echo ""
  echo "    Resultado esperado: timeout o 'connection refused'"
  echo "    (la conexión NUNCA debe completarse)"
  echo ""
  echo "  OPCIÓN B — Con nc (netcat) o telnet:"
  echo ""
  echo "    nc -zv -w 5 $DB_ENDPOINT 5432"
  echo "    # o en Windows PowerShell:"
  echo "    Test-NetConnection -ComputerName $DB_ENDPOINT -Port 5432"
  echo ""
  echo "    Resultado esperado: 'timed out' o 'TCP connect to... FAILED'"
  echo ""
  echo "  ─────────────────────────────────────────────────────────────────"
  echo "  ¿Por qué falla? Porque:"
  echo "  · PubliclyAccessible = False (sin IP pública)"
  echo "  · El SG de RDS solo acepta al SG de EC2 — tu IP local no está"
  echo "    en ninguna regla de entrada"
  echo "  · La subred privada no tiene ruta a internet"
  echo ""
  echo "  → Captura la pantalla mostrando el ERROR de conexión."
  echo "↑ TOMA CAPTURA — EVIDENCIA 2 ↑"
  echo "════════════════════════════════════════════════════════════════════"
}

# =============================================================================
# ██████████████████████████████████████████████████████████████████████████
# PARTE C — Ejecutar DENTRO del servidor EC2 (vía SSH)
# ██████████████████████████████████████████████████████████████████████████
# =============================================================================

mostrar_instrucciones_e3_e4() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "  EVIDENCIA 3 y 4 — Conexión exitosa y esquema desde EC2 (paso 6-7)"
  echo "  EJECUTAR DENTRO DEL SERVIDOR EC2 (conéctate por SSH primero)"
  echo "════════════════════════════════════════════════════════════════════"

  DB_ENDPOINT=$(aws rds describe-db-instances \
    --region "$REGION" \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Address" --output text 2>/dev/null)

  EC2_IP=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=$EC2_NAME" \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null)

  echo ""
  echo "  ── Paso 1: Conectarte al servidor EC2 (desde tu equipo local) ───"
  echo ""
  echo "    ssh -i tu-llave.pem ubuntu@$EC2_IP"
  echo ""
  echo "  ── Paso 2: Instalar el cliente PostgreSQL en EC2 ────────────────"
  echo ""
  echo "    sudo apt-get update -y"
  echo "    sudo apt-get install -y postgresql-client"
  echo ""
  echo "  ── Paso 3: Verificar conectividad al puerto 5432 (E3) ───────────"
  echo ""
  echo "    # Este comando debe responder — captura la salida"
  echo "    nc -zv -w 5 $DB_ENDPOINT 5432"
  echo "    # Resultado esperado: 'Connection to ... 5432 port [tcp/postgresql] succeeded!'"
  echo ""
  echo "  ── Paso 4: Conectarse a la base con psql (E3) ───────────────────"
  echo ""
  echo "    psql -h $DB_ENDPOINT -U postgres -d inventario"
  echo "    # Ingresa la contraseña cuando la pida"
  echo "    # Resultado esperado: prompt 'inventario=#'"
  echo ""
  echo "    # Ya conectado, ejecuta para confirmar (captura esta salida):"
  echo "    \\conninfo"
  echo "    SELECT version();"
  echo ""
  echo "  ── Paso 5: Aplicar el esquema y datos de prueba (E4) ────────────"
  echo ""
  echo "    # Sube el archivo SQL al EC2 (desde tu equipo local):"
  echo "    scp -i tu-llave.pem deploy/schema-p06.sql ubuntu@$EC2_IP:~/"
  echo ""
  echo "    # Luego, dentro del EC2, ejecútalo:"
  echo "    psql -h $DB_ENDPOINT -U postgres -d inventario -f ~/schema-p06.sql"
  echo ""
  echo "    # Captura la salida completa — muestra las tablas creadas"
  echo "    # y los resultados de las consultas (JOIN con datos ficticios)"
  echo ""
  echo "  ── Paso 6: Consulta de verificación final (E4) ──────────────────"
  echo ""
  echo "    psql -h $DB_ENDPOINT -U postgres -d inventario -c \\"
  echo "      \"SELECT p.codigo, p.nombre, c.nombre AS categoria,\\"
  echo "              p.stock_actual, p.stock_minimo\\"
  echo "         FROM productos p\\"
  echo "         JOIN categorias c ON c.id = p.categoria_id\\"
  echo "        ORDER BY p.id;\""
  echo ""
  echo "↑ TOMA CAPTURAS — EVIDENCIA 3 (conexión) y EVIDENCIA 4 (consulta) ↑"
  echo "════════════════════════════════════════════════════════════════════"
}

# =============================================================================
# MENÚ PRINCIPAL
# =============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   PRÁCTICA 06 — Script de evidencias   Equipo: Los Rojos        ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  1) E1 — Base desplegada (CloudShell)                           ║"
echo "║  2) E2 — Instrucciones conexión fallida (ejecutar en local)     ║"
echo "║  3) E3+E4 — Instrucciones conexión exitosa + esquema (EC2)      ║"
echo "║  4) E5 — Respaldos y RPO (CloudShell)                           ║"
echo "║  5) E6 — Detener servidor y base (CloudShell)                   ║"
echo "║  6) Todo (genera las secciones A, E2 instr., E3/E4 instr.)      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo -n "Elige una opción [1-6]: "
read OPCION

case $OPCION in
  1) mostrar_e1_base_desplegada ;;
  2) mostrar_instrucciones_e2 ;;
  3) mostrar_instrucciones_e3_e4 ;;
  4) mostrar_e5_respaldos ;;
  5) mostrar_e6_detener ;;
  6)
    mostrar_e1_base_desplegada
    mostrar_instrucciones_e2
    mostrar_instrucciones_e3_e4
    mostrar_e5_respaldos
    ;;
  *)
    echo "Opción no válida. Ejecuta el script de nuevo."
    exit 1
    ;;
esac

echo ""
echo "============================================================"
echo "  CHECKLIST ENTREGABLE P06"
echo "============================================================"
echo "  [ ] Captura E1: base desplegada, IP pública=False, cifrado=True"
echo "  [ ] Captura E2: intento fallido desde tu equipo local"
echo "  [ ] Captura E3: conexión exitosa desde EC2 (prompt psql)"
echo "  [ ] Captura E4: output de schema-p06.sql con tablas y datos"
echo "  [ ] Captura E5: retención 7 días y análisis RPO"
echo "  [ ] Credencial guardada fuera del repositorio"
echo "  [ ] Servidor EC2 detenido al finalizar"
echo "  [ ] RDS detenida al finalizar (máx. 7 días consecutivos)"
echo "============================================================"
