# Requirements Document

## Introducción

Este documento registra la configuración inicial de la cuenta AWS del equipo **Los Rojos** para la materia **Cómputo en la Nube** (Facultad de Ingeniería Mochis — Ingeniería de Software). Cubre los pasos 06–11 de la práctica: identidades IAM, esquema de etiquetas, nota de cuenta y restricciones del plan gratuito.

El propósito del spec es servir como bitácora de referencia para todo el semestre y como evidencia de que los pasos de configuración fueron ejecutados correctamente.

---

## Glosario

- **Cuenta_AWS**: Cuenta de AWS Free Tier registrada por el equipo.
- **IAM**: Servicio de AWS para gestión de identidades y accesos.
- **Usuario_IAM**: Identidad individual creada dentro de la Cuenta_AWS.
- **Grupo_IAM**: Colección de usuarios con la misma política de permisos.
- **Etiqueta**: Par clave-valor adjunto a recursos AWS para organización y control de costos.
- **Plan_Gratuito**: Nivel gratuito de AWS (AWS Free Tier) con restricciones documentadas en el Paso 11.
- **Correo_Equipo**: Dirección de correo electrónico compartida del equipo.
- **Responsable_Pago**: Integrante que aportó el medio de pago (tarjeta) para la validación de la cuenta.

---

## Requisitos

### Requisito 1: Tabla de identidades del equipo

**User Story:** Como maestra o evaluador, quiero ver de un vistazo quién es cada integrante, qué usuario IAM tiene asignado, a qué grupo pertenece y qué permisos tiene, para verificar que la configuración sigue el principio de mínimo privilegio.

#### Criterios de Aceptación

1. THE **Documento** SHALL contener una tabla con las columnas: Integrante, Usuario IAM, Grupos IAM y Permisos.
2. WHEN un integrante pertenece a más de un grupo, THE **Documento** SHALL listar todos los grupos separados por coma.
3. THE **Documento** SHALL reflejar exactamente los usuarios y grupos creados por el script `deploy/aws-practica01-setup.sh`.

#### Tabla de Identidades

| Integrante | Usuario IAM | Grupos IAM | Permisos |
|---|---|---|---|
| López Payán Kevin Ricardo | `usr-kevin` | `grp-documentacion`, `grp-arquitectura` | ReadOnlyAccess |
| Flores Guevara Ángel Gabriel | `usr-angel` | `grp-seguridad-costos`, `grp-desarrollo` | AdministratorAccess + ReadOnlyAccess |

> **Nota:** Ambos integrantes deben activar MFA en su propio usuario IAM en el primer inicio de sesión (Paso 06 — manual).

---

### Requisito 2: Esquema de etiquetas acordado

**User Story:** Como integrante del equipo, quiero conocer el valor exacto de cada etiqueta que debo aplicar a los recursos AWS, para garantizar consistencia en costos, auditorías y organización.

#### Criterios de Aceptación

1. THE **Documento** SHALL definir las tres etiquetas obligatorias: `proyecto`, `equipo` y `ambiente`.
2. THE **Documento** SHALL mostrar el valor exacto de cada etiqueta para este proyecto.
3. WHEN se crea cualquier recurso AWS durante el semestre, THE **Equipo** SHALL aplicar las tres etiquetas con los valores definidos en este esquema.
4. THE **Documento** SHALL incluir un ejemplo de uso en AWS CLI y en CloudFormation/SAM.

#### Esquema de Etiquetas

| Clave | Valor |
|---|---|
| `proyecto` | `inventario-cloud` |
| `equipo` | `los-rojos` |
| `ambiente` | `dev` |

**Ejemplo — AWS CLI:**
```bash
--tags Key=proyecto,Value=inventario-cloud \
       Key=equipo,Value=los-rojos \
       Key=ambiente,Value=dev
```

**Ejemplo — CloudFormation / SAM:**
```yaml
Tags:
  proyecto: inventario-cloud
  equipo:   los-rojos
  ambiente: dev
```

---

### Requisito 3: Nota de cuenta del equipo

**User Story:** Como integrante del equipo, quiero tener registrado en un solo lugar el correo del equipo, quién aportó el medio de pago y cuándo vence el plan gratuito, para saber a quién contactar ante cargos inesperados y no perder el acceso a créditos.

#### Criterios de Aceptación

1. THE **Documento** SHALL registrar la dirección de correo electrónico asociada a la Cuenta_AWS.
2. THE **Documento** SHALL identificar al Responsable_Pago y su medio de pago registrado.
3. THE **Documento** SHALL indicar la fecha límite de vigencia del Plan_Gratuito.
4. IF el Plan_Gratuito está próximo a vencer, THEN THE **Equipo** SHALL notificar a todos los integrantes con al menos 15 días de anticipación.

#### Datos de la Cuenta

| Campo | Valor |
|---|---|
| Correo del equipo | `angek234122@gmail.com` |
| Responsable del medio de pago | Flores Guevara Ángel Gabriel |
| Fecha límite del plan gratuito | **⚠️ Completar: anotar la fecha exacta del primer año desde el registro** |

> **⚠️ Acción requerida:** Ingresar a **Consola AWS → Billing → Free Tier** y anotar aquí la fecha de expiración del plan gratuito de 12 meses. El plan comienza el día del registro de la cuenta.

---

### Requisito 4: Restricciones del plan gratuito (Paso 11)

**User Story:** Como integrante del equipo, quiero tener documentadas las tres restricciones del plan gratuito registradas en el Paso 11, para evitar acciones que generen cargos o pierdan los créditos del equipo.

#### Criterios de Aceptación

1. THE **Documento** SHALL listar exactamente las tres restricciones identificadas en el Paso 11 de la práctica.
2. THE **Documento** SHALL describir cada restricción de forma clara y accionable.
3. WHEN un integrante planee usar un servicio de terceros o Reserved Instances, THE **Equipo** SHALL verificar primero que la acción no viola ninguna de las tres restricciones.

#### Restricciones del Plan Gratuito

| # | Restricción | Impacto |
|---|---|---|
| 1 | **No permite Reserved Instances ni Savings Plans** | Usar solo instancias On-Demand; no comprometerse a planes de largo plazo. |
| 2 | **No da acceso al AWS Marketplace de soluciones de terceros** | Las soluciones de terceros del Marketplace no están disponibles en el plan gratuito. |
| 3 | **Unirse a una AWS Organization cancela los créditos de inmediato** | El equipo NO debe aceptar invitaciones a Organizations mientras conserve créditos. |

---

## Referencias

- Script de configuración: [`deploy/aws-practica01-setup.sh`](../../deploy/aws-practica01-setup.sh)
- README del proyecto: [`README.md`](../../README.md)
- Comandos de referencia: [`COMANDOS.md`](../../COMANDOS.md)
- Consola AWS Billing: https://console.aws.amazon.com/billing/home
