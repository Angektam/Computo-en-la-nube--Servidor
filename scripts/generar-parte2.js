const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, BorderStyle, ShadingType, AlignmentType, VerticalAlign,
  convertInchesToTwip, HeightRule
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── Colores ──────────────────────────────────────────────────────────────────
const C = {
  darkBg:  "0F1724",
  cardBg:  "1E293B",
  black:   "0F172A",
  red:     "F87171",
  green:   "4ADE80",
  blue:    "60A5FA",
  amber:   "FBBF24",
  violet:  "C084FC",
  teal:    "2DD4BF",
  white:   "FFFFFF",
  light:   "CBD5E1",
  muted:   "94A3B8",
  dim:     "475569",
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function border(color) {
  const b = { style: BorderStyle.SINGLE, size: 6, color };
  return { top: b, bottom: b, left: b, right: b };
}
function noBorder() {
  const b = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
  return { top: b, bottom: b, left: b, right: b };
}
function shade(fill) { return { type: ShadingType.SOLID, color: fill, fill }; }
function sp(b = 0, a = 0) { return { before: b, after: a }; }
function run(text, opts = {}) {
  return new TextRun({ text, font: "Consolas", size: 18, ...opts });
}
function prun(text, opts = {}) {
  return new TextRun({ text, font: "Segoe UI", size: 19, ...opts });
}

// Párrafo simple
function p(children, align = AlignmentType.LEFT, spaceBefore = 0, spaceAfter = 80) {
  return new Paragraph({ alignment: align, spacing: sp(spaceBefore, spaceAfter), children });
}

// Sección de título (cabecera de bloque)
function sectionTitle(num, title, color) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            borders: border(color),
            shading: shade("1E293B"),
            margins: { top: 120, bottom: 120, left: 200, right: 200 },
            children: [
              p([
                prun(`${num}  `, { bold: true, color, size: 24 }),
                prun(title, { bold: true, color, size: 24 }),
              ]),
            ],
          }),
        ],
      }),
    ],
  });
}

// Caja de texto con borde izquierdo
function infoBox(children, color) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          // borde izquierdo de color
          new TableCell({
            width: { size: 3, type: WidthType.PERCENTAGE },
            borders: {
              top: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" },
              bottom: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" },
              left: { style: BorderStyle.SINGLE, size: 20, color },
              right: { style: BorderStyle.NONE, size: 0, color: "FFFFFF" },
            },
            shading: shade("0F172A"),
            children: [p([])],
          }),
          new TableCell({
            width: { size: 97, type: WidthType.PERCENTAGE },
            borders: noBorder(),
            shading: shade("0F172A"),
            margins: { top: 80, bottom: 80, left: 160, right: 160 },
            children,
          }),
        ],
      }),
    ],
  });
}

// Tabla de datos (encabezados + filas)
function dataTable(headers, rows, accentColor) {
  const headerCells = headers.map(h =>
    new TableCell({
      borders: border("334155"),
      shading: shade("0F172A"),
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
      children: [p([prun(h, { bold: true, color: "7DD3FC", size: 17 })])],
    })
  );

  const dataRows = rows.map((row, ri) =>
    new TableRow({
      children: row.map((cell, ci) =>
        new TableCell({
          borders: border("334155"),
          shading: shade(ri % 2 === 0 ? "1E293B" : "162032"),
          margins: { top: 70, bottom: 70, left: 120, right: 120 },
          children: [
            p([
              typeof cell === "string"
                ? prun(cell, { color: ci === 0 ? accentColor : C.light, size: 17 })
                : cell,
            ]),
          ],
        })
      ),
    })
  );

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [new TableRow({ children: headerCells }), ...dataRows],
  });
}

// Bloque de código / diagrama ASCII
function codeBlock(lines) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            borders: border("334155"),
            shading: shade("0F172A"),
            margins: { top: 100, bottom: 100, left: 200, right: 200 },
            children: lines.map(({ text, color }) =>
              new Paragraph({
                spacing: sp(0, 20),
                children: [run(text, { color: color || C.muted, size: 17 })],
              })
            ),
          }),
        ],
      }),
    ],
  });
}

function spacer(n = 160) {
  return new Paragraph({ spacing: sp(0, n), children: [] });
}

// ── DOCUMENTO ─────────────────────────────────────────────────────────────────
const doc = new Document({
  styles: {
    default: {
      document: { run: { font: "Segoe UI", size: 19, color: C.light } },
    },
  },
  sections: [
    {
      properties: {
        page: {
          margin: {
            top: convertInchesToTwip(0.75),
            bottom: convertInchesToTwip(0.75),
            left: convertInchesToTwip(0.85),
            right: convertInchesToTwip(0.85),
          },
        },
      },
      children: [

        // ── PORTADA ──────────────────────────────────────────────────────────
        p([prun("Parte 2 · Su Proyecto — Los Rojos", { bold: true, size: 32, color: "7DD3FC" })], AlignmentType.CENTER, 0, 60),
        p([prun("Sistema de Gestión de Inventarios · Miscelánea familiar · AWS us-east-1", { size: 19, color: C.muted })], AlignmentType.CENTER, 0, 300),

        // ════════════════════════════════════════════════════════════════════
        // PUNTO 1 — Arquitectura actual con puntos de falla
        // ════════════════════════════════════════════════════════════════════
        sectionTitle("1️⃣", "Arquitectura actual con puntos únicos de falla marcados con ✗", C.red),
        spacer(120),

        codeBlock([
          { text: "Internet" },
          { text: "    |" },
          { text: "    |  HTTPS" },
          { text: "    ▼" },
          { text: "✗  EC2 t3.micro  ──────────────── PUNTO ÚNICO DE FALLA #1", color: C.red },
          { text: "   │  (API Node.js + Express)" },
          { text: "   │  Una sola instancia · una sola AZ (us-east-1a)" },
          { text: "   │  Si cae → toda la API deja de responder" },
          { text: "    |" },
          { text: "    |  Puerto 5432 / TLS" },
          { text: "    ▼" },
          { text: "✗  RDS PostgreSQL db.t3.micro ──── PUNTO ÚNICO DE FALLA #2", color: C.red },
          { text: "   │  Single-AZ (us-east-1a)" },
          { text: "   │  Si la AZ falla → BD sin réplica = pérdida de movimientos" },
          { text: "    |" },
          { text: "    ▼" },
          { text: "✗  S3 bucket-los-rojos (frontend) ─ PUNTO ÚNICO DE FALLA #3*", color: C.red },
          { text: "   * Sin CDN = sin caché. Política pública perdida = sitio inaccesible." },
        ]),

        spacer(100),
        infoBox([
          p([prun("Resumen de puntos de falla:", { bold: true, color: C.red })]),
          p([
            prun("✗ #1  ", { bold: true, color: C.red }),
            prun("Una sola EC2 → si se cae, no se pueden registrar ventas ni consultar stock.", { color: C.light }),
          ], AlignmentType.LEFT, 0, 40),
          p([
            prun("✗ #2  ", { bold: true, color: C.red }),
            prun("RDS Single-AZ → si falla us-east-1a, pérdida de movimientos hasta restaurar backup.", { color: C.light }),
          ], AlignmentType.LEFT, 0, 40),
          p([
            prun("✗ #3  ", { bold: true, color: C.red }),
            prun("Sin Load Balancer → no hay quien redirija el tráfico si la instancia no responde.", { color: C.light }),
          ], AlignmentType.LEFT, 0, 0),
        ], C.red),

        spacer(240),

        // ════════════════════════════════════════════════════════════════════
        // PUNTO 2 — Arquitectura rediseñada Multi-AZ
        // ════════════════════════════════════════════════════════════════════
        sectionTitle("2️⃣", "Arquitectura rediseñada · ALB + 2 EC2 en 2 AZ + RDS Multi-AZ", C.green),
        spacer(120),

        codeBlock([
          { text: "Internet" },
          { text: "          |" },
          { text: "          | HTTPS (443)" },
          { text: "          ▼" },
          { text: "✔  Application Load Balancer  (balanceador en dos subredes públicas)", color: C.green },
          { text: "   ├─ Subred pública us-east-1a  (sg-alb: 80/443 desde 0.0.0.0/0)" },
          { text: "   └─ Subred pública us-east-1b  (sg-alb: 80/443 desde 0.0.0.0/0)" },
          { text: "          |" },
          { text: "    ┌─────┴──────┐" },
          { text: "    |             |" },
          { text: "    ▼             ▼" },
          { text: "✔ EC2 t3.micro    ✔ EC2 t3.micro      ← dos servidores en dos zonas", color: C.green },
          { text: "  API Node.js       API Node.js" },
          { text: "  us-east-1a        us-east-1b" },
          { text: "  Subred pública    Subred pública" },
          { text: "  sg-api: 3000      sg-api: 3000" },
          { text: "    |             |" },
          { text: "    └──────┬──────┘" },
          { text: "           |  Puerto 5432 / TLS" },
          { text: "           ▼" },
          { text: "✔  RDS PostgreSQL Multi-AZ                                          ", color: C.green },
          { text: "   ├─ Primaria  us-east-1a  (Subred privada)  ← escrituras normales" },
          { text: "   └─ Standby   us-east-1b  (Subred privada)  ← failover < 60 s" },
          { text: "   sg-rds: 5432 solo desde sg-api" },
        ]),

        spacer(100),
        infoBox([
          p([prun("Cambios clave:", { bold: true, color: C.green })]),
          p([prun("✔  ALB en ", { color: C.green }), prun("dos", { bold: true, color: C.white }), prun(" subredes públicas — detecta fallos y re-enruta.", { color: C.light })], AlignmentType.LEFT, 0, 40),
          p([prun("✔  EC2 en ", { color: C.green }), prun("us-east-1a y us-east-1b", { bold: true, color: C.white }), prun(" — si una AZ falla, el ALB sigue enviando tráfico a la otra.", { color: C.light })], AlignmentType.LEFT, 0, 40),
          p([prun("✔  RDS Multi-AZ", { color: C.green }), prun(" con failover automático — los movimientos de inventario no se pierden.", { color: C.light })], AlignmentType.LEFT, 0, 40),
          p([prun("✔  Grupos de seguridad en cadena: ", { color: C.green }), prun("sg-alb → sg-api → sg-rds", { bold: true, color: C.white }), prun(" (mínimo privilegio).", { color: C.light })], AlignmentType.LEFT, 0, 0),
        ], C.green),

        spacer(240),

        // ════════════════════════════════════════════════════════════════════
        // PUNTO 3 — Verificación de estado
        // ════════════════════════════════════════════════════════════════════
        sectionTitle("3️⃣", "Verificación de estado — ruta, frecuencia y umbral de fallos", C.blue),
        spacer(120),

        dataTable(
          ["Parámetro", "Valor", "Justificación"],
          [
            ["Ruta (endpoint)", "GET /health", 'RF-13 del E1: retorna {"db":"ok","s3":"ok"} con HTTP 200; HTTP 500 si BD o S3 no responden'],
            ["Protocolo", "HTTP interno ALB→EC2", "El ALB habla HTTP al puerto 3000; el TLS termina en el ALB"],
            ["Intervalo", "30 segundos", "Detecta caídas en < 1 min sin saturar la EC2"],
            ["Timeout por intento", "5 segundos", "Si la API tarda > 5 s en /health, cuenta como fallo (RNF-01: < 500 ms en condiciones normales)"],
            ["Fallos para Unhealthy", "2 fallos consecutivos", "2 × 30 s = 60 s máximo antes de retirar el servidor. Evita retiradas por fallo transitorio"],
            ["Éxitos para Healthy", "3 éxitos consecutivos", "90 s de estabilidad antes de reintroducir la instancia (período de calentamiento 120 s)"],
            ["Código HTTP esperado", "200", "Cualquier otro código (500, 503, timeout) se trata como fallo"],
          ],
          C.blue
        ),

        spacer(100),
        infoBox([
          p([
            prun("Flujo completo: ", { bold: true, color: C.blue }),
            prun("ALB llama a ", { color: C.light }),
            run("GET /health", { color: C.amber }),
            prun(" cada 30 s → 2 respuestas no-200 → instancia marcada ", { color: C.light }),
            prun("Unhealthy", { bold: true, color: C.red }),
            prun(" → ALB deja de enviarle tráfico → Auto Scaling lanza nueva EC2 → 3 respuestas 200 → instancia vuelve al grupo.", { color: C.light }),
          ]),
        ], C.blue),

        spacer(240),

        // ════════════════════════════════════════════════════════════════════
        // PUNTO 4 — Usuarios simultáneos y peticiones por segundo
        // ════════════════════════════════════════════════════════════════════
        sectionTitle("4️⃣", "Usuarios simultáneos · pico y valle → peticiones por segundo", C.amber),
        spacer(120),

        infoBox([
          p([
            prun("Supuesto base: ", { bold: true, color: C.amber }),
            prun("1 instancia t3.micro atiende ", { color: C.light }),
            prun("14 peticiones/segundo", { bold: true, color: C.white }),
            prun(" al 50 % de CPU. La miscelánea tiene ", { color: C.light }),
            prun("3 empleados + propietaria = 4 usuarios", { bold: true, color: C.white }),
            prun(" del sistema.", { color: C.light }),
          ]),
        ], C.amber),

        spacer(80),

        dataTable(
          ["Escenario", "Usuarios activos", "Req/usuario/s", "Total req/s", "EC2 necesarias", "Config ASG"],
          [
            ["Valle (madrugada)", "1 (propietaria revisa reportes)", "~1 req/s", "1 req/s", "1 EC2 al 7% CPU", "min = 1"],
            ["Normal (día)", "3 (cajero + bodega + admin)", "~2 req/s", "6 req/s", "1 EC2 al 43% CPU", "deseado = 1–2"],
            ["Pico (corte + ventas)", "4 (todos + cron de alertas)", "~4 req/s", "16 req/s", "2 EC2 al 57% CPU c/u", "máx = 3"],
          ],
          C.amber
        ),

        spacer(100),

        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                new TableCell({
                  borders: border("334155"),
                  shading: shade("0F172A"),
                  margins: { top: 100, bottom: 100, left: 200, right: 200 },
                  children: [
                    new Paragraph({
                      spacing: sp(0, 40),
                      children: [run("Pico: 4 usuarios × 4 req/s = 16 req/s", { color: C.amber, bold: true })],
                    }),
                    new Paragraph({
                      spacing: sp(0, 40),
                      children: [run("÷ 14 req/s por EC2 = 1.14  →  necesita 2 instancias activas", { color: C.light })],
                    }),
                    new Paragraph({
                      spacing: sp(0, 0),
                      children: [run("(con margen de seguridad al ~57 % CPU cada una)", { color: C.muted })],
                    }),
                  ],
                }),
              ],
            }),
          ],
        }),

        spacer(100),
        infoBox([
          p([prun("Conclusión: ", { bold: true, color: C.green }), prun("2 EC2 en pico · 1 EC2 en valle. El Auto Scaling Group absorbe el pico sin superar el 70 % de CPU objetivo, y ahorra costos en valle al reducir a 1 instancia.", { color: C.light })]),
        ], C.green),

        spacer(240),

        // ════════════════════════════════════════════════════════════════════
        // PUNTO 5 — Mínimo, deseado, máximo y política
        // ════════════════════════════════════════════════════════════════════
        sectionTitle("5️⃣", "Mínimo · Deseado · Máximo y política de escalamiento", C.violet),
        spacer(120),

        dataTable(
          ["Parámetro", "Valor", "¿Por qué?"],
          [
            ["Mínimo", "1 instancia", "Siempre debe haber al menos 1 EC2 para que la propietaria acceda remotamente (caso de uso principal del E1). Con 1 cubre el valle (1 req/s = 7 % CPU)."],
            ["Deseado", "2 instancias", "Cubre el uso normal (3 empleados, ~6 req/s). Ninguna supera el 43 % de CPU. Además garantiza alta disponibilidad en dos AZs simultáneamente."],
            ["Máximo", "3 instancias", "El pico real es 16 req/s. 2 instancias lo cubren; la tercera es el colchón de seguridad. 3 × t3.micro caben dentro de los créditos AWS Academy."],
          ],
          C.violet
        ),

        spacer(100),

        infoBox([
          p([prun("Política de escalamiento: ", { bold: true, color: C.violet }), prun("Objetivo de seguimiento (Target Tracking Policy)", { bold: true, color: C.amber })]),
          spacer(60),
          dataTable(
            ["Campo", "Valor"],
            [
              ["Tipo", "Target Tracking Policy — AWS ajusta automáticamente las instancias para mantener la métrica cerca del objetivo"],
              ["Métrica", "CPUUtilization (promedio de todas las instancias del grupo)"],
              ["Valor objetivo", "70 %"],
              ["¿Por qué 70%?", "Al 50% = 14 req/s → al 70% ≈ 19.6 req/s por instancia. Deja margen del 30% antes de saturarse y cumple RNF-01 (<500 ms). Un objetivo más bajo (ej. 40%) escala demasiado pronto y desperdicia créditos Academy."],
              ["Período de calentamiento", "120 s — tiempo para arrancar Node.js, cargar .env y pasar el primer health check"],
              ["Período de gracia", "60 s — el ALB espera antes de enviar tráfico a una instancia nueva, evitando errores 502"],
            ],
            C.violet
          ),
        ], C.violet),

        spacer(100),

        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                new TableCell({
                  borders: border(C.violet),
                  shading: shade("1A1A2E"),
                  margins: { top: 120, bottom: 120, left: 200, right: 200 },
                  children: [
                    p([prun("Resumen de configuración del Auto Scaling Group", { bold: true, color: C.violet, size: 20 })], AlignmentType.LEFT, 0, 80),
                    p([run("Mínimo:  ", { bold: true }), run("1", { color: C.green, bold: true }), run("  →  siempre hay una EC2 activa (acceso remoto propietaria)", { color: C.light })], AlignmentType.LEFT, 0, 40),
                    p([run("Deseado: ", { bold: true }), run("2", { color: C.amber, bold: true }), run("  →  carga normal de los 3 empleados en horario laboral", { color: C.light })], AlignmentType.LEFT, 0, 40),
                    p([run("Máximo:  ", { bold: true }), run("3", { color: C.red, bold: true }), run("  →  absorbe el corte diario + créditos Academy no se agotan", { color: C.light })], AlignmentType.LEFT, 0, 40),
                    p([run("Política: Target Tracking · CPU objetivo ", { color: C.light }), run("70 %", { color: C.amber, bold: true })], AlignmentType.LEFT, 0, 40),
                    p([run("Scale-out: CPU > 70% por 2 períodos de 60 s  →  +1 EC2", { color: C.light })], AlignmentType.LEFT, 0, 40),
                    p([run("Scale-in:  CPU < 30% por 15 períodos de 60 s  →  -1 EC2", { color: C.light })], AlignmentType.LEFT, 0, 0),
                  ],
                }),
              ],
            }),
          ],
        }),

      ],
    },
  ],
});

// ── Guardar ───────────────────────────────────────────────────────────────────
const outPath = path.join(__dirname, "..", "Parte2_AltaDisponibilidad_LosRojos.docx");
Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outPath, buffer);
  console.log("✅  Archivo generado:", outPath);
}).catch((err) => {
  console.error("❌  Error:", err);
  process.exit(1);
});
