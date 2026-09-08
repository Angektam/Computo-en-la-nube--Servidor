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
