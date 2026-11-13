#!/bin/bash
# =============================================================================
# CAPTURA 2 — Intento FALLIDO de conexión desde fuera de la red
# Ejecutar en: tu EQUIPO LOCAL (Windows PowerShell o Mac/Linux terminal)
#              NO en CloudShell, NO en EC2
# Evidencia para: Lista de cotejo — 20 pts (evidencia de aislamiento)
#
# Este script obtiene el endpoint desde AWS y luego intenta conectarse.
# La conexión DEBE FALLAR — eso es la evidencia.
# =============================================================================

REGION="us-east-1"
PROYECTO="inventario-cloud"
EQUIPO="los-rojos"
DB_IDENTIFIER="rds-$PROYECTO-$EQUIPO"

echo "════════════════════════════════════════════════════════════════════"
echo "  CAPTURA 2 — Intento fallido desde fuera de la red del proyecto"
echo "  Equipo: Los Rojos  |  Práctica 06"
echo "  IMPORTANTE: Ejecutar en tu equipo LOCAL, no en CloudShell"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Obtener endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text 2>/dev/null)

if [ -z "$DB_ENDPOINT" ] || [ "$DB_ENDPOINT" = "None" ]; then
  echo "  ⚠  No se pudo obtener el endpoint de RDS."
  echo "  Copia el endpoint manualmente desde la consola RDS y úsalo abajo."
  DB_ENDPOINT="<tu-endpoint>.rds.amazonaws.com"
fi

echo "  Endpoint de la base: $DB_ENDPOINT"
echo "  Puerto             : 5432"
echo ""
echo "  Tu IP pública (desde donde intentas conectarte):"
curl -s --max-time 5 https://checkip.amazonaws.com || echo "  (no disponible)"
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  Intentando conexión TCP al puerto 5432 (timeout 10 segundos)..."
echo "  Resultado esperado: FALLO (timeout o connection refused)"
echo "────────────────────────────────────────────────────────────────────"
echo ""

# Intento con nc (disponible en Mac/Linux y Git Bash en Windows)
if command -v nc &> /dev/null; then
  echo "  [nc] Probando $DB_ENDPOINT:5432 ..."
  nc -zv -w 10 "$DB_ENDPOINT" 5432
  NC_EXIT=$?
  echo ""
  if [ $NC_EXIT -ne 0 ]; then
    echo "  ✔ CONEXIÓN FALLIDA (código $NC_EXIT) — aislamiento confirmado"
  else
    echo "  ✗ CONEXIÓN EXITOSA — revisar configuración del SG y acceso público"
  fi
else
  echo "  nc no disponible. Usa uno de estos comandos manualmente:"
  echo ""
  echo "  # PowerShell (Windows):"
  echo "  Test-NetConnection -ComputerName $DB_ENDPOINT -Port 5432"
  echo ""
  echo "  # Mac/Linux:"
  echo "  nc -zv -w 10 $DB_ENDPOINT 5432"
  echo ""
  echo "  # Con psql (si está instalado):"
  echo "  psql -h $DB_ENDPOINT -U postgres -d inventario -p 5432 --connect-timeout 10"
fi

echo ""
echo "  ¿Por qué falla la conexión?"
echo "  · La base NO tiene IP pública (PubliclyAccessible = False)"
echo "  · El SG de RDS solo permite tráfico desde el SG del EC2"
echo "  · Tu equipo local no está en ninguna regla de entrada"
echo "  · La subred privada no tiene ruta a internet"
echo ""
echo "↑ TOMA CAPTURA MOSTRANDO EL ERROR DE CONEXIÓN ↑"
echo "════════════════════════════════════════════════════════════════════"
