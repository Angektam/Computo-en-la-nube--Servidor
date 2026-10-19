#!/usr/bin/env python3
"""
operaciones_dynamodb.py — Práctica 07 · Equipo Los Rojos
========================================================
Demuestra las cuatro operaciones CRUD sobre la tabla DynamoDB
movimientos_inventario usando el SDK oficial de AWS para Python
(boto3) con el ROL DE SERVICIO de la EC2.

Las credenciales provienen automáticamente del Instance Metadata Service
(IMDS) de la instancia EC2 que tiene adjunto el Instance Profile
'ip-rol-ec2-s3-los-rojos'. NO se usan llaves de acceso hardcodeadas.

Uso (desde la EC2, después de instalar boto3):
  pip3 install boto3 --quiet
  python3 operaciones_dynamodb.py

Requiere:
  - Python 3.8+
  - boto3 >= 1.26
  - IAM: la EC2 debe tener adjunto ip-rol-ec2-s3-los-rojos con permisos
    dynamodb:PutItem, GetItem, UpdateItem, DeleteItem, Query, Scan
"""

import json
import boto3
from decimal import Decimal
from botocore.exceptions import ClientError

# --------------------------------------------------------------------------
# Configuración — no hay llaves aquí; boto3 las obtiene del rol EC2
# --------------------------------------------------------------------------
REGION     = "us-east-1"
TABLE_NAME = "movimientos_inventario"

# boto3 detecta automáticamente las credenciales del rol EC2 via IMDS
dynamodb = boto3.resource("dynamodb", region_name=REGION)
table    = dynamodb.Table(TABLE_NAME)

# Separador visual
SEP = "=" * 60


def imprimir_item(label: str, item: dict) -> None:
    """Imprime un ítem DynamoDB con formato legible."""
    print(f"\n  [{label}]")
    for k, v in sorted(item.items()):
        print(f"    {k:<20} : {v}")


# ==========================================================================
# C1 · INSERT — put_item
# ==========================================================================
def c1_insertar() -> None:
    print(f"\n{SEP}")
    print("  C1 · INSERT — put_item (boto3)")
    print(SEP)

    items = [
        {
            "producto_id"   : "PROD-0042",
            "fecha"         : "2026-10-14T09:15:00Z#MOV-8810",
            "movimiento_id" : "MOV-8810",
            "tipo"          : "salida",
            "cantidad"      : Decimal("12"),
            "stock_antes"   : Decimal("80"),
            "stock_despues" : Decimal("68"),
            "usuario_id"    : "USR-003",
            "motivo"        : "Venta mostrador",
            "fecha_dia"     : "2026-10-14",
        },
        {
            "producto_id"   : "PROD-0042",
            "fecha"         : "2026-10-13T14:30:00Z#MOV-8801",
            "movimiento_id" : "MOV-8801",
            "tipo"          : "entrada",
            "cantidad"      : Decimal("50"),
            "stock_antes"   : Decimal("30"),
            "stock_despues" : Decimal("80"),
            "usuario_id"    : "USR-001",
            "motivo"        : "Reposicion proveedor",
            "fecha_dia"     : "2026-10-13",
        },
        {
            "producto_id"   : "PROD-0017",
            "fecha"         : "2026-10-14T11:00:00Z#MOV-8815",
            "movimiento_id" : "MOV-8815",
            "tipo"          : "ajuste",
            "cantidad"      : Decimal("-3"),
            "stock_antes"   : Decimal("15"),
            "stock_despues" : Decimal("12"),
            "usuario_id"    : "USR-001",
            "motivo"        : "Merma por caducidad",
            "fecha_dia"     : "2026-10-14",
        },
    ]

    for item in items:
        resp = table.put_item(Item=item)
        http = resp["ResponseMetadata"]["HTTPStatusCode"]
        print(f"  ✔ Insertado {item['movimiento_id']} (HTTP {http})")

    # Verificar los dos de PROD-0042
    print("\n  Verificacion — Query PROD-0042 DESC:")
    resp = table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key("producto_id").eq("PROD-0042"),
        ScanIndexForward=False,
    )
    print(f"    Count={resp['Count']}  ScannedCount={resp['ScannedCount']}")
    for it in resp["Items"]:
        print(f"    {it['movimiento_id']}  fecha={it['fecha']}")

    print("\n  *** TOMAR CAPTURA C1 AQUÍ ***")


# ==========================================================================
# C2 · QUERY — query  (Q1 y Q2)
# ==========================================================================
def c2_consultar() -> None:
    from boto3.dynamodb.conditions import Key, Attr

    print(f"\n{SEP}")
    print("  C2 · QUERY — query boto3  (Q1 y Q2)")
    print(SEP)

    # Q1: todos los movimientos de PROD-0042, más recientes primero
    print("\n  Q1: todos los movimientos de PROD-0042 (ScanIndexForward=False)")
    resp = table.query(
        KeyConditionExpression=Key("producto_id").eq("PROD-0042"),
        ScanIndexForward=False,
    )
    print(f"  Count={resp['Count']}  ScannedCount={resp['ScannedCount']}")
    for it in resp["Items"]:
        print(f"    {it['movimiento_id']}  {it['fecha']}  tipo={it['tipo']}")

    # Q2: solo salidas de PROD-0042 (filtro sobre misma partición)
    print("\n  Q2: movimientos tipo=salida de PROD-0042")
    resp2 = table.query(
        KeyConditionExpression=Key("producto_id").eq("PROD-0042"),
        FilterExpression=Attr("tipo").eq("salida"),
        ScanIndexForward=False,
    )
    print(f"  Count={resp2['Count']}  ScannedCount={resp2['ScannedCount']}")
    print(f"  (ScannedCount={resp2['ScannedCount']} porque DynamoDB lee toda la")
    print(f"   particion y aplica el filtro despues — ver B02 seccion 4)")
    for it in resp2["Items"]:
        print(f"    {it['movimiento_id']}  tipo={it['tipo']}  motivo={it['motivo']}")

    print("\n  *** TOMAR CAPTURA C2 AQUÍ ***")


# ==========================================================================
# C3 · UPDATE — update_item
# ==========================================================================
def c3_actualizar() -> None:
    from boto3.dynamodb.conditions import Key

    print(f"\n{SEP}")
    print("  C3 · UPDATE — update_item boto3")
    print(SEP)

    pk  = "PROD-0042"
    sk  = "2026-10-14T09:15:00Z#MOV-8810"

    # Estado ANTES
    print("\n  Estado ANTES:")
    antes = table.get_item(Key={"producto_id": pk, "fecha": sk})
    imprimir_item("ANTES", antes["Item"])

    # Actualizar motivo y stock_despues
    resp = table.update_item(
        Key={"producto_id": pk, "fecha": sk},
        UpdateExpression="SET motivo = :m, stock_despues = :sd",
        ExpressionAttributeValues={
            ":m":  "Venta mostrador - corregida",
            ":sd": Decimal("67"),
        },
        ReturnValues="ALL_NEW",
    )

    # Estado DESPUÉS
    print("\n  Estado DESPUES (ALL_NEW):")
    imprimir_item("DESPUES", resp["Attributes"])

    print("\n  *** TOMAR CAPTURA C3 AQUÍ ***")


# ==========================================================================
# C4 · DELETE — delete_item
# ==========================================================================
def c4_eliminar() -> None:
    print(f"\n{SEP}")
    print("  C4 · DELETE — delete_item boto3")
    print(SEP)

    pk = "PROD-0017"
    sk = "2026-10-14T11:00:00Z#MOV-8815"

    # Verificar que existe ANTES
    print("\n  Verificacion ANTES — get_item:")
    resp_antes = table.get_item(Key={"producto_id": pk, "fecha": sk})
    if "Item" in resp_antes:
        imprimir_item("EXISTE", resp_antes["Item"])
    else:
        print("  ⚠  El item no existe — re-insertar con C1 primero.")
        return

    # Eliminar (devolver atributos ALL_OLD)
    print("\n  Ejecutando delete_item (ReturnValues=ALL_OLD):")
    resp_del = table.delete_item(
        Key={"producto_id": pk, "fecha": sk},
        ReturnValues="ALL_OLD",
    )
    imprimir_item("ELIMINADO (atributos devueltos)", resp_del["Attributes"])

    # Confirmar que ya no existe
    print("\n  Confirmacion DESPUES — get_item (debe estar vacio):")
    resp_post = table.get_item(Key={"producto_id": pk, "fecha": sk})
    if "Item" not in resp_post:
        print("  ✔ Item eliminado — get_item devuelve vacio (sin 'Item' en respuesta)")
    else:
        print("  ⚠  El item todavía existe — verificar.")

    print("\n  *** TOMAR CAPTURA C4 AQUÍ ***")


# ==========================================================================
# C5 · SCAN ineficiente
# ==========================================================================
def c5_scan_ineficiente() -> None:
    from boto3.dynamodb.conditions import Attr

    print(f"\n{SEP}")
    print("  C5 · SCAN — consulta ineficiente (sin PK)")
    print(SEP)
    print("\n  ADVERTENCIA: Scan recorre TODOS los items de la tabla.")
    print("  Con 5 items el costo es despreciable, pero a 1 millon de")
    print("  items (asumiendo 200 B/item) el costo escala drasticamente.")
    print("  Ver seccion 8 del reporte para la cuenta completa.")

    resp = table.scan(
        FilterExpression=Attr("tipo").eq("salida"),
        ReturnConsumedCapacity="TOTAL",
    )
    print(f"\n  Resultado:")
    print(f"    Items devueltos  : {resp['Count']}")
    print(f"    Items escaneados : {resp['ScannedCount']}")
    # scan() via resource no devuelve ConsumedCapacity; usar client para verlo
    client = boto3.client("dynamodb", region_name=REGION)
    resp_c = client.scan(
        TableName=TABLE_NAME,
        FilterExpression="#t = :tipo",
        ExpressionAttributeNames={"#t": "tipo"},
        ExpressionAttributeValues={":tipo": {"S": "salida"}},
        ReturnConsumedCapacity="TOTAL",
    )
    cap = resp_c.get("ConsumedCapacity", {}).get("CapacityUnits", "N/A")
    print(f"    Capacidad usada  : {cap} RCUs")

    print("\n  COMPARACION (ver seccion 8 del reporte):")
    print("    SCAN  (sin PK) : lee TODA la tabla  → 2 RCUs para 5 items")
    print("    QUERY (con PK) : lee solo 1 particion → 0.5 RCUs o menos")

    print("\n  *** TOMAR CAPTURA C5 AQUÍ ***")


# ==========================================================================
# Main
# ==========================================================================
def main() -> None:
    # Verificar que las credenciales vienen del rol EC2, no de llaves manuales
    sts = boto3.client("sts", region_name=REGION)
    ident = sts.get_caller_identity()
    arn   = ident["Arn"]
    print(f"\n{SEP}")
    print("  Identidad activa (rol de servicio EC2 — sin llaves):")
    print(f"    ARN     : {arn}")
    print(f"    Cuenta  : {ident['Account']}")
    if "assumed-role" in arn:
        print("  ✔ Credenciales provienen de un ROL ASUMIDO (IMDS / Instance Profile)")
    else:
        print("  ⚠  Credenciales NO son de rol asumido — verificar Instance Profile")
    print(SEP)

    c1_insertar()
    c2_consultar()
    c3_actualizar()
    c4_eliminar()
    c5_scan_ineficiente()

    print(f"\n{SEP}")
    print("  ✔  Todas las operaciones completadas.")
    print(f"{SEP}\n")


if __name__ == "__main__":
    main()
