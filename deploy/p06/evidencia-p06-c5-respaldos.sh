#!/bin/bash
# =============================================================================
# CAPTURA 5 — Periodo de retención de respaldos y su implicación en el RPO
# Ejecutar en: AWS CloudShell
# Evidencia para: Lista de cotejo — nota requerida en el entregable
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
DB_IDENTIFIER="rds-$PROYECTO-$EQUIPO"

echo "════════════════════════════════════════════════════════════════════"
echo "  CAPTURA 5 — Retención de respaldos automáticos y RPO"
echo "  Equipo: Los Rojos  |  Práctica 06"
echo "════════════════════════════════════════════════════════════════════"
echo ""

echo "▶ Configuración de respaldos de la instancia RDS:"
echo ""
aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].{
    Instancia:DBInstanceIdentifier,
    Estado:DBInstanceStatus,
    Retención_días:BackupRetentionPeriod,
    Ventana_respaldo_UTC:PreferredBackupWindow,
    Ventana_mantenimiento:PreferredMaintenanceWindow,
    Cifrado:StorageEncrypted,
    Motor:Engine,
    Version:EngineVersion
  }" \
  --output table

echo ""
echo "▶ Respaldos automáticos existentes (snapshots):"
echo ""
aws rds describe-db-snapshots \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --snapshot-type automated \
  --query "DBSnapshots[*].{
    SnapshotId:DBSnapshotIdentifier,
    Estado:Status,
    Fecha:SnapshotCreateTime,
    Tamaño_GB:AllocatedStorage,
    Cifrado:Encrypted
  }" \
  --output table 2>/dev/null || echo "  (aún no hay snapshots automáticos — se generan después de la primera ventana de respaldo)"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  ANÁLISIS DEL RPO (Recovery Point Objective)"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Configuración aplicada:"
echo "  · Retención             : 7 días"
echo "  · Frecuencia            : Diaria (automática, ventana 05:00-06:00 UTC)"
echo "  · Tipo                  : Respaldo completo + WAL continuo (PITR)"
echo ""
echo "  RPO resultante:"
echo "  · Con respaldo diario   : ~24 horas"
echo "    → En el peor caso, si la base falla justo antes del respaldo,"
echo "      se pierden hasta 24 horas de transacciones."
echo ""
echo "  · Con PITR activado     : minutos (RDS guarda logs de transacciones)"
echo "    → Se puede restaurar a cualquier segundo dentro de los 7 días."
echo "    → Esto supera el RPO de 24 h y lo reduce a ~5 minutos."
echo ""
echo "  Implicación para el proyecto:"
echo "  · El negocio es una miscelánea con 3 empleados, sin operación 24/7."
echo "  · Un RPO de 24 h es aceptable: los movimientos del día pueden"
echo "    reconstruirse manualmente a partir de notas físicas en caja."
echo "  · La retención de 7 días da margen suficiente para detectar"
echo "    errores de datos antes de que los respaldos expiren."
echo ""
echo "  Nota para práctica 15:"
echo "  · En P15 se usará el PITR para restaurar la base a un punto exacto."
echo "  · La retención de 7 días define la ventana máxima de restauración."
echo ""
echo "↑ TOMA CAPTURA DE ESTA PANTALLA COMPLETA ↑"
echo "════════════════════════════════════════════════════════════════════"
