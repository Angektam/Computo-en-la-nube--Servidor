#!/bin/bash
# =============================================================================
# PRÁCTICA 09 — Evidencia C1 (15 pts): Justificación de la funcionalidad
# Muestra la función elegida y compara con las descartadas.
# Ejecutar en CloudShell. TOMAR CAPTURA de la salida completa.
# =============================================================================

set -euo pipefail

REGION="us-east-1"
EQUIPO="los-rojos"
FUNCION="fn-movimientos-${EQUIPO}"

echo "════════════════════════════════════════════════════════════════════"
echo "  C1 · Justificación de funcionalidad elegida"
echo "  Práctica 09 · Equipo Los Rojos"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  FUNCIONALIDAD ELEGIDA: Consulta de movimientos por producto    │"
echo "│  Ruta: GET /movimientos/{producto_id}                           │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  ¿Por qué es la candidata ideal para Lambda?"
echo ""
echo "  ✔ Esporádica:"
echo "     Solo se ejecuta cuando un usuario consulta el historial."
echo "     Un negocio pequeño consulta ~50-200 veces/día, con silencios"
echo "     prolongados (noche, fines de semana)."
echo ""
echo "  ✔ Breve:"
echo "     DynamoDB responde Q1 (PK directa) en < 100 ms."
echo "     Con 128 MB y timeout de 10 s hay margen de 100x."
echo ""
echo "  ✔ Dirigida por evento:"
echo "     El evento es un HTTP GET de API Gateway — sin polling, sin cron."
echo ""
echo "  ✔ Sin estado:"
echo "     No necesita memoria entre invocaciones; cada consulta es independiente."
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  CANDIDATAS DESCARTADAS"
echo "────────────────────────────────────────────────────────────────────"
echo ""
echo "  ✗ Candidata 2: Sincronización RDS ↔ DynamoDB"
echo "     Razón del descarte: proceso continuo y de larga duración."
echo "     Leer N filas de PostgreSQL y escribirlas en DynamoDB puede"
echo "     tomar minutos para tablas con miles de filas. Lambda cobra"
echo "     por milisegundo; un proceso así es más barato y natural en"
echo "     un contenedor ECS o en la propia EC2 con un cron job."
echo ""
echo "  ✗ Candidata 3: Generación de reporte diario de movimientos"
echo "     Razón del descarte: aunque periódica, es de tipo batch."
echo "     Procesar un día entero de movimientos (potencialmente miles"
echo "     de ítems) y generar un PDF/Excel puede superar 30 s."
echo "     El patrón batch con agregaciones no encaja bien en Lambda;"
echo "     conviene AWS Glue o un script programado en EC2 con EventBridge."
echo ""
echo "────────────────────────────────────────────────────────────────────"
echo "  Verificación: configuración de la función elegida"
echo "────────────────────────────────────────────────────────────────────"
echo ""
aws lambda get-function-configuration \
  --function-name "${FUNCION}" \
  --region "${REGION}" \
  --query "{
    Funcion:FunctionName,
    Runtime:Runtime,
    Handler:Handler,
    Memoria_MB:MemorySize,
    Timeout_s:Timeout,
    Estado:State,
    Rol:Role
  }" \
  --output table

echo ""
echo "  *** TOMAR CAPTURA AQUÍ — Criterio C1 completo ***"
