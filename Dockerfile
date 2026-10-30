# ═══════════════════════════════════════════════════════════════════════
#  Dockerfile — inventario-nube · Equipo Los Rojos
#  Práctica 10 · Cómputo en la Nube · UAS · Octubre 2026
# ═══════════════════════════════════════════════════════════════════════

# ── Etapa 1: imagen base ────────────────────────────────────────────────
# Usamos la variante "alpine" de Node 20 LTS porque:
#   • Alpine Linux pesa ~5 MB frente a los ~900 MB de la imagen Debian completa.
#   • Node 20 es la versión LTS activa (soporte hasta abril 2026).
#   • La etiqueta "alpine" es imagen oficial del Docker Hub, auditada y mantenida.
FROM node:20-alpine

# ── Etapa 2: directorio de trabajo ─────────────────────────────────────
# Todos los comandos siguientes se ejecutan dentro de /app.
# Si el directorio no existe Docker lo crea automáticamente.
WORKDIR /app

# ── Etapa 3: copiar manifiestos de dependencias ─────────────────────────
# Se copian SÓLO package.json y package-lock.json ANTES que el código.
# Motivo del orden: Docker almacena cada instrucción como una capa de
# caché. Si los manifiestos no cambian, la capa de "npm ci" se reutiliza
# aunque el código fuente haya cambiado → construcciones mucho más rápidas.
COPY package.json package-lock.json ./

# ── Etapa 4: instalar dependencias de producción ────────────────────────
# "npm ci" es preferible a "npm install" en CI/CD porque:
#   • Elimina node_modules antes de instalar (reproducibilidad).
#   • Respeta exactamente las versiones del package-lock.json.
# "--omit=dev" excluye devDependencies (nodemon, docx…) que no se necesitan
# en producción, reduciendo el tamaño final de la imagen.
RUN npm ci --omit=dev

# ── Etapa 5: copiar el código fuente y el frontend ──────────────────────
# Ahora sí se copia el resto del proyecto. Al estar después de "npm ci",
# cualquier cambio de código no invalida la caché de dependencias.
COPY src/ ./src/
COPY public/ ./public/

# ── Etapa 6: variables de entorno con valores por defecto seguros ────────
# Solo se declaran variables NO secretas con valores predecibles.
# Los secretos (DB_PASSWORD, JWT_SECRET, AWS_*) se inyectan en tiempo de
# ejecución con "--env" o un archivo ".env" montado, nunca se guardan aquí.
ENV NODE_ENV=production \
    PORT=3000

# ── Etapa 7: documentar el puerto expuesto ─────────────────────────────
# EXPOSE no publica el puerto por sí solo; es documentación para quien
# ejecute la imagen y para herramientas como Docker Compose o ECS.
# La aplicación escucha en process.env.PORT (3000 por defecto).
EXPOSE 3000

# ── Etapa 8: usuario sin privilegios ───────────────────────────────────
# Alpine incluye el usuario "node" (uid 1000). Ejecutar como root dentro
# del contenedor es un riesgo de seguridad; cambiamos al usuario sin
# privilegios para reducir la superficie de ataque.
USER node

# ── Etapa 9: comando de inicio ─────────────────────────────────────────
# Se usa la forma EXEC (array JSON) en lugar de la forma shell para que
# el proceso Node.js reciba señales del sistema operativo (SIGTERM, SIGINT)
# directamente — lo que permite un apagado limpio del contenedor.
# "npm run start" correría un proceso intermedio de shell; "node" directo
# es más eficiente y maneja señales correctamente.
CMD ["node", "src/server.js"]
