# Comandos Importantes — Inventario Nube

## 🚀 Estado del sistema
```bash
pm2 list                          # Ver todos los procesos
pm2 logs                          # Logs en tiempo real
pm2 logs inventario-api --lines 50  # Últimas 50 líneas del servidor
curl http://localhost:3000/health  # Verificar que el servidor responde
```

## 🌐 URL pública (ngrok)

### Instalar ngrok (solo una vez)
```bash
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok
```

### Configurar token (solo una vez)
```bash
ngrok config add-authtoken 2w3zjtNaxVs9wCrQnv1Q8M6qZFW_5FgrVRPeLwd7otwTpW9Cb
```

### Exponer el proyecto al internet
```bash
ngrok http 3000
```

### Ver la URL pública actual (mientras ngrok está corriendo)
```bash
curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*ngrok-free.app'
```
> ⚠️ La URL cambia cada vez que se reinicia ngrok (plan gratuito)

## 🔄 Reiniciar servicios
```bash
pm2 restart inventario-api --update-env   # Reiniciar servidor con nuevo .env
pm2 restart ngrok-tunnel                  # Reiniciar ngrok
pm2 restart all                           # Reiniciar todo
```

## 🛑 Detener servicios
```bash
pm2 stop inventario-api    # Detener servidor
pm2 stop ngrok-tunnel      # Detener ngrok
pm2 stop all               # Detener todo
```

## ⚙️ Configuración inicial (solo una vez)
```bash
pm2 save                              # Guardar lista de procesos
pm2 startup systemd -u ppp --hp /home/ppp   # Generar script de arranque automático
# Copiar y ejecutar el comando sudo que genera
```

## 🗄️ Base de datos (RDS)
```bash
cd ~/Downloads/COMPUTO-EN-LA-NUVE
npm run migrate    # Crear tablas (solo si se borran)
npm run seed       # Insertar datos de prueba (solo una vez)
```

## 🔑 Usuarios del sistema
| Correo               | Contraseña   | Rol            |
|----------------------|-------------|----------------|
| admin@empresa.com    | Admin1234!  | Administrador  |
| bodega@empresa.com   | Admin1234!  | Bodega         |
| cajero@empresa.com   | Admin1234!  | Cajero         |

## ☁️ Infraestructura AWS
| Servicio | Recurso               | Región     |
|----------|-----------------------|------------|
| RDS      | inventario-db         | us-east-1  |
| S3       | inventario-archivos-losrojos | mx-central-1 |

## 🗄️ Conectar a AWS RDS desde Ubuntu

### 1. Instalar cliente PostgreSQL (solo una vez)
```bash
sudo apt install -y postgresql-client
```

### 2. Conectarse directo a RDS
```bash
psql -h TU_ENDPOINT.rds.amazonaws.com \
     -U postgres \
     -d inventario \
     -p 5432
# Te pedirá la contraseña de RDS
```

### 3. Ver tablas y datos dentro de psql
```bash
\dt                          # listar todas las tablas
\d productos                 # ver estructura de una tabla
SELECT * FROM usuarios;      # ver usuarios
SELECT * FROM productos;     # ver productos
SELECT * FROM movimientos ORDER BY fecha DESC LIMIT 10;  # últimos movimientos
SELECT COUNT(*) FROM movimientos;  # total de movimientos
\q                           # salir
```

### 4. Conectar el proyecto a RDS (cambiar .env)
```bash
# Editar el .env con los datos de tu RDS
sed -i "s|DB_HOST=.*|DB_HOST=TU_ENDPOINT.rds.amazonaws.com|" \
    /home/ppp/Downloads/COMPUTO-EN-LA-NUVE/.env
sed -i "s|DB_USER=.*|DB_USER=postgres|" \
    /home/ppp/Downloads/COMPUTO-EN-LA-NUVE/.env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=TU_PASSWORD_RDS|" \
    /home/ppp/Downloads/COMPUTO-EN-LA-NUVE/.env
sed -i "s|DB_SSL=.*|DB_SSL=true|" \
    /home/ppp/Downloads/COMPUTO-EN-LA-NUVE/.env

# Reiniciar para aplicar cambios
pm2 restart inventario-api --update-env
```

### 5. Crear tablas y datos en RDS (después de conectar)
```bash
cd /home/ppp/Downloads/COMPUTO-EN-LA-NUVE
node src/db/migrate.js   # crear tablas
node src/db/seed.js      # cargar datos de prueba
```

### 6. Verificar conexión
```bash
curl http://localhost:3000/health
# Debe mostrar: "db":"ok"
```

### 7. Ver el endpoint de tu RDS (necesitas AWS CLI)
```bash
# Instalar AWS CLI
sudo apt install -y awscli

# Configurar credenciales
aws configure
# Access Key ID:     tu_access_key
# Secret Access Key: tu_secret_key
# Region:            us-east-1
# Output format:     json

# Ver instancias RDS
aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address,DBInstanceStatus]' \
    --output table

# Ver endpoint específico
aws rds describe-db-instances \
    --db-instance-identifier inventario-db \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text
```

### 8. Abrir puerto 5432 en Security Group de RDS
```bash
# Ver security groups
aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].[GroupId,GroupName]' \
    --output table

# Abrir puerto 5432 a tu IP actual
MI_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
    --group-id sg-XXXXXXXXX \
    --protocol tcp \
    --port 5432 \
    --cidr "${MI_IP}/32"
```

## 🔧 Actualizar .env en la VM
```bash
sed -i 's|DB_HOST=.*|DB_HOST=inventario-db.citeqg0wepbd.us-east-1.rds.amazonaws.com|' ~/Downloads/COMPUTO-EN-LA-NUVE/.env
sed -i 's|AWS_REGION=.*|AWS_REGION=us-east-1|' ~/Downloads/COMPUTO-EN-LA-NUVE/.env
pm2 restart inventario-api --update-env
```

## 🚨 Si el puerto 3000 está ocupado
```bash
sudo fuser -k 3000/tcp
pm2 restart inventario-api
```

---

## 🌐 PRÁCTICA 05 — La red del proyecto

### Scripts en orden de ejecución (todos en AWS CloudShell)

```bash
# PASO 1 — Crear toda la infraestructura de red
bash deploy/aws-practica05-vpc-red.sh

# PASO 2 — Evidencias individuales por entregable
bash deploy/evidencia-p05-e1-subredes.sh       # E1: VPC y subredes con rangos
bash deploy/evidencia-p05-e2-tablas-ruteo.sh   # E2: Tablas de ruteo pública vs privada
bash deploy/evidencia-p05-e3-privada-inaccesible.sh  # E3: Subred privada inalcanzable
bash deploy/evidencia-p05-e4-security-groups.sh # E4: Reglas de tráfico por componente
bash deploy/evidencia-p05-e5-nat-costo.sh      # E5: NAT Gateway e implicación de costo
bash deploy/evidencia-p05-e6-diagrama-red.sh   # E6: Diagrama con IDs reales
```

### Recursos creados
| Recurso | Nombre | CIDR / Puerto |
|---------|--------|---------------|
| VPC | vpc-inventario-cloud-los-rojos | 10.0.0.0/16 |
| Subred pública | subnet-pub-inventario-cloud-los-rojos | 10.0.1.0/24 (us-east-1a) |
| Subred privada | subnet-priv-inventario-cloud-los-rojos | 10.0.2.0/24 (us-east-1b) |
| Internet Gateway | igw-inventario-cloud-los-rojos | — |
| Tabla ruteo pub | rt-pub-inventario-cloud-los-rojos | 0.0.0.0/0 → IGW |
| Tabla ruteo priv | rt-priv-inventario-cloud-los-rojos | solo local |
| SG EC2 | sg-ec2-inventario-cloud-los-rojos | 22(IP-equipo), 80, 443, 3000 |
| SG RDS | sg-rds-inventario-cloud-los-rojos | 5432 ← SG-EC2 |

### Entregables del PDF
| # | Entregable | Script de evidencia |
|---|-----------|-------------------|
| E1 | Red y subredes con rangos | `evidencia-p05-e1-subredes.sh` |
| E2 | Dos tablas de ruteo | `evidencia-p05-e2-tablas-ruteo.sh` |
| E3 | Subred privada inaccesible | `evidencia-p05-e3-privada-inaccesible.sh` |
| E4 | Reglas de tráfico por componente | `evidencia-p05-e4-security-groups.sh` |
| E5 | Respuesta Paso 6 + costo NAT | `evidencia-p05-e5-nat-costo.sh` |
| E6 | Diagrama de red con IDs reales | `evidencia-p05-e6-diagrama-red.sh` |

---

## 📦 PRÁCTICA 04 — Sitio estático en S3

### Bucket del sitio informativo
```
Nombre : sitio-inventario-cloud-los-rojos
Región : us-east-1
URL    : http://sitio-inventario-cloud-los-rojos.s3-website-us-east-1.amazonaws.com
```

### Flujo completo (ejecutar en orden)

#### 1. Desde AWS CloudShell — crear bucket, bloqueo, website hosting, política y ciclo de vida
```bash
bash deploy/aws-practica04-s3-estatico.sh
```

#### 2. Desde tu máquina local — subir los archivos del sitio
```bash
bash deploy/p04-subir-archivos-local.sh
```
> Captura el HTTP 403 ANTES de aplicar la política (evidencia requerida)

#### 3. Generar evidencias individuales por criterio
```bash
# Criterios 1 y 2: bucket, etiquetas y justificación del bloqueo
bash deploy/evidencia-criterio-p04-bucket.sh

# Criterios 3, 4 y 6: política comentada, sitio accesible y ciclo de vida
bash deploy/evidencia-criterio-p04-sitio.sh

# Criterio 5: comparación S3 vs EC2 (media cuartilla)
bash deploy/evidencia-criterio-p04-comparacion.sh
```

### Subir archivos manualmente (sin script)
```bash
# Página informativa → index.html en S3
aws s3 cp public/info.html s3://sitio-inventario-cloud-los-rojos/index.html

# Estilos
aws s3 cp public/css/styles.css s3://sitio-inventario-cloud-los-rojos/css/styles.css

# Verificar objetos subidos
aws s3 ls s3://sitio-inventario-cloud-los-rojos --recursive --human-readable
```

### Verificar sitio en línea
```bash
curl -I http://sitio-inventario-cloud-los-rojos.s3-website-us-east-1.amazonaws.com
# Debe retornar HTTP/1.1 200 OK
```

### Ver política actual del bucket
```bash
aws s3api get-bucket-policy \
  --bucket sitio-inventario-cloud-los-rojos \
  --query Policy --output text | python3 -m json.tool
```

### Recursos S3 en la cuenta
| Bucket | Uso |
|--------|-----|
| `inventario-archivos-losrojos` | Imágenes de productos (API) |
| `sitio-inventario-cloud-los-rojos` | Sitio informativo estático (P04) |

---

## ⚡ PRÁCTICA 09 — Cómputo sin servidor: Lambda + API Gateway

**Funcionalidad:** Consulta de movimientos de inventario por producto  
**Ruta:** `GET /movimientos/{producto_id}`  
**Tabla DynamoDB:** `movimientos_inventario`

### Flujo completo (todos en AWS CloudShell)

```bash
# PASO 1 — Despliegue completo: IAM Role + Lambda + API Gateway
bash practica09/aws-practica09-lambda.sh

# PASO 2 — Evidencias por criterio (tomar captura de cada una)
bash practica09/evidencia-p09-c1-justificacion.sh   # C1 (15 pts): funcionalidad elegida vs descartadas
bash practica09/evidencia-p09-c2-funcion-datos.sh   # C2 (25 pts): función + rol de servicio
bash practica09/evidencia-p09-c3-interfaz-publica.sh # C3 (20 pts): API pública responde
bash practica09/evidencia-p09-c4-arranque-frio.sh   # C4 (20 pts): cold start vs warm start
bash practica09/evidencia-p09-c5-costo-comparativo.sh # C5 (20 pts): Lambda vs EC2
```

> ⚠️ Para C4 (arranque en frío): esperar al menos **5-10 minutos** sin invocar la función antes de ejecutar el script.

### Recursos creados

| Recurso | Nombre | Valor |
|---------|--------|-------|
| Lambda | `fn-movimientos-los-rojos` | Python 3.12, 128 MB, 10 s |
| Execution Role | `rol-lambda-los-rojos` | dynamodb:Query,GetItem,DescribeTable |
| Política inline | `pol-lambda-dynamodb-los-rojos` | Solo sobre `movimientos_inventario` |
| API Gateway | `api-inventario-cloud-los-rojos` | HTTP API v2, CORS habilitado |
| Ruta principal | `GET /movimientos/{producto_id}` | Integración Lambda-proxy |
| Ruta de stock | `GET /movimientos/{producto_id}/stock` | Último movimiento del producto |
| Log group | `/aws/lambda/fn-movimientos-los-rojos` | CloudWatch Logs automático |

### Comandos útiles de operación

```bash
# Invocar la función directamente (sin API Gateway)
aws lambda invoke \
  --function-name fn-movimientos-los-rojos \
  --region us-east-1 \
  --payload '{"httpMethod":"GET","path":"/movimientos/PROD-0042","pathParameters":{"producto_id":"PROD-0042"},"queryStringParameters":null,"headers":{},"requestContext":{}}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/out.json ; cat /tmp/out.json

# Ver configuración actual de la función
aws lambda get-function-configuration \
  --function-name fn-movimientos-los-rojos \
  --region us-east-1 \
  --query "{Memoria:MemorySize,Timeout:Timeout,Runtime:Runtime,Estado:State}" \
  --output table

# Ver URL de la API Gateway
aws apigatewayv2 get-apis \
  --region us-east-1 \
  --query "Items[?Name=='api-inventario-cloud-los-rojos'].{Nombre:Name,URL:ApiEndpoint}" \
  --output table

# Ver logs recientes (CloudWatch)
aws logs tail /aws/lambda/fn-movimientos-los-rojos \
  --region us-east-1 \
  --since 30m \
  --format short

# Ver REPORT lines (duración + memoria usada)
aws logs filter-log-events \
  --log-group-name /aws/lambda/fn-movimientos-los-rojos \
  --region us-east-1 \
  --filter-pattern "REPORT" \
  --query "events[*].message" \
  --output text

# Actualizar código de la función (tras modificar lambda_function.py)
cd practica09
zip -j /tmp/fn-movimientos-los-rojos.zip lambda_function.py
aws lambda update-function-code \
  --function-name fn-movimientos-los-rojos \
  --zip-file fileb:///tmp/fn-movimientos-los-rojos.zip \
  --region us-east-1
```

### Prueba rápida desde curl

```bash
# Reemplaza <API_ID> con el ID real (lo muestra aws-practica09-lambda.sh al final)
API_URL="https://<API_ID>.execute-api.us-east-1.amazonaws.com"

# Todos los movimientos de PROD-0042
curl -s "${API_URL}/movimientos/PROD-0042" | python3 -m json.tool

# Solo el stock actual
curl -s "${API_URL}/movimientos/PROD-0042/stock" | python3 -m json.tool

# Filtrar por tipo
curl -s "${API_URL}/movimientos/PROD-0042?tipo=salida" | python3 -m json.tool

# Producto inexistente → debe devolver 404
curl -s "${API_URL}/movimientos/PROD-9999" | python3 -m json.tool
```

### Cálculo de costo rápido (10,000 invocaciones/mes)

| Concepto | Lambda | EC2 t3.micro 24/7 |
|----------|--------|-------------------|
| Costo cómputo | $0.0017 USD/mes | — |
| Costo requests | $0.0020 USD/mes | — |
| **Total** | **~$0.004 USD/mes** | **$7.59 USD/mes** |
| Con capa gratuita | **$0.000 USD/mes** | $7.59 USD/mes |

> Fuentes: [Lambda pricing](https://aws.amazon.com/lambda/pricing/) · [EC2 On-Demand us-east-1](https://aws.amazon.com/ec2/pricing/on-demand/)

### Comparación: EC2 vs Lambda para esta funcionalidad

| Criterio | Lambda | EC2 |
|----------|--------|-----|
| Costo (10K req/mes) | ~$0.004 | ~$7.59 |
| Escala a cero | ✔ Sí | ✗ No |
| Administración de SO | ✔ Ninguna | ✗ Parches, reinicio |
| Cold start | ✗ ~300 ms init | ✔ Siempre caliente |
| Tiempo de ejecución | ✔ Máx 15 min | ✔ Sin límite |
| Adecuado para esta func. | ✔ Sí (esporádica) | ✗ Sobredimensionado |

### Archivos del repositorio

| Archivo | Propósito |
|---------|-----------|
| `practica09/lambda_function.py` | Código de la función (Python 3.12) |
| `practica09/aws-practica09-lambda.sh` | Despliegue completo (IAM + Lambda + APIGW) |
| `practica09/evidencia-p09-c1-justificacion.sh` | Evidencia C1 |
| `practica09/evidencia-p09-c2-funcion-datos.sh` | Evidencia C2 |
| `practica09/evidencia-p09-c3-interfaz-publica.sh` | Evidencia C3 |
| `practica09/evidencia-p09-c4-arranque-frio.sh` | Evidencia C4 |
| `practica09/evidencia-p09-c5-costo-comparativo.sh` | Evidencia C5 |
| `generar_P09.py` | Generador del documento Word |
| `P09_LosRojos_26oct2026.docx` | Documento de entrega |
