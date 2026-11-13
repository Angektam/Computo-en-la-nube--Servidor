# Anexo — Calculadora de precios AWS

**Sistema:** Inventario Nube · **Región:** `us-east-1` (US East — N. Virginia)  
**Fuente:** [AWS Pricing Calculator](https://calculator.aws/#/estimate) · precios On-Demand, sin Free Tier ni créditos.

## Captura de la calculadora/proveedor

La captura de la consola AWS utilizada como evidencia está en [captura-costos.png](../../practica13/captura-costos.png). La calculadora oficial para reproducir el presupuesto es [calculator.aws](https://calculator.aws/#/estimate).

> La captura de Cost Explorer sirve como evidencia de la cuenta y del módulo de costos; el importe de la estimación se documenta abajo con los mismos parámetros de AWS Pricing Calculator.

## Supuestos de uso

| Variable | Escenario actual | Escenario ×3 | Criterio |
|---|---:|---:|---|
| Usuarios activos | 50 | 150 | Se triplica la base de usuarios |
| EC2 `t3.micro` | 730 h/mes | 730 h/mes | Servidor encendido 24/7; capacidad fija |
| Disco EBS gp3 | 20 GB | 20 GB | Sistema operativo, aplicación y logs |
| RDS `db.t3.micro` PostgreSQL | 730 h/mes | 730 h/mes | Single-AZ, encendido 24/7 |
| Almacenamiento RDS gp2 | 20 GB | 20 GB | Base de datos e historial |
| S3 Standard | 5 GB | 15 GB | Sitio, imágenes y archivos; escala ×3 |
| S3 Standard-IA | 2 GB | 6 GB | Objetos con lifecycle después de 30 días |
| Solicitudes S3 | 1,000 PUT + 10,000 GET/mes | 3,000 PUT + 30,000 GET/mes | Escala con la actividad |
| DynamoDB | 30,000 writes + 150,000 reads/mes | 90,000 writes + 450,000 reads/mes | Modo bajo demanda |
| Lambda | 1,000 invocaciones/mes | 3,000 invocaciones/mes | 128 MB, 200 ms promedio |
| API Gateway HTTP API | 1,000 requests/mes | 3,000 requests/mes | Escala con las solicitudes |
| Transferencia saliente | 10 GB/mes | 30 GB/mes | Respuestas, imágenes y descargas |
| NAT Gateway | No incluido | No incluido | Se descartó por costo |

## Costo mensual por servicio

| Servicio | Actual (USD/mes) | ×3 usuarios (USD/mes) | Tratamiento |
|---|---:|---:|---|
| EC2 `t3.micro` + EBS | 9.59 | 9.59 | Fijo: 730 h y 20 GB |
| RDS `db.t3.micro` + almacenamiento | 23.58 | 23.58 | Fijo: 730 h y 20 GB |
| S3 Standard + Standard-IA + requests | 0.14 | 0.42 | Variable, ×3 |
| DynamoDB on-demand | 0.07 | 0.21 | Variable, ×3 |
| Lambda | 0.00 | 0.00 | Variable; volumen pequeño |
| API Gateway | 0.00 | 0.00 | Variable; volumen pequeño |
| Data Transfer Out | 0.90 | 2.70 | Variable, ×3 |
| VPC, subredes, SG, IGW e IAM | 0.00 | 0.00 | Sin cargo directo en este uso |
| **Total mensual estimado** | **34.29** | **36.59** | **USD/mes** |

## Lectura del escenario de crecimiento

El costo no se triplica porque EC2 y RDS son componentes fijos mientras permanecen en el mismo tamaño y encendidos 24/7. Al triplicar usuarios se escalan los componentes variables —almacenamiento S3, solicitudes, lecturas/escrituras, invocaciones y transferencia—, por lo que el estimado pasa de **34.29 USD/mes** a **36.59 USD/mes**.

Los importes son estimaciones: AWS Pricing Calculator no incluye impuestos y el cobro real depende del uso efectivo y de la tarifa vigente.
