#!/bin/bash
# =============================================================================
# PRÁCTICA 13 — Evidencia C6: Gasto acumulado del mes por etiqueta
# Sistema: Inventario Nube · Equipo Los Rojos
#
# Se ejecuta en AWS CloudShell (us-east-1)
#
# Qué hace:
#   1. Consulta el Cost Explorer para el mes en curso, desglosado por etiqueta
#      Proyecto=inventario-nube (o la etiqueta que usen)
#   2. Muestra también el gasto total de la cuenta del mes en curso
#   3. Desglosa por servicio para identificar el mayor consumo
#   4. Genera el dato base para el análisis de costos del E2
#
# NOTA: Cost Explorer tiene latencia de ~24h. Los datos de hoy pueden no
#       aparecer hasta mañana. Si la etiqueta no fue activada en Billing,
#       el script también muestra el gasto por servicio sin filtrar.
# =============================================================================

set -euo pipefail

REGION="us-east-1"

# Etiquetas que usa el proyecto (ajustar si son diferentes)
TAG_KEY="Proyecto"
TAG_VALUE="inventario-nube"

RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m';    NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC}  $*"; }

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════"
echo -e "  P13 · C6 — Gasto acumulado del mes por etiqueta"
echo -e "  Sistema: Inventario Nube · Equipo Los Rojos"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── Calcular fechas del mes en curso ─────────────────────────────
DATE_START=$(date -u +%Y-%m-01)
DATE_END=$(date -u +%Y-%m-%d)

# Si hoy es el día 1, retroceder un mes para tener datos
DAY=$(date -u +%d)
if [ "$DAY" = "01" ]; then
  DATE_START=$(date -u -d "1 month ago" +%Y-%m-01 2>/dev/null \
    || python3 -c "from datetime import date; d=date.today().replace(day=1); import calendar; d2=d.replace(month=d.month-1 if d.month>1 else 12,year=d.year if d.month>1 else d.year-1); print(d2.strftime('%Y-%m-01'))")
fi

# DATE_END debe ser hoy o posterior para incluir datos de hoy
# Cost Explorer requiere que END_DATE sea > START_DATE
if [ "$DATE_START" = "$DATE_END" ]; then
  DATE_END=$(date -u -d "1 day" +%Y-%m-%d 2>/dev/null \
    || python3 -c "from datetime import date, timedelta; print((date.today()+timedelta(days=1)).strftime('%Y-%m-%d'))")
fi

echo "  Período consultado: ${DATE_START} → ${DATE_END}"
echo ""

# ══════════════════════════════════════════════════════════════════
# A — Gasto del mes por etiqueta Proyecto=inventario-nube
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  A · Gasto por etiqueta '${TAG_KEY}=${TAG_VALUE}'${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Consultando Cost Explorer (puede tardar ~10 s)..."

COST_BY_TAG=$(aws ce get-cost-and-usage \
  --region "us-east-1" \
  --time-period "Start=${DATE_START},End=${DATE_END}" \
  --granularity "MONTHLY" \
  --filter "{\"Tags\":{\"Key\":\"${TAG_KEY}\",\"Values\":[\"${TAG_VALUE}\"]}}" \
  --metrics "UnblendedCost" \
  --output json 2>/dev/null || echo "ERROR")

if echo "$COST_BY_TAG" | grep -q "ERROR\|AccessDeniedException\|OptInRequired"; then
  warn "Cost Explorer no está habilitado o no hay datos con esa etiqueta."
  warn "Verifica que la etiqueta '${TAG_KEY}' está activada en Billing → Cost allocation tags"
else
  TOTAL_TAG=$(echo "$COST_BY_TAG" | python3 -c "
import sys, json
data = json.load(sys.stdin)
total = 0.0
for r in data.get('ResultsByTime', []):
    amount = r.get('Total', {}).get('UnblendedCost', {}).get('Amount', '0')
    total += float(amount)
print(f'  Total con etiqueta {\"${TAG_KEY}\"}=${\"${TAG_VALUE}\"}: \${total:.4f} USD')
" 2>/dev/null || echo "  No se pudo calcular el total.")
  ok "$TOTAL_TAG"
fi

echo ""

# ══════════════════════════════════════════════════════════════════
# B — Gasto total de la cuenta del mes en curso
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  B · Gasto TOTAL de la cuenta (mes en curso)${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Consultando gasto total..."

COST_TOTAL=$(aws ce get-cost-and-usage \
  --region "us-east-1" \
  --time-period "Start=${DATE_START},End=${DATE_END}" \
  --granularity "MONTHLY" \
  --metrics "UnblendedCost" \
  --output json 2>/dev/null || echo "ERROR")

if echo "$COST_TOTAL" | grep -q "ERROR\|AccessDeniedException"; then
  warn "No se pudo obtener el gasto total."
else
  echo "$COST_TOTAL" | python3 -c "
import sys, json
data = json.load(sys.stdin)
total = 0.0
for r in data.get('ResultsByTime', []):
    amount = r.get('Total', {}).get('UnblendedCost', {}).get('Amount', '0')
    total += float(amount)
print(f'  Gasto total de la cuenta: \${total:.4f} USD')
print(f'  Período: ${DATE_START} → ${DATE_END}')
" 2>/dev/null || warn "No se pudo calcular."
fi

echo ""

# ══════════════════════════════════════════════════════════════════
# C — Desglose por servicio (sin filtro de etiqueta)
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  C · Desglose por servicio (top 10)${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Consultando desglose por servicio..."

COST_BY_SERVICE=$(aws ce get-cost-and-usage \
  --region "us-east-1" \
  --time-period "Start=${DATE_START},End=${DATE_END}" \
  --granularity "MONTHLY" \
  --metrics "UnblendedCost" \
  --group-by "Type=DIMENSION,Key=SERVICE" \
  --output json 2>/dev/null || echo "ERROR")

if echo "$COST_BY_SERVICE" | grep -q "ERROR\|AccessDeniedException"; then
  warn "No se pudo obtener el desglose por servicio."
else
  echo "$COST_BY_SERVICE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
services = {}
for r in data.get('ResultsByTime', []):
    for g in r.get('Groups', []):
        name = g['Keys'][0]
        amt  = float(g.get('Metrics', {}).get('UnblendedCost', {}).get('Amount', 0))
        services[name] = services.get(name, 0) + amt

# Ordenar por costo
sorted_s = sorted(services.items(), key=lambda x: x[1], reverse=True)
print()
print(f'  {\"Servicio\":<45} {\"Costo USD\":>12}')
print('  ' + '─'*60)
for name, cost in sorted_s[:10]:
    if cost > 0:
        print(f'  {name:<45} \${cost:>11.4f}')
print('  ' + '─'*60)
total = sum(v for v in services.values())
print(f'  {\"TOTAL\":<45} \${total:>11.4f}')
print()
" 2>/dev/null || warn "No se pudo generar el desglose."
fi

echo ""

# ══════════════════════════════════════════════════════════════════
# D — Desglose por etiqueta para todos los valores
# ══════════════════════════════════════════════════════════════════
echo -e "${BOLD}  D · Desglose por etiqueta '${TAG_KEY}' (todos los valores)${NC}"
echo "  ─────────────────────────────────────────────────────────"
info "Agrupando por etiqueta..."

COST_TAG_GROUP=$(aws ce get-cost-and-usage \
  --region "us-east-1" \
  --time-period "Start=${DATE_START},End=${DATE_END}" \
  --granularity "MONTHLY" \
  --metrics "UnblendedCost" \
  --group-by "Type=TAG,Key=${TAG_KEY}" \
  --output json 2>/dev/null || echo "ERROR")

if echo "$COST_TAG_GROUP" | grep -q "ERROR\|AccessDeniedException"; then
  warn "No se pudo agrupar por etiqueta."
else
  echo "$COST_TAG_GROUP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tags = {}
for r in data.get('ResultsByTime', []):
    for g in r.get('Groups', []):
        name = g['Keys'][0] or '(sin etiqueta)'
        amt  = float(g.get('Metrics', {}).get('UnblendedCost', {}).get('Amount', 0))
        tags[name] = tags.get(name, 0) + amt

sorted_t = sorted(tags.items(), key=lambda x: x[1], reverse=True)
print()
print(f'  {\"Etiqueta ${TAG_KEY}\":<40} {\"Costo USD\":>12}')
print('  ' + '─'*55)
for name, cost in sorted_t:
    print(f'  {name:<40} \${cost:>11.4f}')
total = sum(v for v in tags.values())
print('  ' + '─'*55)
print(f'  {\"TOTAL\":<40} \${total:>11.4f}')
print()
" 2>/dev/null || warn "No se pudo generar el desglose por etiqueta."
fi

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo -e "  ✅  Reporte de costos generado"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  URL directa a Cost Explorer:"
echo "  https://us-east-1.console.aws.amazon.com/cost-management/home#/cost-explorer"
echo ""
echo "  Para ver por etiqueta en la consola:"
echo "  Cost Explorer → Group by → Tag → ${TAG_KEY}"
echo ""
echo "  NOTA: Si los datos son \$0.00 en todos los servicios, es probable"
echo "  que la etiqueta '${TAG_KEY}' no esté activada en Billing."
echo "  Ve a: Billing → Cost allocation tags → Activar '${TAG_KEY}'"
echo ""
echo -e "  ${YELLOW}*** TOMAR CAPTURA DEL DESGLOSE POR SERVICIO (sección C)"
echo -e "      Y DEL DESGLOSE POR ETIQUETA (sección D) ***${NC}"
echo ""
