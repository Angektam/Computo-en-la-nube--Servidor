#!/usr/bin/env python3
"""
lambda_function.py — Práctica 09 · Equipo Los Rojos
====================================================
Función Lambda: Consulta de movimientos de inventario por producto.

Funcionalidad elegida: GET /movimientos/{producto_id}
  → Devuelve los movimientos de un producto ordenados por fecha descendente.

Por qué es la candidata ideal para Lambda (serverless):
  - Esporádica: se dispara solo cuando un usuario consulta; no corre
    continuamente como un proceso de sincronización o un servidor web.
  - Breve: acceso a DynamoDB con PK directa → latencia < 100 ms típica.
  - Dirigida por evento: el evento es un HTTP GET desde API Gateway.
  - Sin estado: no necesita memoria entre invocaciones.

Por qué se descartan las otras dos candidatas:
  1. Sincronización RDS↔DynamoDB: procesa lotes grandes y corre de forma
     continua → conviene ECS/EC2, no Lambda.
  2. Generación de reportes diarios: aunque es periódica, los reportes
     pueden tardar varios segundos con millones de registros → Lambda
     (timeout máx 15 min, pero el patrón de acceso es batch, no evento).

Las credenciales provienen del Execution Role de Lambda (IAM role adjunto
a la función), NO de llaves de acceso hardcodeadas. boto3 las resuelve
automáticamente del entorno de ejecución de Lambda.

Configuración mínima recomendada:
  - Memoria  : 128 MB  (DynamoDB client < 10 MB de footprint)
  - Timeout  : 10 s    (P99 < 1 s para queries simples; 10 s deja margen)
  - Runtime  : Python 3.12
  - Handler  : lambda_function.lambda_handler
"""

import json
import os
import logging
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

# ─── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ─── Constantes (configurables vía variables de entorno) ─────────────────────
REGION     = os.environ.get("REGION", "us-east-1")
TABLE_NAME = os.environ.get("TABLE_NAME", "movimientos_inventario")
MAX_ITEMS  = int(os.environ.get("MAX_ITEMS", "50"))   # paginación por defecto

# ─── Clientes AWS (se inicializan fuera del handler para reuso entre
#     invocaciones "calientes" — mejora latencia en warm start) ────────────────
dynamodb = boto3.resource("dynamodb", region_name=REGION)
table    = dynamodb.Table(TABLE_NAME)

# ─── Helpers ──────────────────────────────────────────────────────────────────

def decimal_to_native(obj):
    """Convierte Decimal de DynamoDB a int/float para json.dumps."""
    if isinstance(obj, Decimal):
        return int(obj) if obj == int(obj) else float(obj)
    raise TypeError(f"Type {type(obj)} not serializable")


def response(status_code: int, body: dict, origin: str = "*") -> dict:
    """Construye la respuesta API Gateway compatible con CORS."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type"                : "application/json",
            "Access-Control-Allow-Origin" : origin,
            "Access-Control-Allow-Methods": "GET,OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
        },
        "body": json.dumps(body, default=decimal_to_native, ensure_ascii=False),
    }


# ─── Handler principal ────────────────────────────────────────────────────────

def lambda_handler(event, context):
    """
    Punto de entrada de la función Lambda.

    Rutas soportadas (via API Gateway HTTP API o REST API proxy):
      GET /movimientos/{producto_id}
        → Devuelve hasta MAX_ITEMS movimientos del producto, más recientes primero.
        Parámetros opcionales (query string):
          - limit : número de ítems a devolver (máx MAX_ITEMS)
          - tipo  : filtrar por tipo de movimiento (salida | entrada | ajuste)

      GET /movimientos/{producto_id}/stock
        → Devuelve solo el stock actual (último movimiento registrado).

    Respuestas:
      200 OK      → {"producto_id": ..., "count": N, "movimientos": [...]}
      400 Bad Req → {"error": "mensaje"}
      404 Not Fnd → {"error": "No se encontraron movimientos"}
      500 Internal→ {"error": "Error interno"}
    """
    logger.info("Evento recibido: %s", json.dumps(event))

    # ── Preflight CORS (OPTIONS) ──────────────────────────────────────────────
    http_method = event.get("httpMethod") or event.get("requestContext", {}).get(
        "http", {}
    ).get("method", "GET")
    if http_method == "OPTIONS":
        return response(200, {"message": "OK"})

    # ── Extraer producto_id del path ──────────────────────────────────────────
    path_params = event.get("pathParameters") or {}
    producto_id = path_params.get("producto_id", "").strip()

    if not producto_id:
        return response(400, {"error": "Falta el parámetro producto_id en el path"})

    # Validación básica: solo alfanuméricos y guiones
    import re
    if not re.match(r"^[A-Za-z0-9\-]{1,50}$", producto_id):
        return response(400, {"error": "producto_id inválido (solo letras, números y guiones)"})

    # ── Parámetros opcionales ─────────────────────────────────────────────────
    qs = event.get("queryStringParameters") or {}
    limit = min(int(qs.get("limit", MAX_ITEMS)), MAX_ITEMS)
    tipo  = qs.get("tipo", "").strip().lower()

    # Detectar sub-ruta /stock
    path = event.get("path") or event.get("rawPath") or ""
    solo_stock = path.rstrip("/").endswith("/stock")

    # ── Query a DynamoDB ──────────────────────────────────────────────────────
    try:
        query_kwargs = {
            "KeyConditionExpression": Key("producto_id").eq(producto_id),
            "ScanIndexForward"      : False,   # más recientes primero
            "Limit"                 : 1 if solo_stock else limit,
        }

        # Filtro por tipo (FilterExpression se aplica DESPUÉS del Limit en DynamoDB,
        # pero para datos de prueba con pocos ítems es aceptable)
        if tipo and not solo_stock:
            from boto3.dynamodb.conditions import Attr
            query_kwargs["FilterExpression"] = Attr("tipo").eq(tipo)

        result = table.query(**query_kwargs)
        items  = result.get("Items", [])

        logger.info(
            "Query producto_id=%s → Count=%d ScannedCount=%d",
            producto_id,
            result.get("Count", 0),
            result.get("ScannedCount", 0),
        )

        if not items:
            return response(404, {
                "error"      : f"No se encontraron movimientos para producto_id={producto_id}",
                "producto_id": producto_id,
            })

        if solo_stock:
            ultimo = items[0]
            return response(200, {
                "producto_id"  : producto_id,
                "stock_actual" : ultimo.get("stock_despues"),
                "ultimo_movimiento": {
                    "movimiento_id": ultimo.get("movimiento_id"),
                    "fecha"        : ultimo.get("fecha"),
                    "tipo"         : ultimo.get("tipo"),
                    "cantidad"     : ultimo.get("cantidad"),
                    "motivo"       : ultimo.get("motivo"),
                },
            })

        return response(200, {
            "producto_id" : producto_id,
            "count"       : len(items),
            "movimientos" : items,
        })

    except ClientError as exc:
        err_code = exc.response["Error"]["Code"]
        err_msg  = exc.response["Error"]["Message"]
        logger.error("ClientError %s: %s", err_code, err_msg)

        if err_code in ("ResourceNotFoundException", "TableNotFoundException"):
            return response(500, {"error": f"Tabla {TABLE_NAME} no encontrada"})
        if err_code == "AccessDeniedException":
            return response(500, {"error": "Permisos insuficientes — verificar Execution Role"})

        return response(500, {"error": f"Error DynamoDB: {err_code}"})

    except Exception as exc:  # pylint: disable=broad-except
        logger.exception("Error inesperado")
        return response(500, {"error": "Error interno del servidor"})
