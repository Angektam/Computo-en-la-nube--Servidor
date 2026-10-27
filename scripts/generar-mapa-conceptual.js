const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, BorderStyle, ShadingType, AlignmentType, HeadingLevel,
  VerticalAlign, convertInchesToTwip
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── Colores ──────────────────────────────────────────────────────────────────
const C = {
  darkBg:   "0F1724",
  cardBg:   "1E293B",
  centerBg: "1E40AF",
  red:      "F87171",
  green:    "4ADE80",
  blue:     "60A5FA",
  amber:    "FBBF24",
  violet:   "C084FC",
  teal:     "2DD4BF",
  white:    "FFFFFF",
  light:    "CBD5E1",
  muted:    "94A3B8",
  darkText: "0F172A",
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function cellBorder(color = "334155") {
  const b = { style: BorderStyle.SINGLE, size: 6, color };
  return { top: b, bottom: b, left: b, right: b };
}

function shading(fill) {
  return { type: ShadingType.SOLID, color: fill, fill };
}

// Título de sección (fila de cabecera de bloque)
function sectionHeader(icon, title, color) {
  return new TableRow({
    children: [
      new TableCell({
        borders: cellBorder(color),
        shading: shading("1E293B"),
        children: [
          new Paragraph({
            alignment: AlignmentType.LEFT,
            spacing: { before: 80, after: 80 },
            children: [
              new TextRun({ text: `${icon}  ${title}`, bold: true, color, size: 22, font: "Segoe UI" }),
            ],
          }),
        ],
      }),
    ],
  });
}

// Fila de pregunta → respuesta
function qaRow(question, answer, accentColor) {
  return new TableRow({
    children: [
      new TableCell({
        borders: cellBorder("334155"),
        shading: shading("0F172A"),
        margins: { top: 60, bottom: 60, left: 120, right: 120 },
        children: [
          new Paragraph({
            spacing: { before: 40, after: 40 },
            children: [
              new TextRun({ text: `${question}  `, bold: true, color: accentColor, size: 18, font: "Segoe UI" }),
              new TextRun({ text: answer, color: C.light, size: 18, font: "Segoe UI" }),
            ],
          }),
        ],
      }),
    ],
  });
}

// Fila de concepto (etiqueta + texto)
function conceptRow(label, text, accentColor) {
  return new TableRow({
    children: [
      new TableCell({
        borders: cellBorder("334155"),
        shading: shading("1E293B"),
        margins: { top: 50, bottom: 50, left: 160, right: 120 },
        children: [
          new Paragraph({
            spacing: { before: 30, after: 30 },
            children: [
              new TextRun({ text: `▸  `, color: "475569", size: 16, font: "Segoe UI" }),
              new TextRun({ text: `${label}  `, bold: true, color: accentColor, size: 17, font: "Segoe UI" }),
              new TextRun({ text, color: C.light, size: 17, font: "Segoe UI" }),
            ],
          }),
        ],
      }),
    ],
  });
}

// Bloque completo (cabecera + filas)
function block(icon, title, color, rows) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    margins: { top: 60, bottom: 60, left: 0, right: 0 },
    rows: [sectionHeader(icon, title, color), ...rows],
  });
}

// Espacio entre bloques
function spacer() {
  return new Paragraph({ spacing: { before: 0, after: 120 }, children: [] });
}

// ── Documento ─────────────────────────────────────────────────────────────────
const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: "Segoe UI", size: 20, color: C.light },
      },
    },
  },
  sections: [
    {
      properties: {
        page: {
          margin: { top: convertInchesToTwip(0.7), bottom: convertInchesToTwip(0.7), left: convertInchesToTwip(0.8), right: convertInchesToTwip(0.8) },
        },
      },
      children: [

        // ── TÍTULO PRINCIPAL ────────────────────────────────────────────────
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 100 },
          children: [
            new TextRun({ text: "Alta Disponibilidad y Escalamiento Automático", bold: true, size: 30, color: "7DD3FC", font: "Segoe UI" }),
          ],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 60 },
          children: [
            new TextRun({ text: "Mapa Conceptual — Sistema de Gestión de Inventarios en la Nube", size: 20, color: C.muted, font: "Segoe UI" }),
          ],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 300 },
          children: [
            new TextRun({ text: "Equipo: Los Rojos  ·  Miscelánea familiar, Los Mochis, Sinaloa  ·  AWS Academy", size: 18, color: C.muted, font: "Segoe UI" }),
          ],
        }),

        // ── NODO CENTRAL ────────────────────────────────────────────────────
        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                new TableCell({
                  borders: { top: { style: BorderStyle.SINGLE, size: 8, color: "38BDF8" }, bottom: { style: BorderStyle.SINGLE, size: 8, color: "38BDF8" }, left: { style: BorderStyle.SINGLE, size: 8, color: "38BDF8" }, right: { style: BorderStyle.SINGLE, size: 8, color: "38BDF8" } },
                  shading: shading("1E40AF"),
                  margins: { top: 120, bottom: 120, left: 200, right: 200 },
                  verticalAlign: VerticalAlign.CENTER,
                  children: [
                    new Paragraph({
                      alignment: AlignmentType.CENTER,
                      children: [
                        new TextRun({ text: "🖥️  Sistema de Gestión de Inventarios", bold: true, size: 26, color: C.white, font: "Segoe UI" }),
                      ],
                    }),
                    new Paragraph({
                      alignment: AlignmentType.CENTER,
                      children: [
                        new TextRun({ text: "Miscelánea familiar · Los Mochis, Sinaloa · AWS Academy", size: 18, color: "BAE6FD", font: "Segoe UI" }),
                      ],
                    }),
                  ],
                }),
              ],
            }),
          ],
        }),

        spacer(),

        // ── 1. ALTA DISPONIBILIDAD ──────────────────────────────────────────
        block("🔴", "Alta Disponibilidad — Que NO se caiga", C.red, [
          qaRow("¿Qué puede fallar?", "La instancia EC2 (ec2-api-los-rojos) con la API Node.js/Express, o la RDS PostgreSQL con el catálogo de productos y movimientos.", C.red),
          qaRow("¿Quién lo detecta?", "El Health Check del Application Load Balancer revisando el endpoint /health (RF-13) que reporta estado de RDS y S3.", C.red),
          qaRow("¿A dónde manda el tráfico?", "El ALB redirige al Grupo Destino con instancias saludables; RDS Multi-AZ hace failover automático a la réplica standby.", C.red),
          conceptRow("Disponibilidad SLA:", "EC2 99.99% · RDS 99.95% — disponible en E2 (11 nov) y E3 (14 dic)", C.red),
          conceptRow("Punto único de falla eliminado:", "ALB frente a las EC2 de la API", C.red),
          conceptRow("Zona de disponibilidad:", "us-east-1a (principal) + us-east-1b (standby RDS)", C.red),
          conceptRow("Redundancia:", "RDS Multi-AZ con réplica síncrona en segunda AZ", C.red),
          conceptRow("Tolerancia a fallos:", "EC2 reemplazada automáticamente por Auto Scaling", C.red),
          conceptRow("Balanceador de carga:", "Application Load Balancer capa 7 — HTTP/HTTPS", C.red),
          conceptRow("Grupo destino:", "Instancias EC2 con la API del inventario", C.red),
          conceptRow("Verificación de estado:", 'GET /health → {"db":"ok","s3":"ok"} cada 30 s', C.red),
          conceptRow("Grupos de seguridad en cadena:", "sg-alb → sg-ec2-api → sg-rds-postgres", C.red),
        ]),

        spacer(),

        // ── 2. ESCALAMIENTO AUTOMÁTICO ──────────────────────────────────────
        block("📈", "Escalamiento Automático — Que aguante la demanda", C.green, [
          qaRow("¿Cuántos servidores?", "Mínimo 1 EC2 t3.micro (Free Tier), máximo 3. El límite de créditos AWS Academy determina el techo.", C.green),
          qaRow("¿Quién decide?", "AWS Auto Scaling Group vinculado al ALB, monitoreando métricas de CPU vía CloudWatch.", C.green),
          qaRow("¿Con qué regla?", "Política de objetivo: CPU promedio ≥ 70% → agrega instancias. CPU < 30% → reduce.", C.green),
          qaRow("¿Cuánto cuesta?", "EC2 t3.micro cubierta por Free Tier/créditos Academy. Sin NAT Gateway activo permanente (restricción L-02).", C.green),
          conceptRow("Escalamiento Vertical:", "Cambiar t3.micro → t3.small en consola sin hardware adicional (RNF-03)", C.green),
          conceptRow("Escalamiento Horizontal:", "Auto Scaling Group añade EC2 t3.micro detrás del ALB", C.green),
          conceptRow("Plantilla de lanzamiento:", "AMI con Node.js + API preconfigurada + variables .env", C.green),
          conceptRow("Política objetivo:", "CPU ≥ 70% → scale out · CPU < 30% → scale in", C.green),
          conceptRow("Métrica y umbral:", "CPUUtilization vía CloudWatch cada 60 s", C.green),
          conceptRow("Período de calentamiento:", "120 s para que la nueva EC2 arranque la API", C.green),
          conceptRow("Período de gracia:", "60 s antes de que el health check juzgue la nueva instancia", C.green),
        ]),

        spacer(),

        // ── 3. ARQUITECTURA AWS ─────────────────────────────────────────────
        block("🏗️", "Arquitectura AWS del Sistema", C.blue, [
          conceptRow("Frontend:", "SPA HTML/CSS/JS en S3 bucket-los-rojos (OE-05)", C.blue),
          conceptRow("API:", "Node.js + Express en EC2 t3.micro — ec2-api (OE-01)", C.blue),
          conceptRow("Base de datos:", "RDS PostgreSQL db.t3.micro — rds-los-rojos (OE-02)", C.blue),
          conceptRow("Almacenamiento imágenes:", "S3 estándar → URL pública por producto (RF-12)", C.blue),
          conceptRow("Red:", "VPC con subred pública (EC2, ALB) y subred privada (RDS)", C.blue),
          conceptRow("Seguridad en cadena:", "sg-alb (80/443) → sg-api (3000) → sg-rds (5432)", C.blue),
          conceptRow("Credenciales:", "Instance Profile con rol IAM — sin llaves hardcoded (RNF-05)", C.blue),
          conceptRow("HTTPS:", "TLS 1.2+ en toda comunicación cliente ↔ API ↔ RDS (RNF-02)", C.blue),
        ]),

        spacer(),

        // ── 4. CONEXIÓN entre ramas ─────────────────────────────────────────
        block("🔗", "¿Qué conecta las dos ramas?", C.amber, [
          conceptRow("Load Balancer:", "Distribuye peticiones de cajeros, bodegueros y admin entre EC2 disponibles", C.amber),
          conceptRow("Auto Scaling:", "Durante el corte diario o si varios cajeros registran ventas simultáneas, agrega una EC2 automáticamente", C.amber),
          conceptRow("Health Check /health:", "Detecta EC2 con API caída, la saca del grupo destino y Auto Scaling lanza reemplazo", C.amber),
          conceptRow("RDS Multi-AZ:", "Si la AZ primaria falla durante una venta, el failover preserva los movimientos sin pérdida de datos", C.amber),
          conceptRow("S3 99.999999999%:", "Imágenes y frontend siempre disponibles independiente del estado de las EC2", C.amber),
          new TableRow({
            children: [
              new TableCell({
                borders: cellBorder(C.amber),
                shading: shading("0F172A"),
                margins: { top: 80, bottom: 80, left: 160, right: 120 },
                children: [
                  new Paragraph({
                    children: [
                      new TextRun({ text: "T3 — Requisito: ", bold: true, color: C.amber, size: 18, font: "Segoe UI" }),
                      new TextRun({ text: "Mínimo 3 instancias (min=1, deseado=2, máx=3). Cada instancia sirve a los 3 roles: Administrador · Bodega · Cajero. Funcionamiento visible INDIVIDUAL por endpoint.", color: C.light, size: 17, font: "Segoe UI" }),
                    ],
                  }),
                ],
              }),
            ],
          }),
        ]),

        spacer(),

        // ── 5. CONCEPTOS OBLIGATORIOS ───────────────────────────────────────
        block("📚", "Conceptos OBLIGATORIOS — Aplicación en el proyecto", C.violet, [
          conceptRow("Disponibilidad:", "SLA EC2 99.99% / RDS 99.95% — sistema accesible durante E2 (11 nov) y E3 (14 dic)", C.violet),
          conceptRow("Punto único de falla:", "Eliminado con ALB + Multi-AZ RDS", C.violet),
          conceptRow("Zona de disponibilidad:", "us-east-1a (principal) + us-east-1b (standby RDS)", C.violet),
          conceptRow("Redundancia:", "Réplica síncrona de RDS; múltiples EC2 detrás del ALB", C.violet),
          conceptRow("Tolerancia a fallos:", "Auto Scaling reemplaza instancias no saludables automáticamente", C.violet),
          conceptRow("Balanceador de carga (Aplicación):", "ALB enruta /api/* a EC2 y /* a S3", C.violet),
          conceptRow("Grupo destino:", "EC2 con la API del inventario (Node.js puerto 3000)", C.violet),
          conceptRow("Verificación de estado:", "Endpoint /health cada 30 s, umbral 2 fallos = unhealthy", C.violet),
          conceptRow("Grupos de seguridad en cadena:", "ALB → EC2 → RDS (tráfico mínimo necesario)", C.violet),
          conceptRow("Base Multi-AZ:", "RDS PostgreSQL con failover automático activado", C.violet),
          conceptRow("Escalamiento Vertical:", "t3.micro → t3.small si el tráfico crece post-semestre", C.violet),
          conceptRow("Escalamiento Horizontal:", "Auto Scaling Group 1→3 instancias EC2 t3.micro", C.violet),
          conceptRow("Plantilla de lanzamiento:", "AMI con API preconfigurada + user-data script", C.violet),
          conceptRow("Política objetivo:", "CPUUtilization target 70%", C.violet),
          conceptRow("Métrica y umbral:", "CPU ≥ 70% → +1 EC2 · CPU < 30% → -1 EC2", C.violet),
          conceptRow("Calentamiento / Período de gracia:", "120 s arranque · 60 s antes del primer health check", C.violet),
        ]),

        spacer(),

        // ── 6. ¿POR QUÉ LO NECESITA LA MISCELÁNEA? ─────────────────────────
        block("🏪", "¿Por qué lo necesita la miscelánea?", C.teal, [
          conceptRow("Sin caída en caja:", "Una venta genera salida en inventario (RF-03/RF-04) — si la EC2 cae a mitad del registro, la transacción se pierde", C.teal),
          conceptRow("Alerta de stock:", "El sistema detecta stock ≤ mínimo (RF-05) en tiempo real — una caída de 5 min puede significar no detectar un agotamiento", C.teal),
          conceptRow("Acceso remoto de la propietaria:", "Consulta inventario desde casa 24h (problema original) — necesita alta disponibilidad constante", C.teal),
          conceptRow("Corte diario:", "Si hay carga simultánea cajero + bodeguero + propietaria, el escalamiento evita superar 500 ms (RNF-01)", C.teal),
          conceptRow("Respaldo automático:", "RDS retiene 7 días de backups (RNF-03) — un error en un movimiento puede revertirse", C.teal),
        ]),

      ],
    },
  ],
});

// ── Guardar ───────────────────────────────────────────────────────────────────
const outPath = path.join(__dirname, "..", "MapaConceptual_AltaDisponibilidad_LosRojos.docx");

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outPath, buffer);
  console.log("✅  Archivo generado:", outPath);
}).catch((err) => {
  console.error("❌  Error:", err);
  process.exit(1);
});
