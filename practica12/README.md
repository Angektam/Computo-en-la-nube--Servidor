# Práctica 12 — Infraestructura como código

Equipo Los Rojos · AWS CloudShell · región us-east-1

## Alcance

Se declara un bucket S3 mediante AWS CloudFormation, con cifrado AES256, versionado, bloqueo de acceso público y etiquetas del proyecto. El recurso queda definido en [p12-template.yaml](./p12-template.yaml) y también en [infra/p12-template.yaml](../infra/p12-template.yaml).

## Evidencia real

Las imágenes generadas con texto no deben entregarse como capturas. La evidencia corregida se obtiene ejecutando [evidencia-real-p12.sh](./evidencia-real-p12.sh) desde AWS CloudShell:

    cd practica12
    bash evidencia-real-p12.sh

El script muestra datos reales de la cuenta, ARN, región, hora UTC, stack, bucket, estado, configuración de S3, aplicación idempotente y tiempos de destrucción/recreación. Cada bloque debe capturarse directamente desde CloudShell.

Además, abrir S3 en la consola, entrar al bucket indicado por la salida “Bucket real” y tomar una captura de la pantalla de propiedades. La captura debe conservar el encabezado de AWS donde se identifiquen cuenta, región y hora.

## Capturas que deben incluirse

1. Previsualización del change set y el parámetro Environment.
2. Primera aplicación y segunda aplicación con “No changes to deploy”.
3. Stack en CREATE_COMPLETE y bucket visible en la consola S3.
4. Eliminación y recreación del stack, con tiempos reales.
5. Código de [p12-template.yaml](./p12-template.yaml), [infra/p12-template.yaml](../infra/p12-template.yaml) y [.gitignore](../.gitignore).

No se deben usar paneles dibujados, resultados escritos a mano, nombres de bucket inventados ni tiempos reutilizados de otra ejecución.

## Estado excluido

CloudFormation conserva el estado del stack en AWS. El repositorio contiene la definición declarativa y excluye estados locales, credenciales y archivos sensibles mediante [.gitignore](../.gitignore).
