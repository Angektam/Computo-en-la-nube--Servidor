# Auditoría del sitio en AWS

Sitio: http://alb-inventario-cloud-los-rojos-727813269.us-east-1.elb.amazonaws.com/index-1.html

Ejecución: 6 de noviembre de 2026, 21:21 UTC. Los resultados corresponden a la versión desplegada en ese momento, antes de publicar las correcciones locales.

## Alcance y resultado

- 73 solicitudes HTTP, 74 comprobaciones: 67 aprobadas y 7 fallidas.
- Máximo cinco solicitudes simultáneas. Las 15 consultas concurrentes respondieron 200.
- Latencia desde esta máquina, incluyendo descarga de respuesta: mediana 95 ms, percentil 95 de 409 ms, máximo 427 ms.
- Salud del servidor y conexión a base de datos correctas al inicio y al terminar.
- Se consultaron datos existentes; no se crearon, editaron ni eliminaron productos, usuarios, movimientos ni pedidos.
- No hubo prueba visual de navegador ni una prueba de capacidad máxima. Cinco conexiones simultáneas no permiten estimar cuántos usuarios soporta el sistema.

## Hallazgos

| Comprobación | Resultado en AWS | Comportamiento esperado |
|---|---|---|
| `/api/movimientos?limit=-1` | 500 | Rechazar con 400 o normalizar a un límite positivo |
| `/api/movimientos?desde=no-es-fecha&limit=1` | 500 | 400 con un mensaje de validación |
| `/api/reportes/gastos?desde=no-es-fecha` | 500 | 400 con un mensaje de validación |
| `/api/productos/no-es-numero` | 400 con detalles de PostgreSQL | 400 con un mensaje comprensible, sin detalles SQL |
| Gastos con `desde=2026-11-06&hasta=2026-11-01` | 200 | Rechazar el rango invertido |
| Endpoint API inexistente | 404 con HTML | 404 con JSON coherente con el cliente |
| Login con las credenciales documentadas de Cajero | 401 | Verificar vigencia de esas credenciales; el resultado no demuestra por sí solo un fallo del login |

## Comprobaciones satisfactorias

Administrador y Bodega iniciaron sesión y consultaron productos, categorías, movimientos y los cuatro estados de pedidos. El total de pedidos y sus estados fueron consistentes. Bodega recibió 403 al consultar usuarios y gastos. La respuesta de usuarios de Administrador no incluyó el campo `password`.

Las rutas protegidas rechazaron peticiones sin sesión y tokens manipulados. Las exportaciones de faltantes y movimientos devolvieron CSV. La página, sus scripts y estilos estuvieron disponibles. Las cabeceras CSP y `nosniff` estuvieron presentes.

Las peticiones a `/.env` y `/.git/config` devolvieron la página de respaldo de la aplicación con estado 200; no se detectaron los patrones de configuración privada comprobados. Este resultado no constituye una revisión completa de exposición de secretos.

## Correcciones locales

Se agregaron validaciones de fechas reales, rangos, paginación, filtros numéricos e IDs de producto antes de consultar PostgreSQL. También se agregó una respuesta JSON para rutas API inexistentes. Hay pruebas de regresión para entradas inválidas y consultas válidas.

Las correcciones siguen pendientes de despliegue: las credenciales de AWS disponibles fueron rechazadas previamente con `SignatureDoesNotMatch`. Las pruebas de Cajero en producción requieren credenciales vigentes; no se cambió su contraseña.

El detalle de comprobaciones, sin tokens ni respuestas con datos de negocio, está en `aws-audit.json`. Para repetir la auditoría acotada: `node test-local/audit-live.cjs`. Para ejecutar las pruebas locales: `npm test`.
