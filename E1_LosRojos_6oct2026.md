# E1 — ANTEPROYECTO DEL PROYECTO INTEGRADOR

---

## 1. PORTADA

|||
|---|---|
| **Institución** | Universidad Autónoma de Sinaloa · Facultad de Ingeniería Mochis |
| **Programa** | Ingeniería de Software |
| **Asignatura** | Cómputo en la Nube |
| **Docente** | Elizabeth Gaxiola Carrillo |
| **Nombre del proyecto** | Sistema de Gestión de Inventarios en la Nube |
| **Nombre del equipo** | Los Rojos |
| **Integrantes** | López Payán Kevin Ricardo · Flores Guevara Ángel Gabriel |
| **Repositorio** | https://github.com/[USUARIO]/inventario-nube *(privado; docente agregada como colaboradora)* |
| **Fecha** | Los Mochis, Sinaloa, México, 06 de octubre de 2026 |

---

## 2. ÍNDICE

| Apartado | Página |
|---|---|
| 3. Planteamiento del problema | 3 |
| 4. Justificación | 3 |
| 5. Objetivos | 4 |
| 6. Alcance y limitaciones | 5 |
| 7. Usuarios | 6 |
| 8. Requerimientos | 6 |
| 9. Cronograma | 8 |
| 10. Matriz de roles | 8 |
| 11. Referencias | 9 |
| 12. Declaración de uso de asistentes | 9 |

---

## 3. PLANTEAMIENTO DEL PROBLEMA

La organización de referencia es una miscelánea familiar con tres empleados ubicada en el municipio de Ahome, Sinaloa, cuya razón social no se divulga por acuerdo de confidencialidad. El negocio opera con un único punto de venta y bodega central; su giro es la venta al menudeo de abarrotes, artículos de limpieza y botanas.

En entrevista realizada con la propietaria el 15 de septiembre de 2026, se identificaron las siguientes situaciones concretas:

- **Tiempo de registro manual:** el encargado de bodega destina aproximadamente 45 minutos diarios a actualizar el cuaderno físico de entradas y salidas, tiempo que podría destinarse a atención al cliente o a otras actividades operativas.
- **Discrepancias frecuentes:** en promedio se detectan entre tres y cinco diferencias semanales entre el inventario físico y el registrado en la libreta, las cuales se descubren únicamente durante el conteo físico semanal.
- **Falta de consulta remota:** la propietaria no puede conocer las existencias sin desplazarse al local o llamar a un empleado; no existe acceso a los registros fuera del establecimiento.
- **Desabasto no anticipado:** en al menos dos ocasiones durante el semestre previo a la entrevista, la empresa perdió ventas por agotamiento de productos de alta rotación que no fueron detectados a tiempo para generar una orden de compra oportuna.

Según el Instituto Nacional de Estadística y Geografía (INEGI, 2021), el 95.4 % de las unidades económicas en México son microempresas; de ellas, la mayoría no cuenta con herramientas digitales integradas para la gestión operativa. La consecuencia para la organización descrita es una toma de decisiones de compra reactiva que incrementa el riesgo de sobreinventario —capital inmovilizado— o de desabasto con pérdida directa de venta.

---

## 4. JUSTIFICACIÓN

### Razón de negocio

La implementación de un sistema de información orientado a la operación permite reducir el tiempo de registro, eliminar las discrepancias manuales y consultar el inventario en tiempo real desde cualquier dispositivo con acceso a internet. Laudon y Laudon (2022) señalan que los sistemas de procesamiento de transacciones generan ventajas medibles en ciclos de abastecimiento y reducción de mermas cuando sustituyen registros manuales en negocios de bajo volumen.

Desde la perspectiva de costos, el modelo de pago por uso de los servicios en la nube elimina la inversión inicial en hardware de servidor y licencias; los servicios utilizados en este proyecto (EC2 t3.micro, RDS db.t3.micro, S3 estándar) están cubiertos por el nivel gratuito de AWS durante los primeros 12 meses o por los créditos educativos de AWS Academy, por lo que el costo de operación durante el semestre es cercano a cero.

### Razón técnica

Una solución desplegada en la nube ofrece capacidades que no son alcanzables con un servidor local en el presupuesto de una microempresa:

1. **Alta disponibilidad:** Amazon EC2 y RDS cuentan con acuerdos de nivel de servicio (SLA) del 99.99 % y 99.95 %, respectivamente (Amazon Web Services, 2024a; Amazon Web Services, 2024b), niveles que no son viables con hardware de bajo costo adquirido y administrado por el propio negocio.
2. **Seguridad gestionada:** Amazon RDS incluye cifrado en reposo con AES-256, cifrado en tránsito mediante TLS y aplicación automática de parches de seguridad del motor de base de datos (Amazon Web Services, 2024b). Estas responsabilidades recaerían en el equipo de IT del negocio si se optara por una solución local, lo cual es inviable para una microempresa sin personal técnico dedicado.
3. **Escalabilidad sin inversión adicional:** el tamaño de la instancia de cómputo o de base de datos puede modificarse en minutos mediante la consola de AWS, sin adquirir hardware adicional ni interrumpir el servicio de forma prolongada.

---

## 5. OBJETIVOS

### Objetivo general

Desarrollar e implementar un sistema web de gestión de inventarios desplegado en Amazon Web Services, que permita a pequeñas empresas de comercio minorista registrar movimientos de stock, consultar existencias en tiempo real y recibir alertas automáticas de reabastecimiento, reduciendo el tiempo de registro manual y las discrepancias de inventario comprobables al 14 de diciembre de 2026.

### Objetivos específicos

- **OE-01.** Implementar una API REST con autenticación basada en JSON Web Token y control de acceso por tres roles (administrador, bodega, cajero), desplegada en una instancia EC2, y demostrar que los endpoints protegidos devuelven HTTP 403 ante solicitudes sin token o con rol insuficiente, antes del 11 de noviembre de 2026.
- **OE-02.** Configurar una instancia de Amazon RDS con PostgreSQL con cifrado en tránsito habilitado (SSL), política de respaldos automáticos de siete días y al menos cuatro tablas relacionadas (usuarios, productos, movimientos, pedidos), y demostrar la conexión exitosa desde la API, antes del 11 de noviembre de 2026.
- **OE-03.** Construir el módulo de alertas que genere automáticamente un registro en la tabla de pedidos cuando el stock de un producto descienda al valor del stock mínimo configurado, demostrable mediante la ejecución del endpoint `POST /api/movimientos` en la exposición del 14 de diciembre de 2026.
- **OE-04.** Publicar los reportes de faltantes, sobrantes y corte diario accesibles vía API REST, verificables mediante consulta directa al endpoint `/api/reportes` durante la exposición del 14 de diciembre de 2026.
- **OE-05.** Alojar los archivos estáticos del frontend en un bucket de Amazon S3 con acceso público controlado mediante política de bucket, y demostrar que el sitio es accesible desde un navegador mediante su URL de sitio web estático, antes del 14 de diciembre de 2026.

---

## 6. ALCANCE Y LIMITACIONES

### Lo que SÍ se construirá este semestre

| ID | Componente | Descripción |
|---|---|---|
| A-01 | Módulo de productos | Alta, modificación y baja lógica con campos: nombre, categoría, unidad, precio unitario, stock actual, stock mínimo e imagen opcional. |
| A-02 | Módulo de movimientos | Registro de entradas, salidas y ajustes con fecha, responsable, cantidad y concepto. |
| A-03 | Módulo de reportes | Reporte de faltantes, sobrantes, historial de gastos acumulados y corte diario. |
| A-04 | Módulo de alertas y pedidos | Generación automática de un registro de pedido sugerido al detectar stock igual o menor al mínimo configurado. |
| A-05 | Autenticación y roles | Login con JWT con vigencia de ocho horas; tres roles con permisos diferenciados por endpoint. |
| A-06 | Infraestructura AWS | EC2 t3.micro (API), RDS db.t3.micro PostgreSQL (datos), S3 estándar (archivos e imágenes), VPC con subred pública y privada, grupos de seguridad diferenciados por componente. |
| A-07 | Frontend estático | Interfaz de una sola página (SPA) en HTML, CSS y JavaScript, servida desde S3. |

### Lo que queda FUERA de este semestre

| ID | Exclusión | Motivo |
|---|---|---|
| L-01 | Facturación electrónica (CFDI) | Requiere integración con un proveedor autorizado de certificación (PAC), fuera del alcance de la materia. |
| L-02 | Pasarelas de pago | Implica cumplimiento PCI-DSS, que supera el alcance semestral. |
| L-03 | Múltiples puntos de venta | Incrementa la complejidad de sincronización; el sistema se limita a un almacén central. |
| L-04 | Aplicación móvil nativa | El frontend es web responsivo; no se desarrolla una aplicación iOS ni Android. |
| L-05 | Integración con ERP externo | No se contemplan conectores hacia sistemas como SAP u Odoo. |

### Limitaciones reales del semestre

- **Tiempo:** el ciclo escolar concluye el 14 de diciembre de 2026; todas las funcionalidades deben ser demostrables en esa fecha.
- **Créditos de cuenta AWS:** se trabaja con créditos del programa AWS Academy; no se utilizarán servicios de costo continuo elevado (p. ej., NAT Gateway activo de forma permanente, instancias mayores a t3.micro).
- **Datos:** los datos de prueba son ficticios. El sistema no procesará información personal ni financiera real de clientes durante el desarrollo.

---

## 7. USUARIOS

### Perfil 1 — Administrador / Propietario

**Descripción:** titular o encargado general del negocio con acceso completo al sistema.

**Actividades:** gestionar el catálogo de productos y categorías, administrar cuentas de usuario y roles, revisar reportes de inventario y gastos acumulados, consultar y aprobar pedidos de reabastecimiento sugeridos.

**Qué espera obtener:** visibilidad completa del estado del inventario en tiempo real desde cualquier dispositivo conectado a internet, sin necesidad de desplazarse físicamente al local ni depender de llamadas telefónicas a los empleados.

---

### Perfil 2 — Encargado / Auxiliar de Bodega

**Descripción:** empleado responsable del almacén que registra la entrada y salida de mercancía.

**Actividades:** registrar entradas de proveedor y salidas de almacén, registrar ajustes por merma o conteo, consultar el stock actual de cualquier producto, revisar la lista de alertas de stock bajo.

**Qué espera obtener:** un formulario ágil que reemplace el cuaderno físico, reduzca el tiempo de captura y le notifique automáticamente cuando un producto esté próximo a agotarse.

---

### Perfil 3 — Cajero / Vendedor

**Descripción:** empleado de punto de venta con permisos de solo lectura sobre el inventario.

**Actividades:** consultar la disponibilidad de un producto antes de confirmar una venta al cliente.

**Qué espera obtener:** acceso rápido a las existencias actuales sin posibilidad de modificar datos del inventario de forma accidental.

---

## 8. REQUERIMIENTOS

### Requerimientos funcionales

| ID | Descripción |
|---|---|
| RF-01 | El sistema permitirá al administrador crear un producto con los campos obligatorios: nombre, categoría, unidad de medida, precio unitario, stock inicial y stock mínimo. |
| RF-02 | El sistema permitirá al administrador editar cualquier campo de un producto existente y registrar su baja de forma lógica (sin eliminar el historial). |
| RF-03 | El sistema permitirá al encargado de bodega registrar un movimiento de tipo entrada, salida o ajuste, asociado a un producto, con los campos: fecha, cantidad, concepto y responsable. |
| RF-04 | El sistema actualizará el stock actual del producto de forma automática cada vez que se registre un movimiento asociado a él. |
| RF-05 | El sistema generará un registro de pedido sugerido en la tabla de pedidos cuando el stock de un producto sea igual o menor al stock mínimo configurado, sin intervención manual del usuario. |
| RF-06 | El sistema expondrá un reporte de faltantes que liste todos los productos cuyo stock actual sea menor al stock mínimo configurado. |
| RF-07 | El sistema expondrá un reporte de sobrantes que liste los productos cuyo stock actual supere en más del doble su stock mínimo. |
| RF-08 | El sistema generará un corte diario que muestre el total de entradas, salidas y ajustes del día en curso. |
| RF-09 | El sistema autenticará a los usuarios mediante correo electrónico y contraseña, devolviendo un token JWT con vigencia de ocho horas. |
| RF-10 | El sistema controlará el acceso a cada endpoint según el rol del usuario autenticado, rechazando solicitudes no autorizadas con el código HTTP 403. |
| RF-11 | El sistema permitirá al administrador crear, editar el rol y desactivar cuentas de usuario. |
| RF-12 | El sistema permitirá adjuntar una imagen a cada producto; el archivo se almacenará en Amazon S3 y el sistema proporcionará una URL de acceso al cliente. |
| RF-13 | El sistema expondrá un endpoint `/health` que informe el estado de la conexión a la base de datos y al servicio de almacenamiento. |

### Requerimientos no funcionales

| ID | Descripción |
|---|---|
| RNF-01 | El tiempo de respuesta de los endpoints de listado y registro no excederá 500 ms bajo condiciones de hasta diez usuarios concurrentes, medido con la herramienta curl o Postman. |
| RNF-02 | Toda comunicación entre el cliente y el servidor utilizará HTTPS con TLS 1.2 o superior; las solicitudes HTTP sin cifrar serán redirigidas automáticamente. |
| RNF-03 | La base de datos contará con respaldos automáticos diarios con período de retención de siete días, gestionados por Amazon RDS. |
| RNF-04 | Las contraseñas de los usuarios se almacenarán como hash irreversible con bcrypt y factor de costo mínimo de 10; no se almacenará la contraseña en texto plano en ningún registro. |
| RNF-05 | Ninguna credencial (contraseña, clave de acceso AWS, cadena de conexión a base de datos) se versionará en el repositorio; se usarán variables de entorno declaradas en un archivo `.env` excluido mediante `.gitignore`. |
| RNF-06 | El sistema registrará en bitácora cada intento de autenticación fallido, incluyendo marca de tiempo y dirección IP de origen, en el log del servidor. |
| RNF-07 | La interfaz web será funcional en Google Chrome y Mozilla Firefox en sus versiones estables más recientes a la fecha de entrega. |
| RNF-08 | El sistema estará disponible durante los períodos de evaluación del semestre (E2 y E3), con un tiempo de inactividad planificado no mayor a 30 minutos para mantenimiento, notificado con al menos dos horas de anticipación al docente. |

---

## 9. CRONOGRAMA

| Semana | Período | Actividad | Responsable | Hito |
|---|---|---|---|---|
| 1 | 06 oct – 12 oct | Configuración del repositorio, bitácora del equipo, instancia EC2 y RDS en AWS; despliegue inicial de la API base. | Flores Guevara | — |
| 2 | 13 oct – 19 oct | Implementación del módulo de productos: CRUD completo con control de roles. | Flores Guevara | — |
| 3 | 20 oct – 26 oct | Implementación del módulo de movimientos con actualización automática de stock. | Flores Guevara | — |
| 4 | 27 oct – 02 nov | Implementación del módulo de alertas y generación de pedidos sugeridos. | Flores Guevara | — |
| 5 | 03 nov – 09 nov | Pruebas de integración de los módulos anteriores; corrección de defectos. Redacción del E2. | Flores Guevara / López Payán | — |
| 6 | 10 nov – 11 nov | Entrega del E2: arquitectura, diagrama de red, decisiones de diseño. | López Payán | **E2 — 11 nov 2026** |
| 7 | 12 nov – 22 nov | Implementación de los reportes de faltantes, sobrantes y corte diario. | Flores Guevara | — |
| 8 | 23 nov – 29 nov | Configuración del sitio estático en S3, HTTPS en EC2; pruebas de acceso externo. | Flores Guevara / López Payán | — |
| 9 | 30 nov – 06 dic | Pruebas funcionales completas contra la rúbrica del E3; corrección de incidencias. | Ambos | — |
| 10 | 07 dic – 13 dic | Redacción del documento final E3, capturas de evidencia y preparación de la demostración. | López Payán | — |
| 11 | 14 dic | Entrega y exposición final del proyecto integrador. | Ambos | **E3 — 14 dic 2026** |

---

## 10. MATRIZ DE ROLES

| Integrante | Rol en el proyecto | Responsabilidades concretas | Usuario en el repositorio |
|---|---|---|---|
| **López Payán Kevin Ricardo** | Responsable de Documentación y Arquitectura | Redactar y actualizar los documentos E1, E2 y E3. Diseñar y mantener el diagrama de arquitectura en la nube. Definir el modelo de datos y los requerimientos. Gestionar el tablero de issues y el registro de la bitácora del equipo. Revisar y aprobar los pull requests de infraestructura. | `@[USUARIO_KEVIN]` |
| **Flores Guevara Ángel Gabriel** | Responsable de Desarrollo y Seguridad | Implementar la API REST en Node.js y Express. Configurar y administrar los servicios AWS (EC2, RDS, S3, VPC, grupos de seguridad). Aplicar las políticas de seguridad (JWT, bcrypt, HTTPS). Ejecutar las pruebas funcionales y corregir los defectos reportados. Mantener actualizado el `.env.example` y la guía de despliegue. | `@angek` |

---

## 11. REFERENCIAS

Amazon Web Services. (2024a). *Amazon EC2 Service Level Agreement*. https://aws.amazon.com/ec2/sla/

Amazon Web Services. (2024b). *Amazon RDS features: Security*. https://aws.amazon.com/rds/features/security/

Instituto Nacional de Estadística y Geografía. (2021). *Censos Económicos 2019: Resultados definitivos*. INEGI. https://www.inegi.org.mx/programas/ce/2019/

Laudon, K. C., y Laudon, J. P. (2022). *Management information systems: Managing the digital firm* (17.ª ed.). Pearson.

---

## 12. DECLARACIÓN DE USO DE ASISTENTES DE INTELIGENCIA ARTIFICIAL

| Herramienta | Apartados en los que se utilizó | Uso específico |
|---|---|---|
| **Kiro (Amazon)** — asistente integrado en el IDE | §3 Planteamiento del problema, §4 Justificación, §5 Objetivos, §8 Requerimientos, §9 Cronograma | Generación del borrador estructurado del documento a partir del README del proyecto y la documentación técnica existente. El equipo revisó, corrigió y validó cada sección antes de la entrega; los datos cuantitativos del planteamiento provienen de la entrevista realizada por el equipo. |
| **GitHub Copilot** | Ninguno en este documento | Se utiliza en sesiones de codificación del proyecto; no participó en la redacción del anteproyecto. |

El contenido sustantivo —identificación del problema, justificación, objetivos, requerimientos, cronograma y roles— fue revisado y aprobado íntegramente por los integrantes del equipo. Los asistentes se utilizaron como herramientas de apoyo para la estructuración y redacción inicial; no sustituyeron el juicio técnico ni la verificación de los datos por parte del equipo.
