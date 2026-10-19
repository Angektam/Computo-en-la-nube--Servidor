#!/bin/bash
# =============================================================================
# PRÁCTICA 07 — Evidencia C5: SCAN ineficiente
# Busca todos los movimientos tipo "salida" SIN usar la clave de partición.
# Demuestra por qué el Scan es problemático a escala y cómo el Query + GSI
# resuelve la misma necesidad sin recorrer la tabla entera.
#
# CÁLCULO DE COSTO (supuesto: ítem promedio = 200 B):
#
#   Precio on-demand us-east-1 (octubre 2026):
#     Lectura  (RCU): $0.25 por millón de RCUs
#     Escritura(WCU): $1.25 por millón de WCUs
#
#   Una RCU lee hasta 4 KB en modo eventually consistent (0.5 RCU),
#   o hasta 4 KB en modo strongly consistent (1 RCU).
#   DynamoDB usa eventually consistent por defecto en Scan y Query.
#
#   SCAN — 1 000 000 de ítems × 200 B / ítem = 200 000 000 B = ~190 MB
#     RCUs consumidas = ceil(200 000 000 / 4 096) × 0.5  ≈ 24 415 RCUs
#     Costo           = 24 415 / 1 000 000 × $0.25       ≈ $0.0061 por ejecución
#     Si se ejecuta cada minuto: 0.0061 × 60 × 24 × 30   ≈ $263 USD/mes
#
#   QUERY (con PK, un solo producto, 10 movimientos × 200 B):
#     Datos leídos    = 10 × 200 B = 2 000 B = ~2 KB
#     RCUs consumidas = ceil(2000 / 4096) × 0.5 = 0.5 RCUs
#     Costo           = 0.5 / 1 000 000 × $0.25 ≈ $0.000000125 por ejecución
#     (~49 000 veces más barato que el Scan por ejecución)
#
# TOMAR CAPTURA de la salida completa + del resumen de consumo.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
TABLE_NAME="movimientos_inventario"

echo "============================================="
echo " C5 · SCAN — Consulta ineficiente (sin PK)"
echo " Tabla  : $TABLE_NAME"
echo "============================================="
echo ""
echo "SUPUESTO DE CÁLCULO: ítem promedio = 200 B (8 atributos × ~25 B)"
echo "Precio RCU (us-east-1): \$0.25 / millón de RCUs (eventually consistent)"
echo ""
echo "  SCAN   (1M ítems × 200B): ~24 415 RCUs → ~\$0.0061/ejecución"
echo "  Si se dispara cada minuto: ~\$263 USD/mes — solo por esta operación."
echo ""
echo "  QUERY  (1 producto × 10 movimientos × 200B): 0.5 RCUs → ~\$0.000000125/ejecución"
echo "  49 000x más barato que el Scan."
echo ""

# --- SCAN sin clave de partición -------------------------------------------
echo ">>> Ejecutando Scan (tipo=salida, sin filtro de PK)..."
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
import json
data = json.load(open('/tmp/scan_result.json'))
count    = data.get('Count', 0)
scanned  = data.get('ScannedCount', 0)
cap      = data.get('ConsumedCapacity', {}).get('CapacityUnits', 'N/A')
precio_rcu = 0.25 / 1_000_000          # por RCU
costo_hoy  = float(cap) * precio_rcu if isinstance(cap, (int,float)) else 0

print(f'  Items devueltos  : {count}')
print(f'  Items escaneados : {scanned}   <- todos, aunque solo {count} coincidan')
print(f'  Capacidad usada  : {cap} RCUs  (eventually consistent)')
print(f'  Costo real hoy   : \${costo_hoy:.8f} USD  ({scanned} items x 200B)')
print()
print('  Proyección a escala (200B/item, Scan eventual-consistent):')
print('  ─────────────────────────────────────────────────────────')
print('  ítems    RCUs consumidas   Costo/ejecución   Costo si corre c/minuto')
for n, label in [(1000,'1K'), (100000,'100K'), (1000000,'1M')]:
    rcus  = (n * 200 / 4096) * 0.5
    costo = rcus / 1_000_000 * 0.25
    mens  = costo * 60 * 24 * 30
    print(f'  {label:<8} {rcus:>14.0f} RCUs   \${costo:.6f}/ejec   \${mens:.2f}/mes')
print()
print('  Query (1 producto, 10 movimientos x 200B):')
print('  RCUs = ceil(2000/4096) x 0.5 = 0.5 RCUs')
print(f'  Costo = 0.5 / 1000000 x \$0.25 = \$0.000000125 por ejecucion')
" 2>/dev/null || cat /tmp/scan_result.json

echo ""
echo "✔  C5 completado."
echo "   *** TOMAR CAPTURA AQUÍ — muestra el resumen de consumo completo ***"
echo ""
echo "CONCLUSIÓN: Siempre diseñar el patrón de acceso ANTES de la tabla."
echo "  Q1/Q2 → Query por producto_id (costo mínimo)."
echo "  Q3    → Query por GSI_fecha   (sin Scan)."
