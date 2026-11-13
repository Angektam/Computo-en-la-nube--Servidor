# Arquitectura y modelo de datos

## Diagrama de arquitectura

```mermaid
flowchart TB
    U[Usuario / navegador]
    IGW[Internet Gateway]
    OBJ[S3 privado\nImágenes y archivos]
    STATIC[S3\nFrontend estático\nAlternativa]

    U -->|HTTPS| IGW
    U -.->|Publicación alternativa| STATIC

    subgraph VPC["VPC de AWS"]
        subgraph PUB["Subred pública · Security Group EC2"]
            EC2[EC2\nNginx + Node.js/Express\nFrontend + API REST]
        end
        subgraph PRIV["Subred privada · Security Group RDS"]
            RDS[RDS PostgreSQL\nBase de datos\nBackups automáticos]
        end
        IAM[IAM Role\npara EC2]
        CW[CloudWatch\nLogs y métricas]
    end

    IGW --> PUB
    EC2 -->|PostgreSQL / TLS| PRIV
    EC2 -->|SDK / URLs firmadas| OBJ
    IAM -.->|Permisos| EC2
    EC2 -.->|Logs| CW
```

### Flujo principal

1. El navegador llega por HTTPS a través del Internet Gateway.
2. EC2 se encuentra en la subred pública y ejecuta Nginx, Node.js y Express.
3. Nginx entrega el frontend y redirige las rutas de API a Node.js/Express.
4. Node.js/Express valida JWT y roles antes de ejecutar la operación.
5. La API consulta o actualiza PostgreSQL en RDS mediante TLS.
6. RDS está en una subred privada y solo acepta conexiones desde EC2.
7. Las imágenes de productos se almacenan en S3 y la API entrega URLs firmadas.
8. CloudWatch recibe logs y métricas; IAM autoriza el acceso de EC2 a S3.

## Modelo de datos

```mermaid
erDiagram
    USUARIOS ||--o{ MOVIMIENTOS : registra
    CATEGORIAS ||--o{ PRODUCTOS : agrupa
    PRODUCTOS ||--o{ MOVIMIENTOS : tiene
    PRODUCTOS ||--o{ PEDIDOS : genera
    PROVEEDORES ||--o{ PEDIDOS : atiende
    PEDIDOS ||--o{ PEDIDO_EVENTOS : registra
    PEDIDOS ||--o{ PEDIDO_RECEPCIONES : recibe
    USUARIOS ||--o{ PEDIDO_EVENTOS : ejecuta
    USUARIOS ||--o{ PEDIDO_RECEPCIONES : confirma

    USUARIOS {
        int id PK
        varchar nombre
        varchar correo UK
        varchar password
        varchar rol
        boolean activo
        timestamp creado_en
    }

    CATEGORIAS {
        int id PK
        varchar nombre UK
        text descripcion
        varchar abreviacion
    }

    PRODUCTOS {
        int id PK
        varchar codigo UK
        varchar nombre
        text descripcion
        int categoria_id FK
        numeric precio
        int stock_actual
        int stock_minimo
        varchar unidad
        text imagen_url
        boolean activo
        timestamp creado_en
        timestamp actualizado_en
    }

    MOVIMIENTOS {
        int id PK
        int producto_id FK
        int usuario_id FK
        varchar tipo
        int cantidad
        int stock_antes
        int stock_despues
        text motivo
        timestamp fecha
    }

    PEDIDOS {
        int id PK
        int producto_id FK
        int proveedor_id FK
        int cantidad_sugerida
        int cantidad_recibida
        numeric costo_unitario
        date entrega_estimada
        varchar estado
        timestamp generado_en
        timestamp actualizado_en
    }

    PROVEEDORES {
        int id PK
        varchar nombre UK
        varchar contacto
        varchar correo
        varchar telefono
        boolean activo
    }

    PEDIDO_EVENTOS {
        int id PK
        int pedido_id FK
        int usuario_id FK
        varchar tipo
        varchar estado_anterior
        varchar estado_nuevo
        int cantidad
        text detalle
        timestamp creado_en
    }

    PEDIDO_RECEPCIONES {
        int id PK
        int pedido_id FK
        int usuario_id FK
        int cantidad
        int movimiento_id FK
        timestamp creado_en
    }
```

### Reglas principales

- `usuarios.rol`: `administrador`, `bodega` o `cajero`.
- `movimientos.tipo`: `entrada`, `salida` o `ajuste`.
- `pedidos.estado`: `pendiente`, `enviado`, `recibido` o `cancelado`.
- Un producto pertenece opcionalmente a una categoría.
- Cada movimiento identifica el producto afectado y el usuario responsable.
- Cuando el stock llega al mínimo configurado, se puede generar un pedido sugerido.
- Un pedido puede asociarse con un proveedor, costo, fecha estimada y recepciones parciales.
- `pedido_eventos` conserva el historial de cambios de estado del pedido.
- `pedido_recepciones` relaciona cada recepción con el movimiento de inventario generado.

Fuentes: [migrate.js](../src/db/migrate.js), [upgrade-pedidos.js](../src/db/upgrade-pedidos.js), [pedidos.service.js](../src/services/pedidos.service.js) y las rutas de compras.
