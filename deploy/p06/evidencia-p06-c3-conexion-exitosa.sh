#!/bin/bash
# =============================================================================
# CAPTURA 3 — Conexión EXITOSA desde el servidor EC2
# Ejecutar en: DENTRO del servidor EC2 (conéctate por SSH primero)
# Evidencia para: Lista de cotejo — 20 pts (conexión exitosa desde servidor)
#
# Prerequisito: tener el endpoint de RDS a la mano
#   → lo obtienes corriendo evidencia-p06-c1-base-desplegada.sh en CloudShell
# =============================================================================

echo "════════════════════════════════════════════════════════════════════"
echo "  CAPTURA 3 — Conexión exitosa desde el servidor EC2"
echo "  Equipo: Los Rojos  |  Práctica 06"
echo "  IMPORTANTE: Ejecutar DENTRO del EC2 (después de conectarte por SSH)"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Leer endpoint (puede estar en variable de entorno o pedirlo)
if [ -z "$DB_HOST" ]; then
  echo -n "  Ingresa el endpoint de RDS: "
  read DB_HOST
fi

if [ -z "$DB_HOST" ]; then
  echo "  ❌ Endpoint vacío. Sal del script y defínelo:"
  echo "     export DB_HOST=<tu-endpoint>.rds.amazonaws.com"
  exit 1
fi

echo ""
echo "  ── Paso 1: Verificar que el cliente PostgreSQL está instalado ───"
echo ""
if ! command -v psql &> /dev/null; then
  echo "  psql no encontrado. Instalando..."
  sudo apt-get update -y -q
  sudo apt-get install -y -q postgresql-client
  echo "  ✔ postgresql-client instalado"
else
  echo "  ✔ psql disponible: $(psql --version)"
fi

echo ""
echo "  ── Paso 2: Prueba de conectividad TCP al puerto 5432 ────────────"
echo ""
echo "  Probando $DB_HOST:5432 ..."
nc -zv -w 10 "$DB_HOST" 5432
NC_EXIT=$?
echo ""
if [ $NC_EXIT -eq 0 ]; then
  echo "  ✔ Puerto 5432 ALCANZABLE desde EC2 — el SG permite la conexión"
else
  echo "  ✗ Puerto no alcanzable. Verifica el SG de RDS y que la base esté activa."
  exit 1
fi

echo ""
echo "  ── Paso 3: Mostrar desde dónde se conecta este servidor ─────────"
echo ""
echo "  IP privada del EC2 (debe estar en 10.0.1.0/24):"
hostname -I | tr ' ' '\n' | grep "^10\."
echo ""
echo "  Nombre del host:"
hostname

echo ""
echo "  ── Paso 4: Conectarse a la base de datos ────────────────────────"
echo ""
echo "  Se abrirá la sesión de psql. Una vez conectado, ejecuta:"
echo "    \\conninfo"
echo "    SELECT version();"
echo "    \\q"
echo ""
echo "  Captura la pantalla mostrando el prompt: inventario=#"
echo ""
echo -n "  Ingresa la contraseña de postgres cuando la pida."
echo ""
echo "  Ejecutando: psql -h $DB_HOST -U postgres -d inventario"
echo ""

psql -h "$DB_HOST" -U postgres -d inventario \
  -c "\conninfo" \
  -c "SELECT version() AS motor_postgresql;" \
  -c "SELECT current_database() AS base, current_user AS usuario, inet_server_addr() AS ip_servidor, inet_server_port() AS puerto;"

echo ""
echo "  Si ves la información de arriba, la conexión fue EXITOSA ✔"
echo ""
echo "↑ TOMA CAPTURA DE ESTA PANTALLA COMPLETA ↑"
echo "════════════════════════════════════════════════════════════════════"
