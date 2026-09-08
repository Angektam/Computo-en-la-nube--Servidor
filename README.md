# Anteproyecto — Sistema de Gestión de Inventarios en la Nube

**Materia:** Cómputo en la Nube  
**Maestra:** Elizabeth Gaxiola Carrillo  
**Alumnos:** López Payán Kevin Ricardo · Flores Guevara Ángel Gabriel  
**Fecha:** Los Mochis, Sinaloa, México, a 03 de septiembre de 2026

---

## Facultad de Ingeniería Mochis — Ingeniería de Software

### Equipo: Los Rojos

| Integrante | Roles |
| :--- | :--- |
| **López Payán Kevin Ricardo** | 1. Responsable de Documentación · 2. Arquitectura de la Solución |
| **Flores Guevara Ángel Gabriel** | 1. Responsable de Desarrollo · 2. Responsable de Seguridad y Costos |

---

## 1. Planteamiento del Problema

En las pequeñas empresas locales, el control manual de inventarios o el uso de hojas de cálculo tradicionales genera una gestión ineficiente del stock. Este método implica un gasto excesivo de tiempo en la captura y actualización de datos, es altamente propenso a errores humanos y dificulta la consulta en tiempo real de los artículos y su cantidad disponible.

Como consecuencia, las empresas enfrentan descuadres en sus inventarios, pérdidas económicas por falta o exceso de mercancía y retrasos en la atención al cliente.

---

## 2. Objetivos del Proyecto

### Objetivo General

Desarrollar un sistema de gestión de inventarios en la nube para pequeñas empresas que automatice el control de stock, el registro de movimientos y la generación de alertas, mejorando la precisión del inventario y reduciendo el tiempo operativo de consulta y registro.

### Objetivos Específicos

- Implementar módulos para el alta de productos y registro de movimientos (entradas/salidas).
- Diseñar un mecanismo automatizado de alertas de existencias mínimas para la generación oportuna de pedidos a proveedores.
- Configurar una base de datos administrada con respaldos automáticos y mecanismos de cifrado para garantizar la seguridad e integridad de la información.
- Desarrollar un módulo de reportes para visibilizar faltantes, sobrantes e historial de gastos acumulados.

---

## 3. Alcance y Limitaciones

### Alcance

**Módulos del Sistema:**
- Alta, baja y modificación de productos.
- Registro de entradas y salidas de almacén.
- Generación de cortes diarios.
- Alertas de stock mínimo.
- Reportes de inventario.

**Manejo de Datos:**
- Gestión mediante base de datos administrada con política de respaldos periódicos y matriz de accesos por roles.

**Usuarios Objetivo:**

| Rol | Descripción |
| :--- | :--- |
| Administrador / Propietario | Acceso total al sistema |
| Encargado / Auxiliar de Bodega | Registro de movimientos y consulta de stock |
| Cajero / Vendedor | Consulta de disponibilidad de productos |

### Limitaciones

- El sistema estará enfocado inicialmente en pequeños negocios locales con un único punto de venta o bodega central.
- No incluirá integración directa con pasarelas de pago electrónicas ni facturación fiscal ante el SAT.
- Requiere conexión a Internet estable para la sincronización con la base de datos administrada en la nube.

---

## Arquitectura en la Nube

```
[Cliente / Navegador]
        │  HTTPS
        ▼
[VM — Nginx (proxy inverso + TLS)]
        │
        ▼
[Node.js / Express — API REST]  ──►  [PostgreSQL gestionado en la nube (Supabase)]
        │
        ▼
[Supabase Storage / Cloudinary — Almacenamiento de archivos e imágenes]
```

---

## Estructura del Proyecto

```
inventario-nube/
├── public/                         ← Frontend (HTML + CSS + JS vanilla)
│   ├── index.html                  ← Página única (SPA)
│   ├── css/
│   │   └── styles.css              ← Estilos completos
│   └── js/
│       ├── api.js                  ← Cliente HTTP base (fetch + JWT)
│       ├── auth.js                 ← Login / logout
│       ├── app.js                  ← Navegación y arranque
│       ├── dashboard.js            ← Tarjetas de resumen
│       ├── productos.js            ← CRUD de productos
│       ├── movimientos.js          ← Registro de movimientos
│       └── reportes.js             ← Faltantes, sobrantes, gastos, corte
├── src/
│   ├── server.js                   ← Express + sirve el frontend estático
│   ├── db/
│   │   ├── connection.js           ← Pool de conexión a PostgreSQL (Supabase)
│   │   ├── supabase.js             ← Cliente Supabase para Storage
│   │   ├── migrate.js              ← Crea las tablas en la BD
│   │   └── seed.js                 ← Datos iniciales de prueba
│   ├── middleware/
│   │   └── auth.middleware.js      ← JWT + control de roles
│   └── routes/
│       ├── health.routes.js        ← GET /health
│       ├── auth.routes.js          ← POST /api/auth/login
│       ├── producto.routes.js      ← CRUD de productos
│       ├── movimiento.routes.js    ← Entradas / salidas / ajustes
│       ├── reporte.routes.js       ← Faltantes, sobrantes, gastos, corte, pedidos
│       └── storage.routes.js       ← Subida de imágenes a Supabase Storage
├── deploy/
│   ├── setup-vm.sh                 ← Configura la VM (Nginx + TLS + PM2)
│   └── deploy.sh                   ← Despliega una nueva versión
├── .env.example
├── .gitignore
└── package.json
```

---

## Configuración Inicial

### 1. Clonar y configurar variables de entorno

```bash
cp .env.example .env
# Editar .env con tus credenciales reales
```

### 2. Instalar dependencias

```bash
npm install
```

### 3. Crear tablas en la base de datos

```bash
node src/db/migrate.js
```

### 4. Cargar datos iniciales (opcional)

```bash
node src/db/seed.js
# Usuario por defecto: admin@empresa.com / Admin1234!
```

### 5. Iniciar el servidor en desarrollo

```bash
npm run dev
```

---

## Despliegue en VM (Producción)

```bash
# 1. Configurar la VM por primera vez (Ubuntu)
sudo bash deploy/setup-vm.sh

# 2. Copiar el .env a la VM
scp .env usuario@ip-vm:/var/www/inventario/.env

# 3. Desplegar actualizaciones
bash deploy/deploy.sh usuario@ip-vm
```

---

## Endpoints Principales

| Método | Ruta | Descripción | Roles |
| :--- | :--- | :--- | :--- |
| GET | `/health` | Estado de DB y storage | público |
| POST | `/api/auth/login` | Iniciar sesión | público |
| GET | `/api/productos` | Listar productos | todos |
| POST | `/api/productos` | Crear producto | admin, bodega |
| PUT | `/api/productos/:id` | Editar producto | admin, bodega |
| POST | `/api/movimientos` | Registrar entrada/salida | admin, bodega |
| GET | `/api/reportes/faltantes` | Productos con stock bajo | todos |
| GET | `/api/reportes/sobrantes` | Productos con exceso | todos |
| GET | `/api/reportes/gastos` | Historial de gastos acumulados | admin |
| GET | `/api/reportes/corte-diario` | Corte del día | admin, bodega |
| GET | `/api/reportes/pedidos` | Pedidos automáticos pendientes | admin, bodega |
| POST | `/api/storage/upload/:id` | Subir imagen de producto | admin, bodega |
| GET | `/api/storage/url-firmada/:id` | URL pre-firmada de imagen | todos |

---

## Criterios de Éxito

1. **Reporte de faltantes y sobrantes** → `/api/reportes/faltantes` y `/api/reportes/sobrantes`
2. **Reducción de tiempo de registros y consultas** → API REST con respuestas en < 200 ms
3. **Generación de pedido automático** → se crea automáticamente al registrar una salida que deja el stock por debajo del mínimo configurado
