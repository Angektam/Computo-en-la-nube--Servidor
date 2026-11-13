#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C5: SCAN ineficiente (paso 07 de la práctica)
# Busca todos los movimientos de tipo "salida" SIN usar la clave de partición.
# TOMAR CAPTURA de la salida completa + de las métricas de consumo.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C5 · SCAN — Consulta ineficiente (sin PK)"
echo " Tabla  : $TABLE_NAME"
echo "============================================="
echo ""
echo "ADVERTENCIA: Scan recorre TODOS los elementos de la tabla."
echo "Con 5 elementos el costo es despreciable, pero con 1 000 000"
echo "de elementos cada Scan consume ~1 RCU por cada 4 KB leídos:"
echo "  1 000 000 ítems × ~200 B ≈ 50 000 RCUs = ~\$0.01 por ejecución."
echo "Si se dispara automáticamente (ej. cada minuto), el gasto mensual"
echo "puede superar \$430 USD — solo por esta operación."
echo ""

# --- SCAN sin clave de partición -----------------------------------------
echo ">>> Ejecutando Scan (tipo = salida, sin filtro de PK)..."
aws dynamodb scan \
  --table-name "$TABLE_NAME" \
  --filter-expression "#t = :tipo" \
  --expression-attribute-names '{"#t": "tipo"}' \
  --expression-attribute-values '{":tipo": {"S": "salida"}}' \
  --return-consumed-capacity TOTAL \
  --region "$REGION" \
  --output json | tee /tmp/scan_result.json

echo ""
echo "--- Resumen de consumo ---"
python3 -c "
import json, sys
data = json.load(open('/tmp/scan_result.json'))
count  = data.get('Count', 0)
scanned = data.get('ScannedCount', 0)
cap    = data.get('ConsumedCapacity', {}).get('CapacityUnits', 'N/A')
print(f'  Ítems devueltos  : {count}')
print(f'  Ítems escaneados : {scanned}   ← todos, aunque solo {count} coincidan')
print(f'  Capacidad usada  : {cap} RCUs')
print()
print('  COMPARACIÓN:')
print('  QUERY (con PK) : escanea solo los ítems de esa partición.')
print('  SCAN (sin PK)  : escanea TODA la tabla sin importar el resultado.')
" 2>/dev/null || \
  cat /tmp/scan_result.json

echo ""
echo "✔  C5 completado — scan ineficiente ejecutado."
echo "   *** TOMAR CAPTURA AQUÍ ***"
echo ""
echo "CONCLUSIÓN: Siempre diseñar el patrón de acceso antes de la tabla"
echo "para evitar Scans en producción."
