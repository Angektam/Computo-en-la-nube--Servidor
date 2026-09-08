# Documento de Requisitos

## Introducción

Este documento describe los requisitos para un sistema web compuesto por un servidor web hospedado en una máquina virtual, almacenamiento de archivos en la nube y una base de datos gestionada en la nube. El objetivo es proporcionar una plataforma confiable, escalable y segura que sirva contenido y datos a los usuarios finales, aprovechando servicios cloud para el almacenamiento persistente y la gestión de datos.

---

## Glosario

- **Servidor_Web**: Instancia de máquina virtual que ejecuta el servidor HTTP/HTTPS y aloja la aplicación.
- **Almacenamiento_Cloud**: Servicio de almacenamiento de objetos en la nube (por ejemplo, Amazon S3, Azure Blob Storage o Google Cloud Storage) utilizado para guardar archivos, activos estáticos y otros recursos binarios.
- **Base_de_Datos_Cloud**: Servicio de base de datos gestionado en la nube (por ejemplo, Amazon RDS, Azure Database o Cloud SQL) responsable del almacenamiento y recuperación de datos estructurados.
- **Cliente**: Navegador web u otra aplicación que realiza peticiones al Servidor_Web.
- **Administrador**: Persona responsable de configurar, desplegar y mantener el sistema.
- **Credenciales**: Información de autenticación (claves de acceso, tokens, contraseñas) necesaria para conectarse a los servicios cloud.
- **Petición**: Mensaje HTTP/HTTPS enviado por el Cliente al Servidor_Web.
- **Respuesta**: Mensaje HTTP/HTTPS devuelto por el Servidor_Web al Cliente.
- **Archivo**: Recurso binario o de texto almacenado en el Almacenamiento_Cloud.
- **Registro**: Entrada de datos estructurados almacenada en la Base_de_Datos_Cloud.

---

## Requisitos

### Requisito 1: Servicio del Servidor Web

**Historia de Usuario:** Como Cliente, quiero acceder a la aplicación a través de un servidor web estable, para poder consumir los servicios y recursos del sistema.

#### Criterios de Aceptación

1. THE Servidor_Web SHALL escuchar peticiones entrantes en los puertos 80 (HTTP) y 443 (HTTPS).
2. WHEN el Cliente envía una Petición HTTP válida, THE Servidor_Web SHALL devolver una Respuesta con código de estado en el rango 2xx, 3xx, 4xx o 5xx según corresponda a la naturaleza de la petición, en un tiempo máximo de 2000 ms.
3. WHEN el Cliente envía una Petición HTTP en el puerto 80, THE Servidor_Web SHALL redirigir la petición al puerto 443 mediante una Respuesta con código de estado 301.
4. IF el Servidor_Web recibe una Petición con un recurso no encontrado, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 404 y un mensaje que identifique el tipo de error y la ruta del recurso afectado.
5. IF el Servidor_Web recibe una Petición malformada, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 400 y un mensaje que identifique el tipo de error y la ruta del recurso afectado.
6. WHILE el Servidor_Web está en funcionamiento, THE Servidor_Web SHALL registrar todas las Peticiones y Respuestas en un log de acceso local con marca de tiempo, método HTTP, ruta, código de estado y duración de la petición.
7. IF el Servidor_Web experimenta una excepción no manejada, THEN THE Servidor_Web SHALL registrar el error con su traza completa y devolver una Respuesta con código de estado 500 sin exponer detalles internos al Cliente.

---

### Requisito 2: Almacenamiento de Archivos en la Nube

**Historia de Usuario:** Como Servidor_Web, quiero almacenar y recuperar archivos en el Almacenamiento_Cloud, para poder gestionar activos estáticos y recursos binarios de forma escalable.

#### Criterios de Aceptación

1. WHEN el Servidor_Web recibe una solicitud de subida de Archivo con tamaño ≤ 10 MB y tipo MIME declarado, THE Servidor_Web SHALL subir el Archivo al Almacenamiento_Cloud y devolver al Cliente la URL de acceso al Archivo en un tiempo máximo de 5000 ms.
2. WHEN el Servidor_Web recibe una solicitud de subida de Archivo con tamaño > 10 MB y ≤ 100 MB y tipo MIME declarado, THE Servidor_Web SHALL subir el Archivo al Almacenamiento_Cloud y devolver al Cliente la URL de acceso al Archivo en un tiempo máximo de 30000 ms.
3. WHEN el Cliente solicita la descarga de un Archivo existente, THE Servidor_Web SHALL recuperar el Archivo desde el Almacenamiento_Cloud y devolverlo al Cliente en un tiempo máximo de 5000 ms con la cabecera `Content-Type` establecida al tipo MIME registrado durante la subida.
4. IF el Archivo solicitado no existe en el Almacenamiento_Cloud, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 404 y un mensaje de error descriptivo.
5. IF la conexión con el Almacenamiento_Cloud falla durante una operación de subida o descarga, THEN THE Servidor_Web SHALL registrar el error, reintentar la operación hasta 3 veces con intervalos de 1 segundo, y devolver una Respuesta con código de estado 503 si todos los reintentos fallan.
6. THE Servidor_Web SHALL autenticarse en el Almacenamiento_Cloud utilizando Credenciales almacenadas en variables de entorno, sin incluirlas en el código fuente ni en los logs.
7. WHEN se sube un Archivo, THE Servidor_Web SHALL validar que el tamaño del Archivo no supere 100 MB antes de iniciar la subida.
8. IF el tamaño del Archivo supera 100 MB, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 413 y un mensaje de error descriptivo, sin iniciar la subida.
9. THE Almacenamiento_Cloud SHALL almacenar los Archivos con cifrado en reposo habilitado.

---

### Requisito 3: Gestión de Datos en la Base de Datos Cloud

**Historia de Usuario:** Como Servidor_Web, quiero leer y escribir Registros en la Base_de_Datos_Cloud, para poder persistir y recuperar datos estructurados de la aplicación.

#### Criterios de Aceptación

1. WHEN el Servidor_Web necesita crear un Registro, THE Servidor_Web SHALL insertar el Registro en la Base_de_Datos_Cloud y devolver al Cliente una Respuesta con código de estado 201 e incluir el identificador del Registro creado, en un tiempo máximo de 1000 ms.
2. WHEN el Servidor_Web necesita recuperar un Registro existente, THE Servidor_Web SHALL consultar la Base_de_Datos_Cloud y devolver al Cliente una Respuesta con código de estado 200 y el cuerpo del Registro, en un tiempo máximo de 1000 ms.
3. WHEN el Servidor_Web necesita actualizar un Registro existente, THE Servidor_Web SHALL modificar el Registro en la Base_de_Datos_Cloud y devolver al Cliente una Respuesta con código de estado 200 e incluir el identificador del Registro actualizado, en un tiempo máximo de 1000 ms.
4. WHEN el Servidor_Web necesita eliminar un Registro existente, THE Servidor_Web SHALL borrar el Registro de la Base_de_Datos_Cloud y devolver al Cliente una Respuesta con código de estado 204, en un tiempo máximo de 1000 ms.
5. IF un Registro solicitado no existe en la Base_de_Datos_Cloud, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 404 y un mensaje que identifique el tipo de error y el identificador del Registro buscado.
6. IF se intenta actualizar o eliminar un Registro que no existe en la Base_de_Datos_Cloud, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 404 y un mensaje que identifique el tipo de error y el identificador del Registro afectado.
7. IF la conexión con la Base_de_Datos_Cloud falla, THEN THE Servidor_Web SHALL registrar el error y devolver una Respuesta con código de estado 503 sin exponer detalles de la infraestructura al Cliente.
8. THE Servidor_Web SHALL autenticarse en la Base_de_Datos_Cloud utilizando Credenciales almacenadas en variables de entorno, sin incluirlas en el código fuente ni en los logs.
9. IF el Servidor_Web intenta conectarse a la Base_de_Datos_Cloud con Credenciales ausentes o inválidas, THEN THE Servidor_Web SHALL registrar el intento fallido y devolver una Respuesta con código de estado 500, sin exponer las Credenciales en el mensaje de error.
10. WHEN el Servidor_Web responde al endpoint `/health`, THE Servidor_Web SHALL incluir en el cuerpo JSON un campo `database_backup_status` con valor `"ok"` si el último backup automático se completó dentro de las últimas 25 horas, o `"error"` en caso contrario.

---

### Requisito 4: Seguridad y Control de Acceso

**Historia de Usuario:** Como Administrador, quiero que el sistema proteja los datos y servicios ante accesos no autorizados, para garantizar la seguridad e integridad de la información.

#### Criterios de Aceptación

1. THE Servidor_Web SHALL aceptar únicamente conexiones HTTPS con TLS 1.2 o superior; IF el Cliente intenta conectarse por HTTP (puerto 80), THEN THE Servidor_Web SHALL redirigir la conexión a la URL HTTPS equivalente con código de estado 301 o rechazar la conexión si la redirección no es aplicable.
2. WHEN el Cliente envía una Petición a un recurso protegido sin Credenciales válidas, THE Servidor_Web SHALL devolver una Respuesta con código de estado 401 y un mensaje que indique la razón específica del rechazo (credenciales ausentes o inválidas).
3. WHEN el Cliente envía una Petición a un recurso para el cual no tiene permisos, THE Servidor_Web SHALL devolver una Respuesta con código de estado 403 y un mensaje que indique la razón específica del rechazo (permisos insuficientes para el recurso solicitado).
4. IF el Servidor_Web recibe una Petición con cabeceras que superen 8 KB de tamaño total, THEN THE Servidor_Web SHALL rechazar la Petición devolviendo una Respuesta con código de estado 431.
5. THE Base_de_Datos_Cloud SHALL aceptar únicamente conexiones originadas desde la dirección IP del Servidor_Web.
6. THE Almacenamiento_Cloud SHALL denegar el acceso público directo a los Archivos; los Archivos solo serán accesibles a través del Servidor_Web o mediante URLs prefirmadas con tiempo de expiración máximo de 1 hora.

---

### Requisito 5: Disponibilidad y Recuperación ante Fallos

**Historia de Usuario:** Como Administrador, quiero que el sistema sea resiliente y recuperable ante fallos, para minimizar el tiempo de inactividad y la pérdida de datos.

#### Criterios de Aceptación

1. WHEN el Cliente envía una Petición al endpoint `/health`, THE Servidor_Web SHALL devolver una Respuesta con código de estado 200 en un tiempo máximo de 1000 ms y un cuerpo JSON con los campos `storage_status` y `database_status`, cuyos valores serán `"ok"` o `"error"` según la conectividad actual con el Almacenamiento_Cloud y la Base_de_Datos_Cloud respectivamente.
2. IF el Servidor_Web detecta 3 fallos de conexión consecutivos a la Base_de_Datos_Cloud en un intervalo de 30 segundos, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 503 en las peticiones que requieran datos y SHALL establecer el campo `database_status` en `"error"` en el endpoint `/health`.
3. IF el Servidor_Web detecta 3 fallos de conexión consecutivos al Almacenamiento_Cloud en un intervalo de 30 segundos, THEN THE Servidor_Web SHALL devolver una Respuesta con código de estado 503 en las peticiones que requieran archivos y SHALL establecer el campo `storage_status` en `"error"` en el endpoint `/health`.
4. THE Base_de_Datos_Cloud SHALL operar con replicación de datos que garantice un objetivo de punto de recuperación (RPO) máximo de 24 horas y un objetivo de tiempo de recuperación (RTO) máximo de 4 horas.
5. WHEN el Administrador solicita la restauración de la Base_de_Datos_Cloud a un punto anterior dentro de los últimos 7 días, THE Base_de_Datos_Cloud SHALL completar la restauración en un tiempo máximo de 60 minutos y el Servidor_Web SHALL reportar `database_status: "ok"` en el endpoint `/health` una vez completada la restauración.
