// =============================================================================
// Genera P04_LosRojos_30sep2026.docx
// Ejecutar: node scripts/generar-practica04-doc.js
// =============================================================================
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel,
  AlignmentType, Table, TableRow, TableCell, WidthType,
  BorderStyle, ShadingType, PageBreak, VerticalAlign,
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── Helpers ──────────────────────────────────────────────────────────────────

function titulo(text) {
  return new Paragraph({
    text,
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
  });
}

function subtitulo(text) {
  return new Paragraph({
    text,
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 300, after: 150 },
  });
}

function parrafo(text, opts = {}) {
  return new Paragraph({
    children: [new TextRun({ text, size: 24, font: "Calibri", ...opts })],
    spacing: { after: 160 },
    alignment: AlignmentType.JUSTIFIED,
  });
}

function bold(text) {
  return new TextRun({ text, bold: true, size: 24, font: "Calibri" });
}

function code(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: "Courier New", size: 20, color: "1a1f36" })],
    shading: { type: ShadingType.CLEAR, fill: "F0F2F5" },
    spacing: { before: 80, after: 80 },
    indent: { left: 400 },
  });
}

function lineaVacia() {
  return new Paragraph({ text: "", spacing: { after: 100 } });
}

function tablaDatos(filas) {
  // filas: [[col1, col2, col3?], ...]  primera fila = encabezado
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: filas.map((fila, rowIdx) =>
      new TableRow({
        children: fila.map((celda) =>
          new TableCell({
            children: [new Paragraph({
              children: [new TextRun({
                text: celda,
                bold: rowIdx === 0,
                size: 22,
                font: "Calibri",
                color: rowIdx === 0 ? "FFFFFF" : "1a1f36",
              })],
              alignment: AlignmentType.CENTER,
              spacing: { before: 60, after: 60 },
            })],
            shading: rowIdx === 0
              ? { type: ShadingType.CLEAR, fill: "D63031" }
              : { type: ShadingType.CLEAR, fill: rowIdx % 2 === 0 ? "F8FAFC" : "FFFFFF" },
            verticalAlign: VerticalAlign.CENTER,
            margins: { top: 80, bottom: 80, left: 120, right: 120 },
          })
        ),
      })
    ),
  });
}

// ── Portada ───────────────────────────────────────────────────────────────────
const portada = [
  lineaVacia(), lineaVacia(), lineaVacia(),
  new Paragraph({
    children: [new TextRun({ text: "UNIVERSIDAD AUTÓNOMA DE SINALOA", bold: true, size: 32, font: "Calibri", color: "D63031" })],
    alignment: AlignmentType.CENTER, spacing: { after: 200 },
  }),
  new Paragraph({
    children: [new TextRun({ text: "Facultad de Ingeniería Mochis", size: 26, font: "Calibri" })],
    alignment: AlignmentType.CENTER, spacing: { after: 100 },
  }),
  new Paragraph({
    children: [new TextRun({ text: "Ingeniería de Software", size: 26, font: "Calibri" })],
    alignment: AlignmentType.CENTER, spacing: { after: 400 },
  }),
  new Paragraph({
    children: [new TextRun({ text: "PRÁCTICA 04", bold: true, size: 40, font: "Calibri", color: "D63031" })],
    alignment: AlignmentType.CENTER, spacing: { after: 200 },
  }),
  new Paragraph({
    children: [new TextRun({ text: "Almacenamiento de objetos y publicación del sitio del proyecto", bold: true, size: 28, font: "Calibri" })],
    alignment: AlignmentType.CENTER, spacing: { after: 400 },
  }),
  lineaVacia(), lineaVacia(),
  tablaDatos([
    ["Campo", "Valor"],
    ["Materia", "Cómputo en la Nube · Grupos 501 y 503"],
    ["Maestra", "Elizabeth Gaxiola Carrillo"],
    ["Equipo", "Los Rojos"],
    ["Integrante 1", "López Payán Kevin Ricardo"],
    ["Integrante 2", "Flores Guevara Ángel Gabriel"],
    ["Fecha", "Miércoles 30 de septiembre de 2026"],
    ["Bucket", "sitio-inventario-cloud-los-rojos"],
    ["Región", "us-east-1"],
  ]),
  lineaVacia(), lineaVacia(),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Sección 1: Criterio 1 — Bucket y etiquetas ───────────────────────────────
const seccion1 = [
  titulo("1. Bucket etiquetado conforme al esquema del equipo (10 pts)"),
  parrafo("Se creó el bucket sitio-inventario-cloud-los-rojos en la región us-east-1 y se le aplicaron las tres etiquetas del esquema del equipo mediante el comando aws s3api put-bucket-tagging."),
  lineaVacia(),
  subtitulo("Comando ejecutado"),
  code("aws s3api get-bucket-tagging --bucket sitio-inventario-cloud-los-rojos"),
  lineaVacia(),
  subtitulo("Salida obtenida"),
  code("{"),
  code('    "TagSet": ['),
  code('        { "Key": "proyecto", "Value": "inventario-cloud" },'),
  code('        { "Key": "ambiente", "Value": "dev" },'),
  code('        { "Key": "equipo",   "Value": "los-rojos" }'),
  code("    ]"),
  code("}"),
  lineaVacia(),
  new Paragraph({
    children: [
      new TextRun({ text: "→ INSERTAR CAPTURA: ", bold: true, color: "D63031", size: 22, font: "Calibri" }),
      new TextRun({ text: "CloudShell con salida de get-bucket-tagging mostrando las 3 etiquetas", size: 22, font: "Calibri" }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "FFEAEA" },
    spacing: { before: 100, after: 200 },
    indent: { left: 200 },
  }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Sección 2: Criterio 2 — Bloqueo de acceso público ────────────────────────
const seccion2 = [
  titulo("2. Estado inicial del bloqueo y modificación justificada (20 pts)"),
  parrafo("Al crear el bucket, AWS activa por defecto los cuatro controles de acceso público. Se documentó ese estado inicial antes de modificarlo, y se desactivaron únicamente los dos controles que impiden aplicar una política de bucket pública, dejando activos los que protegen contra ACLs."),
  lineaVacia(),
  subtitulo("Estado INICIAL (antes de modificar)"),
  code("aws s3api get-public-access-block --bucket sitio-inventario-cloud-los-rojos"),
  code("{"),
  code('    "PublicAccessBlockConfiguration": {'),
  code('        "BlockPublicAcls":       true,'),
  code('        "IgnorePublicAcls":      true,'),
  code('        "BlockPublicPolicy":     true,   ← impedía aplicar política'),
  code('        "RestrictPublicBuckets": true    ← ignoraba políticas públicas'),
  code("    }"),
  code("}"),
  lineaVacia(),
  subtitulo("Estado FINAL (después de la modificación mínima)"),
  code("{"),
  code('    "PublicAccessBlockConfiguration": {'),
  code('        "BlockPublicAcls":       true,   ← MANTENIDO  (no usamos ACLs)'),
  code('        "IgnorePublicAcls":      true,   ← MANTENIDO  (seguridad extra)'),
  code('        "BlockPublicPolicy":     false,  ← MODIFICADO (permite la policy)'),
  code('        "RestrictPublicBuckets": false   ← MODIFICADO (aplica la policy)'),
  code("    }"),
  code("}"),
  lineaVacia(),
  subtitulo("Justificación"),
  new Paragraph({
    children: [
      bold("BlockPublicAcls = true: "),
      new TextRun({ text: "No usamos ACLs para publicar, usamos una bucket policy. Mantenerlo bloqueado es la práctica correcta.", size: 24, font: "Calibri" }),
    ], spacing: { after: 140 },
  }),
  new Paragraph({
    children: [
      bold("IgnorePublicAcls = true: "),
      new TextRun({ text: "Capa adicional de seguridad que ignora cualquier ACL pública preexistente en los objetos.", size: 24, font: "Calibri" }),
    ], spacing: { after: 140 },
  }),
  new Paragraph({
    children: [
      bold("BlockPublicPolicy = false: "),
      new TextRun({ text: "Por defecto bloqueaba cualquier política que otorgara acceso público. Se desactivó únicamente para poder agregar la política de lectura del sitio.", size: 24, font: "Calibri" }),
    ], spacing: { after: 140 },
  }),
  new Paragraph({
    children: [
      bold("RestrictPublicBuckets = false: "),
      new TextRun({ text: "Por defecto ignoraba las políticas públicas aunque existieran. Se desactivó para que la política de s3:GetObject tuviera efecto real.", size: 24, font: "Calibri" }),
    ], spacing: { after: 200 },
  }),
  new Paragraph({
    children: [
      new TextRun({ text: "→ INSERTAR CAPTURA: ", bold: true, color: "D63031", size: 22, font: "Calibri" }),
      new TextRun({ text: "CloudShell con salida de get-public-access-block mostrando el estado final", size: 22, font: "Calibri" }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "FFEAEA" },
    spacing: { before: 100, after: 200 },
    indent: { left: 200 },
  }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Sección 3: Criterio 3 — Política de bucket ───────────────────────────────
const seccion3 = [
  titulo("3. Política del bucket — solo lectura, sin permisos amplios (25 pts)"),
  parrafo("Se redactó una política que otorga únicamente s3:GetObject (lectura de objetos). No permite listar el contenido del bucket, subir archivos, borrarlos ni realizar ninguna operación de administración."),
  lineaVacia(),
  subtitulo("Política aplicada"),
  code("{"),
  code('  "Version": "2012-10-17",'),
  code('  "Statement": ['),
  code("    {"),
  code('      "Sid":       "PermitirLecturaSitioPublico",'),
  code('      "Effect":    "Allow",'),
  code('      "Principal": "*",'),
  code('      "Action":    "s3:GetObject",'),
  code('      "Resource":  "arn:aws:s3:::sitio-inventario-cloud-los-rojos/*"'),
  code("    }"),
  code("  ]"),
  code("}"),
  lineaVacia(),
  subtitulo("Explicación de cada parte"),
  new Paragraph({
    children: [bold("Version: 2012-10-17  →  "), new TextRun({ text: "Versión del lenguaje de políticas IAM. Es la más reciente y la requerida para usar todas las funciones modernas de IAM.", size: 24, font: "Calibri" })],
    spacing: { after: 140 },
  }),
  new Paragraph({
    children: [bold("Sid: PermitirLecturaSitioPublico  →  "), new TextRun({ text: "Identificador descriptivo del statement. No afecta el comportamiento, sirve para documentar y auditar qué hace cada regla.", size: 24, font: "Calibri" })],
    spacing: { after: 140 },
  }),
  new Paragraph({
    children: [bold("Effect: Allow  →  "), new TextRun({ text: "Concede el permiso. Si fuera Deny lo negaría explícitamente aunque otro statement lo permitiera.", size: 24, font: "Calibri" })],
    spacing: { after: 140 },
  }),
  new Paragraph({
    children: [bold('Principal: "*"  →  '), new TextRun({ text: "Aplica a cualquier entidad: usuarios anónimos, otras cuentas AWS, servicios. Necesario para que el sitio sea público sin autenticación.", size: 24, font: "Calibri" })],
    spacing: { after: 140 },
  }),
  new Paragraph({
    children: [bold("Action: s3:GetObject  →  "), new TextRun({ text: "Única acción permitida: descargar/leer un objeto ya existente. NO otorga s3:ListBucket (listar), s3:PutObject (subir), s3:DeleteObject (borrar) ni ninguna acción de administración.", size: 24, font: "Calibri" })],
    spacing: { after: 140 },
  }),
  new Paragraph({
    children: [bold("Resource: arn:aws:s3:::bucket/*  →  "), new TextRun({ text: "El /* al final significa 'todos los objetos dentro del bucket'. No da permisos sobre el bucket en sí (que requeriría sin /*) y no permite enumerar su contenido.", size: 24, font: "Calibri" })],
    spacing: { after: 200 },
  }),
  new Paragraph({
    children: [
      new TextRun({ text: "→ INSERTAR CAPTURA: ", bold: true, color: "D63031", size: 22, font: "Calibri" }),
      new TextRun({ text: "CloudShell con salida de get-bucket-policy mostrando el JSON de la política", size: 22, font: "Calibri" }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "FFEAEA" },
    spacing: { before: 100, after: 200 },
    indent: { left: 200 },
  }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Sección 4: Criterio 4 — Sitio accesible ──────────────────────────────────
const seccion4 = [
  titulo("4. Sitio accesible con información real del proyecto (20 pts)"),
  parrafo("El sitio informativo del proyecto quedó publicado mediante Amazon S3 Static Website Hosting. La página muestra el nombre del sistema, el problema que resuelve, los módulos desarrollados, la arquitectura en la nube, los tipos de usuario y los integrantes del equipo."),
  lineaVacia(),
  subtitulo("Error de acceso denegado (antes de aplicar la política)"),
  parrafo("Antes de aplicar la bucket policy, al intentar acceder al objeto directamente por su URL de API, S3 respondía con un error de acceso denegado, confirmando que el bloqueo de acceso público estaba activo y funcionando correctamente."),
  new Paragraph({
    children: [
      new TextRun({ text: "→ INSERTAR CAPTURA: ", bold: true, color: "D63031", size: 22, font: "Calibri" }),
      new TextRun({ text: "Navegador mostrando AccessDenied al abrir la URL de objeto directo (antes de la política)", size: 22, font: "Calibri" }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "FFEAEA" },
    spacing: { before: 100, after: 200 },
    indent: { left: 200 },
  }),
  lineaVacia(),
  subtitulo("Sitio funcionando (después de aplicar la política)"),
  parrafo("Una vez aplicada la política de solo lectura y habilitado el website hosting, el sitio es accesible desde cualquier navegador en la siguiente URL:"),
  code("http://sitio-inventario-cloud-los-rojos.s3-website-us-east-1.amazonaws.com"),
  new Paragraph({
    children: [
      new TextRun({ text: "→ INSERTAR CAPTURA: ", bold: true, color: "D63031", size: 22, font: "Calibri" }),
      new TextRun({ text: "Navegador mostrando el sitio Inventario Nube con la URL visible en la barra de direcciones", size: 22, font: "Calibri" }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "FFEAEA" },
    spacing: { before: 100, after: 200 },
    indent: { left: 200 },
  }),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Sección 5: Criterio 5 — Comparación con el servidor ──────────────────────
const seccion5 = [
  titulo("5. Comparación con el servidor de la Práctica 03 (15 pts)"),
  parrafo("A continuación se presentan dos diferencias observadas entre servir contenido con un servidor EC2 (Práctica 03) y servir contenido directamente desde Amazon S3 (Práctica 04):"),
  lineaVacia(),
  tablaDatos([
    ["Aspecto", "Práctica 03 — EC2 + Nginx", "Práctica 04 — S3 estático"],
    [
      "Lo que se administra",
      "Instancia EC2, sistema operativo, Nginx, actualizaciones de seguridad, PM2 y logs del servidor.",
      "Solo archivos y política del bucket. S3 es completamente gestionado por AWS. Sin SO, sin procesos, sin parches.",
    ],
    [
      "Con 1,000 usuarios simultáneos",
      "La instancia t3.micro puede saturarse (CPU, memoria, conexiones). Requiere escalar manualmente o configurar un Load Balancer.",
      "S3 escala automáticamente sin configuración adicional. AWS distribuye las peticiones en infraestructura global. No hay servidor que saturar.",
    ],
  ]),
  lineaVacia(),
  subtitulo("Análisis"),
  new Paragraph({
    children: [
      new TextRun({ text: "El servidor EC2 es necesario ", bold: true, size: 24, font: "Calibri" }),
      new TextRun({ text: "para la API REST y la lógica del negocio: consultas a la base de datos, autenticación JWT, cálculo de reportes y registro de movimientos. Esas operaciones dependen de cómputo real.", size: 24, font: "Calibri" }),
    ], spacing: { after: 160 }, alignment: AlignmentType.JUSTIFIED,
  }),
  new Paragraph({
    children: [
      new TextRun({ text: "Amazon S3 es suficiente ", bold: true, size: 24, font: "Calibri" }),
      new TextRun({ text: "para contenido que no varía por usuario, como esta página informativa. Usar EC2 para servir un HTML estático desperdiciaría cómputo y elevaría el costo sin ningún beneficio real.", size: 24, font: "Calibri" }),
    ], spacing: { after: 160 }, alignment: AlignmentType.JUSTIFIED,
  }),
  parrafo("La separación estático/dinámico es una práctica estándar de arquitectura en la nube: S3 sirve lo que no cambia, EC2 procesa lo que sí cambia. Esta decisión reduce costos, mejora la disponibilidad del sitio informativo (SLA de S3: 99.99%) y descarga trabajo del servidor de la API."),
  new Paragraph({ children: [new PageBreak()] }),
];

// ── Sección 6: Criterio 6 — Ciclo de vida ────────────────────────────────────
const seccion6 = [
  titulo("6. Regla de ciclo de vida configurada (10 pts)"),
  parrafo("Se configuró una regla de ciclo de vida que mueve automáticamente los objetos del bucket a la clase de almacenamiento S3 Standard-IA (Infrequent Access) después de 30 días, reduciendo el costo de almacenamiento para objetos que ya no se acceden con frecuencia."),
  lineaVacia(),
  subtitulo("Comando ejecutado"),
  code("aws s3api get-bucket-lifecycle-configuration --bucket sitio-inventario-cloud-los-rojos"),
  lineaVacia(),
  subtitulo("Configuración de la regla"),
  code("{"),
  code('  "Rules": ['),
  code("    {"),
  code('      "ID":     "mover-a-standard-ia-30dias",'),
  code('      "Status": "Enabled",'),
  code('      "Filter": { "Prefix": "" },'),
  code('      "Transitions": ['),
  code("        {"),
  code('          "Days": 30,'),
  code('          "StorageClass": "STANDARD_IA"'),
  code("        }"),
  code("      ]"),
  code("    }"),
  code("  ]"),
  code("}"),
  lineaVacia(),
  subtitulo("Análisis de costos"),
  tablaDatos([
    ["Parámetro", "S3 Standard", "S3 Standard-IA"],
    ["Almacenamiento (us-east-1)", "$0.023 / GB / mes", "$0.0125 / GB / mes"],
    ["Ahorro en almacenamiento", "—", "~46% menos"],
    ["Costo de recuperación", "Sin cargo adicional", "$0.01 / GB recuperado"],
    ["Aplicación práctica", "Objetos accedidos frecuentemente", "Objetos sin acceso > 30 días"],
  ]),
  lineaVacia(),
  parrafo("Para el sitio informativo, que después de la entrega del parcial tendrá muy poco tráfico, la transición a Standard-IA reduce el costo de almacenamiento en aproximadamente 46%. El costo de recuperación solo aplica si alguien descarga el objeto, lo cual es despreciable para este caso de uso."),
  new Paragraph({
    children: [
      new TextRun({ text: "→ INSERTAR CAPTURA: ", bold: true, color: "D63031", size: 22, font: "Calibri" }),
      new TextRun({ text: "CloudShell con salida de get-bucket-lifecycle-configuration mostrando la regla activa", size: 22, font: "Calibri" }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "FFEAEA" },
    spacing: { before: 100, after: 200 },
    indent: { left: 200 },
  }),
];

// ── Ensamblar y generar ───────────────────────────────────────────────────────
const doc = new Document({
  creator: "Los Rojos — Cómputo en la Nube 2026",
  title: "Práctica 04 — Almacenamiento de objetos y publicación del sitio del proyecto",
  description: "Evidencia P04 · Equipo Los Rojos · 30 sep 2026",
  sections: [{
    properties: {},
    children: [
      ...portada,
      ...seccion1,
      ...seccion2,
      ...seccion3,
      ...seccion4,
      ...seccion5,
      ...seccion6,
    ],
  }],
});

const outPath = path.join(__dirname, "..", "P04_LosRojos_30sep2026.docx");

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outPath, buffer);
  console.log("✔ Documento generado:", outPath);
}).catch((err) => {
  console.error("✗ Error:", err.message);
});
