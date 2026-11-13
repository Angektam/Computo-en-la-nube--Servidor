#!/bin/bash
# =============================================================================
# CAPTURA 4 — Esquema creado y consulta con resultados
# Ejecutar en: DENTRO del servidor EC2 (después de la captura 3)
# Evidencia para: Lista de cotejo — 15 pts (esquema del modelo de datos)
#
# Este script aplica el schema-p06.sql y luego muestra el resultado
# de varias consultas con datos reales para la captura.
# =============================================================================

echo "════════════════════════════════════════════════════════════════════"
echo "  CAPTURA 4 — Esquema del proyecto creado y consulta con resultados"
echo "  Equipo: Los Rojos  |  Práctica 06"
echo "  IMPORTANTE: Ejecutar DENTRO del EC2"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Leer endpoint
if [ -z "$DB_HOST" ]; then
  echo -n "  Ingresa el endpoint de RDS: "
  read DB_HOST
fi

if [ -z "$DB_HOST" ]; then
  echo "  ❌ Endpoint vacío."
  exit 1
fi

echo ""
echo "  ── Paso 1: Verificar si el archivo schema-p06.sql está disponible ─"
echo ""

# Buscar el archivo en ubicaciones comunes
SQL_FILE=""
for RUTA in ~/schema-p06.sql /home/ubuntu/schema-p06.sql ./schema-p06.sql; do
  if [ -f "$RUTA" ]; then
    SQL_FILE="$RUTA"
    break
  fi
done

if [ -z "$SQL_FILE" ]; then
  echo "  ⚠  schema-p06.sql no encontrado."
  echo "  Súbelo con SCP desde tu equipo local:"
  echo ""
  echo "    scp -i tu-llave.pem deploy/schema-p06.sql ubuntu@<IP-EC2>:~/"
  echo ""
  echo "  Luego ejecuta este script de nuevo."
  exit 1
else
  echo "  ✔ Archivo encontrado: $SQL_FILE"
fi

echo ""
echo "  ── Paso 2: Aplicar el esquema y datos de prueba ─────────────────"
echo ""

PGPASSWORD="${DB_PASSWORD}" psql \
  -h "$DB_HOST" \
  -U postgres \
  -d inventario \
  -f "$SQL_FILE"

echo ""
echo "  ── Paso 3: Consulta de evidencia — tablas existentes ────────────"
echo ""

PGPASSWORD="${DB_PASSWORD}" psql \
  -h "$DB_HOST" \
  -U postgres \
  -d inventario \
  -c "SELECT tablename AS tabla, pg_size_pretty(pg_total_relation_size(quote_ident(tablename))) AS tamanio
      FROM pg_tables
      WHERE schemaname = 'public'
      ORDER BY tablename;"

echo ""
echo "  ── Paso 4: Consulta principal — productos con categoría y stock ──"
echo ""

PGPASSWORD="${DB_PASSWORD}" psql \
  -h "$DB_HOST" \
  -U postgres \
  -d inventario \
  -c "SELECT p.id,
             p.codigo,
             p.nombre        AS producto,
             c.nombre        AS categoria,
             p.precio,
             p.stock_actual,
             p.stock_minimo,
             CASE WHEN p.stock_actual <= p.stock_minimo
                  THEN 'BAJO ⚠'
                  ELSE 'OK ✔'
             END             AS estado_stock
      FROM   productos p
      JOIN   categorias c ON c.id = p.categoria_id
      ORDER  BY p.id;"

echo ""
echo "  ── Paso 5: Consulta de movimientos con usuario y producto ────────"
echo ""

PGPASSWORD="${DB_PASSWORD}" psql \
  -h "$DB_HOST" \
  -U postgres \
  -d inventario \
  -c "SELECT m.id,
             pr.nombre  AS producto,
             u.nombre   AS usuario,
             u.rol,
             m.tipo,
             m.cantidad,
             m.stock_antes,
             m.stock_despues,
             m.fecha
      FROM   movimientos m
      JOIN   productos pr ON pr.id = m.producto_id
      JOIN   usuarios  u  ON u.id  = m.usuario_id
      ORDER  BY m.fecha;"

echo ""
echo "  ── Paso 6: Conteo de registros por tabla ─────────────────────────"
echo ""

PGPASSWORD="${DB_PASSWORD}" psql \
  -h "$DB_HOST" \
  -U postgres \
  -d inventario \
  -c "SELECT 'usuarios'    AS tabla, COUNT(*) AS registros FROM usuarios    UNION ALL
      SELECT 'categorias',          COUNT(*)               FROM categorias  UNION ALL
      SELECT 'productos',           COUNT(*)               FROM productos   UNION ALL
      SELECT 'movimientos',         COUNT(*)               FROM movimientos UNION ALL
      SELECT 'pedidos',             COUNT(*)               FROM pedidos
      ORDER BY tabla;"

echo ""
echo "↑ TOMA CAPTURA DE ESTA PANTALLA COMPLETA ↑"
echo "  (debe mostrar tablas creadas + resultados de las consultas)"
echo "════════════════════════════════════════════════════════════════════"
