#!/bin/bash
# =============================================================================
# T6 · COSTOS DEL PROYECTO · Equipo Los Rojos
# Sistema: Inventario Nube · Cómputo en la Nube
# Entrega: miércoles 4 de noviembre de 2026
#
# Qué hace:
#   1. Consulta precios REALES con AWS Price List API (boto3)
#   2. Calcula el costo mensual del proyecto SIN free tier ni créditos
#   3. Desglosa el costo por servicio (EC2, RDS, S3, DynamoDB, Lambda, etc.)
#   4. Documenta los supuestos (usuarios, horas encendido, GB guardados)
#   5. Genera un reporte listo para captura de pantalla
#
# Cómo usar:
#   1. Abre AWS CloudShell en us-east-1
#   2. Sube este archivo o pega su contenido
#   3. Ejecuta:  bash t6-costos-proyecto.sh
#   4. Toma captura de pantalla del reporte generado
#
# Requisitos: AWS CloudShell (incluye python3 + boto3 + credenciales)
# =============================================================================

set -euo pipefail

# ── Verificar que estamos en CloudShell (o con credenciales AWS) ──
if ! python3 -c "import boto3" 2>/dev/null; then
    echo "ERROR: python3 y boto3 son requeridos. CloudShell los incluye por defecto."
    exit 1
fi

# ══════════════════════════════════════════════════════════════════
# Ejecutar todo en python3 (más robusto que parsear JSON en bash)
# ══════════════════════════════════════════════════════════════════

python3 << 'PYEOF'
import boto3
import json
import sys
from datetime import datetime

# ══════════════════════════════════════════════════════════════════
# SUPUESTOS — ajusta estos valores según tu proyecto
# ══════════════════════════════════════════════════════════════════
REGION          = "us-east-1"
REGION_DISPLAY  = "US East (N. Virginia)"

# EC2 — servidor web (Nginx + Node.js)
EC2_TYPE        = "t3.micro"
EC2_HOURS_MES   = 730           # 24/7
EC2_EBS_GB      = 20            # disco gp3

# RDS — base de datos PostgreSQL
RDS_TYPE        = "db.t3.micro"
RDS_HOURS_MES   = 730           # 24/7
RDS_STORAGE_GB  = 20            # gp2

# S3 — sitio estático + archivos del inventario
S3_GB           = 5             # Standard
S3_PUT_MES      = 1000          # solicitudes PUT
S3_GET_MES      = 10000         # solicitudes GET
S3_IA_GB        = 2             # GB que migran a Standard-IA (lifecycle)

# DynamoDB — tabla movimientos_inventario (on-demand)
DDB_WRITES_MES  = 30000         # ~1000 escrituras/día
DDB_READS_MES   = 150000        # ~5000 lecturas/día

# Lambda — fn-movimientos-los-rojos
LAMBDA_INVOC_MES = 1000
LAMBDA_MEM_MB   = 128
LAMBDA_AVG_MS   = 200           # duración promedio

# API Gateway — HTTP API
APIGW_REQ_MES   = 1000

# Data Transfer — salida a internet
DT_OUT_GB       = 10

# Usuarios
USUARIOS        = 50

# ══════════════════════════════════════════════════════════════════
# PRECIOS DE RESPALDO (se usan si la API no responde)
# Valores de la página pública de AWS Pricing (us-east-1, 2025-2026)
# ══════════════════════════════════════════════════════════════════
FALLBACK = {
    "ec2_hr":       0.0208,     # t3.micro OnDemand /hr
    "rds_hr":       0.026,      # db.t3.micro PostgreSQL Single-AZ /hr
    "ebs_gb":       0.08,       # gp3 /GB-mes
    "rds_stor_gb":  0.115,      # gp2 /GB-mes
    "s3_stor_gb":   0.023,      # Standard /GB-mes
    "s3_put":       0.005,      # PUT por 1,000 requests
    "s3_get":       0.0004,     # GET por 1,000 requests
    "s3_ia_gb":     0.0125,     # Standard-IA /GB-mes
    "ddb_write":    1.25,       # por millón writes
    "ddb_read":     0.25,       # por millón reads
    "lambda_gbs":   0.0000166667,  # por GB-segundo
    "lambda_req":   0.20,       # por millón requests
    "apigw":        1.00,       # HTTP API por millón requests
    "dt_out":       0.09,       # /GB salida a internet
}

# ══════════════════════════════════════════════════════════════════
# FUNCIÓN: extraer precio OnDemand de una entrada del Price List
# ══════════════════════════════════════════════════════════════════
def extract_ondemand_price(price_entry):
    """Extrae el primer precio OnDemand USD de un PriceList entry."""
    try:
        terms = price_entry.get("terms", {}).get("OnDemand", {})
        for term in terms.values():
            for dim in term.get("priceDimensions", {}).values():
                price = dim.get("pricePerUnit", {}).get("USD")
                if price:
                    return float(price)
    except Exception:
        pass
    return None

# ══════════════════════════════════════════════════════════════════
# FUNCIÓN: consultar la AWS Price List API
# ══════════════════════════════════════════════════════════════════
def fetch_price(service_code, filters, fallback_key):
    """Consulta la Price List API y devuelve el precio o un fallback."""
    try:
        client = boto3.client("pricing", region_name="us-east-1")
        resp = client.get_products(
            ServiceCode=service_code,
            Filters=[{"Type": "TERM_MATCH", "Field": f, "Value": v}
                     for f, v in filters],
            MaxResults=1,
        )
        price_list = resp.get("PriceList", [])
        if price_list:
            entry = json.loads(price_list[0])
            price = extract_ondemand_price(entry)
            if price is not None:
                return price, "API"
    except Exception:
        pass
    return FALLBACK[fallback_key], "fallback"

# ══════════════════════════════════════════════════════════════════
# CONSULTAR PRECIOS REALES
# ══════════════════════════════════════════════════════════════════
print()
print("\033[1m\033[36m═══════════════════════════════════════════════════════════════")
print("  T6 · COSTOS DEL PROYECTO · Equipo Los Rojos")
print(f"  Sistema: Inventario Nube · Región: {REGION}")
print("═══════════════════════════════════════════════════════════════\033[0m")
print()
print("\033[34m[INFO]\033[0m Consultando precios reales con AWS Price List API...")
print()

prices = {}
sources = {}

# ── EC2 t3.micro OnDemand Linux ──────────────────────────────────
p, src = fetch_price("AmazonEC2", [
    ("instanceType",    EC2_TYPE),
    ("location",        REGION_DISPLAY),
    ("operatingSystem", "Linux"),
    ("tenancy",         "Shared"),
    ("capacitystatus",  "Used"),
    ("preInstalledSw",  "NA"),
], "ec2_hr")
prices["ec2_hr"] = p; sources["ec2_hr"] = src
print(f"  · EC2 {EC2_TYPE} OnDemand...           \033[32m✔ ${p}/hr\033[0m" if src=="API"
      else f"  · EC2 {EC2_TYPE} OnDemand...           \033[33m(fallback) ${p}/hr\033[0m")

# ── RDS db.t3.micro PostgreSQL Single-AZ ─────────────────────────
p, src = fetch_price("AmazonRDS", [
    ("instanceType",     RDS_TYPE),
    ("location",         REGION_DISPLAY),
    ("engine",           "PostgreSQL"),
    ("deploymentOption", "Single-AZ"),
    ("licenseModel",     "License included"),
], "rds_hr")
prices["rds_hr"] = p; sources["rds_hr"] = src
print(f"  · RDS {RDS_TYPE} PostgreSQL...      \033[32m✔ ${p}/hr\033[0m" if src=="API"
      else f"  · RDS {RDS_TYPE} PostgreSQL...      \033[33m(fallback) ${p}/hr\033[0m")

# ── EBS gp3 (disco EC2) ──────────────────────────────────────────
p, src = fetch_price("AmazonEC2", [
    ("volumeType", "General Purpose"),
    ("location",   REGION_DISPLAY),
], "ebs_gb")
prices["ebs_gb"] = p; sources["ebs_gb"] = src
print(f"  · EBS gp3 (disco EC2)...        \033[32m✔ ${p}/GB-mes\033[0m" if src=="API"
      else f"  · EBS gp3 (disco EC2)...        \033[33m(fallback) ${p}/GB-mes\033[0m")

# ── RDS storage gp2 ──────────────────────────────────────────────
p, src = fetch_price("AmazonRDS", [
    ("volumeType", "General Purpose (SSD)"),
    ("location",   REGION_DISPLAY),
], "rds_stor_gb")
prices["rds_stor_gb"] = p; sources["rds_stor_gb"] = src
print(f"  · RDS storage gp2...            \033[32m✔ ${p}/GB-mes\033[0m" if src=="API"
      else f"  · RDS storage gp2...            \033[33m(fallback) ${p}/GB-mes\033[0m")

# ── S3 Standard storage ──────────────────────────────────────────
p, src = fetch_price("AmazonS3", [
    ("location",     REGION_DISPLAY),
    ("storageClass",  "Standard"),
    ("volumeType",    "Standard"),
], "s3_stor_gb")
prices["s3_stor_gb"] = p; sources["s3_stor_gb"] = src
print(f"  · S3 Standard storage...        \033[32m✔ ${p}/GB-mes\033[0m" if src=="API"
      else f"  · S3 Standard storage...        \033[33m(fallback) ${p}/GB-mes\033[0m")

# ── S3 Standard-IA storage ──────────────────────────────────────
p, src = fetch_price("AmazonS3", [
    ("location",     REGION_DISPLAY),
    ("storageClass",  "Infrequent Access"),
], "s3_ia_gb")
prices["s3_ia_gb"] = p; sources["s3_ia_gb"] = src
print(f"  · S3 Standard-IA...             \033[32m✔ ${p}/GB-mes\033[0m" if src=="API"
      else f"  · S3 Standard-IA...             \033[33m(fallback) ${p}/GB-mes\033[0m")

# ── S3 PUT requests ─────────────────────────────────────────────
p, src = fetch_price("AmazonS3", [
    ("location",  REGION_DISPLAY),
    ("operation",  "PutObject"),
], "s3_put")
prices["s3_put"] = p; sources["s3_put"] = src
print(f"  · S3 PUT requests...            \033[32m✔ ${p}/1K req\033[0m" if src=="API"
      else f"  · S3 PUT requests...            \033[33m(fallback) ${p}/1K req\033[0m")

# ── S3 GET requests ─────────────────────────────────────────────
p, src = fetch_price("AmazonS3", [
    ("location",  REGION_DISPLAY),
    ("operation",  "GetObject"),
], "s3_get")
prices["s3_get"] = p; sources["s3_get"] = src
print(f"  · S3 GET requests...            \033[32m✔ ${p}/1K req\033[0m" if src=="API"
      else f"  · S3 GET requests...            \033[33m(fallback) ${p}/1K req\033[0m")

# ── DynamoDB writes (on-demand) ─────────────────────────────────
p, src = fetch_price("AmazonDynamoDB", [
    ("location",   REGION_DISPLAY),
    ("operation",  "WriteRequestUnit"),
], "ddb_write")
prices["ddb_write"] = p; sources["ddb_write"] = src
print(f"  · DynamoDB writes...            \033[32m✔ ${p}/M writes\033[0m" if src=="API"
      else f"  · DynamoDB writes...            \033[33m(fallback) ${p}/M writes\033[0m")

# ── DynamoDB reads (on-demand) ──────────────────────────────────
p, src = fetch_price("AmazonDynamoDB", [
    ("location",   REGION_DISPLAY),
    ("operation",  "ReadRequestUnit"),
], "ddb_read")
prices["ddb_read"] = p; sources["ddb_read"] = src
print(f"  · DynamoDB reads...             \033[32m✔ ${p}/M reads\033[0m" if src=="API"
      else f"  · DynamoDB reads...             \033[33m(fallback) ${p}/M reads\033[0m")

# ── Lambda compute (GB-s) ──────────────────────────────────────
p, src = fetch_price("AWSLambda", [
    ("location",  REGION_DISPLAY),
    ("group",     "Lambda-Duration"),
], "lambda_gbs")
prices["lambda_gbs"] = p; sources["lambda_gbs"] = src
print(f"  · Lambda compute (GB-s)...      \033[32m✔ ${p}/GB-s\033[0m" if src=="API"
      else f"  · Lambda compute (GB-s)...      \033[33m(fallback) ${p}/GB-s\033[0m")

# ── Lambda requests ─────────────────────────────────────────────
p, src = fetch_price("AWSLambda", [
    ("location",  REGION_DISPLAY),
    ("group",     "Lambda-Requests"),
], "lambda_req")
prices["lambda_req"] = p; sources["lambda_req"] = src
print(f"  · Lambda requests...            \033[32m✔ ${p}/M req\033[0m" if src=="API"
      else f"  · Lambda requests...            \033[33m(fallback) ${p}/M req\033[0m")

# ── API Gateway HTTP API ────────────────────────────────────────
p, src = fetch_price("AmazonApiGateway", [
    ("location",  REGION_DISPLAY),
    ("apiType",   "HTTP"),
], "apigw")
prices["apigw"] = p; sources["apigw"] = src
print(f"  · API Gateway HTTP API...       \033[32m✔ ${p}/M req\033[0m" if src=="API"
      else f"  · API Gateway HTTP API...       \033[33m(fallback) ${p}/M req\033[0m")

# ── Data Transfer Out ──────────────────────────────────────────
p, src = fetch_price("AmazonEC2", [
    ("location",      REGION_DISPLAY),
    ("transferType",  "AmazonEC2 Outbound"),
    ("fromLocation",  REGION_DISPLAY),
    ("toLocation",    "Outside EC2"),
], "dt_out")
prices["dt_out"] = p; sources["dt_out"] = src
print(f"  · Data Transfer Out...         \033[32m✔ ${p}/GB\033[0m" if src=="API"
      else f"  · Data Transfer Out...         \033[33m(fallback) ${p}/GB\033[0m")

print()
print("\033[32m[OK]\033[0m Precios obtenidos. Calculando costos mensuales...")
print()

# ══════════════════════════════════════════════════════════════════
# CÁLCULO DE COSTOS MENSUALES
# ══════════════════════════════════════════════════════════════════

# EC2 compute
c_ec2        = prices["ec2_hr"]     * EC2_HOURS_MES
c_ebs        = prices["ebs_gb"]     * EC2_EBS_GB
st_ec2       = c_ec2 + c_ebs

# RDS
c_rds_comp   = prices["rds_hr"]     * RDS_HOURS_MES
c_rds_stor   = prices["rds_stor_gb"] * RDS_STORAGE_GB
st_rds       = c_rds_comp + c_rds_stor

# S3
c_s3_stor    = prices["s3_stor_gb"] * S3_GB
c_s3_ia      = prices["s3_ia_gb"]   * S3_IA_GB
c_s3_put     = prices["s3_put"]     * (S3_PUT_MES / 1000.0)
c_s3_get     = prices["s3_get"]    * (S3_GET_MES / 1000.0)
st_s3        = c_s3_stor + c_s3_ia + c_s3_put + c_s3_get

# DynamoDB
c_ddb_w      = prices["ddb_write"]  * (DDB_WRITES_MES / 1_000_000)
c_ddb_r      = prices["ddb_read"]   * (DDB_READS_MES / 1_000_000)
st_ddb       = c_ddb_w + c_ddb_r

# Lambda
lambda_mem_gb = LAMBDA_MEM_MB / 1024.0
lambda_sec    = LAMBDA_AVG_MS / 1000.0
c_lambda_c   = lambda_mem_gb * lambda_sec * LAMBDA_INVOC_MES * prices["lambda_gbs"]
c_lambda_r   = prices["lambda_req"] * (LAMBDA_INVOC_MES / 1_000_000)
st_lambda    = c_lambda_c + c_lambda_r

# API Gateway
st_apigw     = prices["apigw"] * (APIGW_REQ_MES / 1_000_000)

# Data Transfer
c_dt         = prices["dt_out"] * DT_OUT_GB

# Total
total        = st_ec2 + st_rds + st_s3 + st_ddb + st_lambda + st_apigw + c_dt
total_anio   = total * 12

# ══════════════════════════════════════════════════════════════════
# GENERAR REPORTE
# ══════════════════════════════════════════════════════════════════

fecha = datetime.now().strftime("%Y-%m-%d %H:%M")

# Contar cuántos precios vinieron de la API vs fallback
api_count = sum(1 for s in sources.values() if s == "API")
fb_count  = sum(1 for s in sources.values() if s == "fallback")

# Construir líneas del desglose
rows = [
    ("EC2 (" + EC2_TYPE + ")",
     f"${prices['ec2_hr']}/hr x{EC2_HOURS_MES}",
     st_ec2),
    ("  |- EBS gp3 (" + str(EC2_EBS_GB) + "GB)",
     f"${prices['ebs_gb']}/GB-mes",
     c_ebs),
    ("  |- EC2 compute",
     f"${prices['ec2_hr']}/hr x{EC2_HOURS_MES}",
     c_ec2),
    ("RDS (" + RDS_TYPE + " PostgreSQL)",
     f"${prices['rds_hr']}/hr x{RDS_HOURS_MES}",
     st_rds),
    ("  |- RDS compute",
     f"${prices['rds_hr']}/hr x{RDS_HOURS_MES}",
     c_rds_comp),
    ("  |- RDS storage (" + str(RDS_STORAGE_GB) + "GB)",
     f"${prices['rds_stor_gb']}/GB-mes",
     c_rds_stor),
    ("S3 Standard (" + str(S3_GB) + "GB)",
     f"${prices['s3_stor_gb']}/GB-mes",
     c_s3_stor),
    ("S3 Standard-IA (" + str(S3_IA_GB) + "GB)",
     f"${prices['s3_ia_gb']}/GB-mes",
     c_s3_ia),
    ("S3 requests (PUT+GET)",
     f"PUT ${prices['s3_put']}/1K + GET ${prices['s3_get']}/1K",
     c_s3_put + c_s3_get),
    ("DynamoDB (on-demand)",
     "por request",
     st_ddb),
    ("  |- Writes (" + f"{DDB_WRITES_MES:,}" + ")",
     f"${prices['ddb_write']}/M",
     c_ddb_w),
    ("  |- Reads (" + f"{DDB_READS_MES:,}" + ")",
     f"${prices['ddb_read']}/M",
     c_ddb_r),
    ("Lambda (" + f"{LAMBDA_INVOC_MES:,}" + " invoc.)",
     f"${prices['lambda_gbs']}/GB-s",
     st_lambda),
    ("API Gateway (HTTP API)",
     f"${prices['apigw']}/M reqs",
     st_apigw),
    ("Data Transfer Out (" + str(DT_OUT_GB) + "GB)",
     f"${prices['dt_out']}/GB",
     c_dt),
    ("VPC + Subnets + SG + IGW",
     "-",
     0.0),
    ("IAM (Roles + Policies)",
     "-",
     0.0),
]

# ── Imprimir el reporte completo ──────────────────────────────────
report_lines = []
def out(s=""):
    print(s)
    report_lines.append(s)

out("═══════════════════════════════════════════════════════════════════════")
out("  T6 · COSTOS DEL PROYECTO · Equipo Los Rojos")
out(f"  Sistema: Inventario Nube · Región: {REGION}")
out(f"  Fecha de estimación: {fecha}")
out(f"  Fuente de precios: AWS Price List API ({api_count} reales + {fb_count} fallback)")
out("═══════════════════════════════════════════════════════════════════════")
out()
out("  ┌─────────────────────────────────────────────────────────────┐")
out("  │  SUPUESTOS                                                  │")
out("  ├─────────────────────────────────────────────────────────────┤")
out(f"  │  Usuarios activos del sistema:    {USUARIOS}                       │")
out("  │                                                             │")
out(f"  │  EC2 ({EC2_TYPE}):                                              │")
out(f"  │    · Horas encendido:  {EC2_HOURS_MES} hrs/mes (24/7)             │")
out(f"  │    · Disco EBS:        {EC2_EBS_GB} GB (gp3)                        │")
out("  │                                                             │")
out(f"  │  RDS ({RDS_TYPE} PostgreSQL):                                 │")
out(f"  │    · Horas encendido:  {RDS_HOURS_MES} hrs/mes (24/7)             │")
out(f"  │    · Almacenamiento:   {RDS_STORAGE_GB} GB (gp2)                   │")
out("  │    · Configuración:    Single-AZ, cifrado en reposo        │")
out("  │                                                             │")
out("  │  S3:                                                         │")
out(f"  │    · GB guardados:     {S3_GB} GB (Standard)                     │")
out(f"  │    · Lifecycle -> IA:  {S3_IA_GB} GB (tras 30 días)               │")
out(f"  │    · Requests PUT:     {S3_PUT_MES:,}/mes                       │")
out(f"  │    · Requests GET:     {S3_GET_MES:,}/mes                      │")
out("  │                                                             │")
out("  │  DynamoDB (on-demand):                                      │")
out(f"  │    · Escrituras:       {DDB_WRITES_MES:,}/mes (~1000/día)        │")
out(f"  │    · Lecturas:         {DDB_READS_MES:,}/mes (~5000/día)       │")
out("  │                                                             │")
out("  │  Lambda (fn-movimientos):                                  │")
out(f"  │    · Invocaciones:     {LAMBDA_INVOC_MES:,}/mes                    │")
out(f"  │    · Memoria:           {LAMBDA_MEM_MB} MB                         │")
out(f"  │    · Duración promedio: {LAMBDA_AVG_MS} ms                         │")
out("  │                                                             │")
out("  │  API Gateway (HTTP API):                                   │")
out(f"  │    · Requests:         {APIGW_REQ_MES:,}/mes                     │")
out("  │                                                             │")
out("  │  Data Transfer:                                             │")
out(f"  │    · Salida a internet: {DT_OUT_GB} GB/mes                       │")
out("  │                                                             │")
out("  │  NAT Gateway:          NO (descartado por costo en P05)   │")
out("  │  VPC/Subnets/SG/IGW:   Sin costo (infraestructura de red)  │")
out("  │  IAM Roles/Policies:   Sin costo                           │")
out("  │  Free tier/creditos:   NO aplican (precio OnDemand real)  │")
out("  └─────────────────────────────────────────────────────────────┘")
out()
out("  DESGLOSE DE COSTO MENSUAL POR SERVICIO")
out("  ═══════════════════════════════════════════════════════════════")
out(f"  {'Servicio':<34} {'Precio base':<34} {'Costo/mes':>10}")
out("  ────────────────────────────────────────────────────────────────")
for name, base, cost in rows:
    out(f"  {name:<34} {base:<34} ${cost:>9.2f}")
out("  ────────────────────────────────────────────────────────────────")
out(f"  {'TOTAL MENSUAL':<34} {'':34} ${total:>9.2f}")
out("  ═══════════════════════════════════════════════════════════════")
out(f"  {'COSTO ANUAL ESTIMADO':<34} {'':34} ${total_anio:>9.2f}")
out("  ═══════════════════════════════════════════════════════════════")
out()
out("  SERVICIOS SIN COSTO MENSUAL:")
out("  · VPC, subredes (publica+privada), tablas de ruteo, Internet Gateway")
out("  · Security Groups (EC2 y RDS)")
out("  · IAM: roles, politicas, instance profiles, key pairs")
out("  · CloudWatch Logs: capa gratuita cubre el uso del proyecto")
out("  · Route 53: no configurado (usamos IP publica de EC2)")
out()
out("  NOTA SOBRE EL FREE TIER:")
out("  Estos precios asumen que NO hay capa gratuita (Free Tier) ni creditos")
out("  AWS Educate. En el Free Tier real, EC2 t3.micro tendria 750 hrs/mes")
out("  gratis y RDS db.t3.micro tendria 750 hrs/mes gratis, lo que reduciria")
out("  el costo significativamente durante el primer año.")
out()
out("  ═══════════════════════════════════════════════════════════════")
out("  SUPUESTOS DETALLADOS (media cuartilla)")
out("  ═══════════════════════════════════════════════════════════════")
out()
out("  La estimacion corresponde al sistema \"Inventario Nube\" del equipo")
out("  Los Rojos, desplegado en la region us-east-1 de AWS.")
out()
out("  USUARIOS: Se asumen 50 usuarios activos que interactuan con el")
out("  sistema de inventario diariamente. Cada usuario registra")
out("  movimientos de entrada/salida de productos, consulta existencias")
out("  y sube documentos (facturas, reportes) al almacenamiento S3.")
out()
out("  HORAS DE ENCENDIDO: El servidor EC2 (t3.micro) y la base de datos")
out("  RDS (db.t3.micro PostgreSQL) se consideran encendidos 24/7 (730")
out("  horas/mes). Esto refleja un escenario de produccion donde el")
out("  sistema debe estar siempre disponible. En la practica escolar,")
out("  el equipo detiene las instancias fuera de horario de clase para")
out("  minimizar consumo de Free Tier.")
out()
out("  ALMACENAMIENTO (GB):")
out(f"  · EC2 EBS: {EC2_EBS_GB} GB (sistema operativo + aplicacion + logs)")
out(f"  · RDS: {RDS_STORAGE_GB} GB (base de datos PostgreSQL del inventario)")
out(f"  · S3 Standard: {S3_GB} GB (sitio estatico + archivos subidos)")
out(f"  · S3 Standard-IA: {S3_IA_GB} GB (objetos migrados por lifecycle rule a")
out("    los 30 días, para reducir costo de almacenamiento)")
out("  · DynamoDB: sin costo de almacenamiento en modo on-demand")
out()
out("  DYNAMODB: La tabla movimientos_inventario opera en modo bajo")
out("  demanda (PAY_PER_REQUEST). Se estiman ~1000 escrituras/dia")
out("  (registro de movimientos) y ~5000 lecturas/dia (consultas de")
out(f"  inventario), totalizando {DDB_WRITES_MES:,} escrituras y {DDB_READS_MES:,} lecturas/mes.")
out()
out("  LAMBDA + API GATEWAY: La funcion fn-movimientos-los-rojos (128 MB,")
out(f"  timeout 10s) se invoca ~{LAMBDA_INVOC_MES:,} veces/mes para consultas de stock")
out("  via API Gateway HTTP API. La duracion promedio por invocacion es de")
out("  200ms. El costo de estos servicios es marginal por el bajo volumen.")
out()
out("  DATA TRANSFER: Se asumen 10 GB/mes de trafico saliente a internet")
out("  (respuestas HTTP, descargas de archivos, imagenes del sitio).")
out()
out("  NAT GATEWAY: No se incluye. En la Practica 05 se analizo el costo")
out("  (~$32/mes en horas + $0.045/GB procesado) y se decidio que la")
out("  subred privada no necesita acceso a internet para RDS.")
out()
out("  SERVICIOS SIN COSTO: VPC, subredes, tablas de ruteo, Internet")
out("  Gateway, Security Groups, IAM (roles y politicas) y CloudWatch")
out("  Logs no generan costo mensual con el nivel de uso del proyecto.")
out()
out("  ═══════════════════════════════════════════════════════════════")
out("  TOMAR CAPTURA DE PANTALLA DE TODO LO ANTERIOR ↑")
out("  ═══════════════════════════════════════════════════════════════")

# ── Guardar el reporte en un archivo ─────────────────────────────
report_text = "\n".join(report_lines)
with open("/tmp/t6-costos-reporte.txt", "w", encoding="utf-8") as f:
    f.write(report_text)

# Intentar copiar al directorio de trabajo
try:
    import shutil
    shutil.copy("/tmp/t6-costos-reporte.txt", "t6-costos-reporte.txt")
    saved = True
except Exception:
    saved = False

print()
print("\033[32m[OK]\033[0m Reporte generado.")
if saved:
    print("\033[32m[OK]\033[0m Guardado en: t6-costos-reporte.txt")
print("\033[33m[TIP]\033[0m Toma captura de pantalla del reporte de arriba")
print("\033[33m[TIP]\033[0m El archivo t6-costos-reporte.txt tiene el texto de supuestos")
print()

PYEOF
