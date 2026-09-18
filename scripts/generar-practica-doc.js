/**
 * Genera el documento Word de la Práctica AWS — Equipo Los Rojos
 * Uso: node scripts/generar-practica-doc.js
 */

const {
  Document,
  Packer,
  Paragraph,
  Table,
  TableRow,
  TableCell,
  TextRun,
  HeadingLevel,
  WidthType,
  AlignmentType,
  BorderStyle,
  ShadingType,
  UnderlineType,
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── Colores ──────────────────────────────────────────────────────────────────
const COLOR = {
  headerBg: "2D3748",   // gris oscuro
  headerFg: "FFFFFF",   // blanco
  rowAlt:   "F7FAFC",   // gris muy claro
  warning:  "E53E3E",   // rojo advertencia
  accent:   "2B6CB0",   // azul
  border:   "CBD5E0",
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function bold(text, color) {
  return new TextRun({ text, bold: true, color: color || "000000" });
}

function normal(text) {
  return new TextRun({ text });
}

function mono(text) {
  return new TextRun({ text, font: "Courier New", size: 18 });
}

function heading(text, level) {
  return new Paragraph({
    text,
    heading: level,
    spacing: { before: 240, after: 120 },
  });
}

function bodyParagraph(runs, spacing) {
  return new Paragraph({
    children: Array.isArray(runs) ? runs : [normal(runs)],
    spacing: spacing || { before: 80, after: 80 },
  });
}

function warningParagraph(text) {
  return new Paragraph({
    children: [
      new TextRun({ text: "⚠️  ", bold: true }),
      new TextRun({ text, color: COLOR.warning, bold: true }),
    ],
    spacing: { before: 100, after: 100 },
    border: {
      left: { style: BorderStyle.THICK, size: 6, color: COLOR.warning },
    },
    indent: { left: 200 },
  });
}

function tableHeaderCell(text) {
  return new TableCell({
    children: [
      new Paragraph({
        children: [bold(text, COLOR.headerFg)],
        alignment: AlignmentType.CENTER,
        spacing: { before: 80, after: 80 },
      }),
    ],
    shading: { type: ShadingType.SOLID, fill: COLOR.headerBg },
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
  });
}

function tableCell(text, isAlt, isMono) {
  return new TableCell({
    children: [
      new Paragraph({
        children: [isMono ? mono(text) : normal(text)],
        spacing: { before: 60, after: 60 },
      }),
    ],
    shading: isAlt
      ? { type: ShadingType.SOLID, fill: COLOR.rowAlt }
      : undefined,
    margins: { top: 60, bottom: 60, left: 120, right: 120 },
  });
}

function buildTable(headers, rows) {
  const colCount = headers.length;
  const colWidth = Math.floor(9000 / colCount);

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({
        tableHeader: true,
        children: headers.map((h) => tableHeaderCell(h)),
      }),
      ...rows.map((row, rowIdx) =>
        new TableRow({
          children: row.map((cell, colIdx) =>
            tableCell(
              cell.text !== undefined ? cell.text : cell,
              rowIdx % 2 === 1,
              cell.mono || false
            )
          ),
        })
      ),
    ],
  });
}

// ── Contenido del documento ───────────────────────────────────────────────────

const doc = new Document({
  sections: [
    {
      properties: {},
      children: [

        // ── Título principal ─────────────────────────────────────────────────
        new Paragraph({
          children: [
            bold("Práctica 01 — Configuración de Cuenta AWS", COLOR.accent),
          ],
          heading: HeadingLevel.TITLE,
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 160 },
        }),
        new Paragraph({
          children: [normal("Equipo: Los Rojos  |  Materia: Cómputo en la Nube  |  FIM — Ingeniería de Software")],
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 400 },
        }),

        // ── 1. Tabla de identidades ──────────────────────────────────────────
        heading("1. Tabla de Identidades del Equipo", HeadingLevel.HEADING_1),
        bodyParagraph(
          "Identidades IAM creadas en la cuenta AWS del equipo. Cada integrante debe activar MFA en su primer inicio de sesión."
        ),

        buildTable(
          ["Integrante", "Usuario IAM", "Grupos IAM", "Permisos"],
          [
            [
              "López Payán Kevin Ricardo",
              { text: "usr-kevin", mono: true },
              "grp-documentacion, grp-arquitectura",
              "ReadOnlyAccess",
            ],
            [
              "Flores Guevara Ángel Gabriel",
              { text: "usr-angel", mono: true },
              "grp-seguridad-costos, grp-desarrollo",
              "AdministratorAccess + ReadOnlyAccess",
            ],
          ]
        ),

        warningParagraph(
          "Ambos integrantes deben activar MFA en su propio usuario IAM en el primer inicio de sesión (Paso 06)."
        ),

        // ── 2. Esquema de etiquetas ──────────────────────────────────────────
        heading("2. Esquema de Etiquetas Acordado", HeadingLevel.HEADING_1),
        bodyParagraph(
          "Las siguientes etiquetas son obligatorias para todos los recursos AWS creados durante el semestre."
        ),

        buildTable(
          ["Clave", "Valor"],
          [
            [{ text: "proyecto", mono: true }, { text: "inventario-cloud", mono: true }],
            [{ text: "equipo",   mono: true }, { text: "los-rojos",        mono: true }],
            [{ text: "ambiente", mono: true }, { text: "dev",              mono: true }],
          ]
        ),

        heading("Ejemplo — AWS CLI", HeadingLevel.HEADING_2),
        new Paragraph({
          children: [
            mono("--tags Key=proyecto,Value=inventario-cloud \\"),
          ],
          spacing: { before: 60, after: 0 },
          indent: { left: 360 },
        }),
        new Paragraph({
          children: [mono("       Key=equipo,Value=los-rojos \\")],
          spacing: { before: 0, after: 0 },
          indent: { left: 360 },
        }),
        new Paragraph({
          children: [mono("       Key=ambiente,Value=dev")],
          spacing: { before: 0, after: 120 },
          indent: { left: 360 },
        }),

        heading("Ejemplo — CloudFormation / SAM", HeadingLevel.HEADING_2),
        new Paragraph({
          children: [mono("Tags:")],
          spacing: { before: 60, after: 0 },
          indent: { left: 360 },
        }),
        new Paragraph({
          children: [mono("  proyecto: inventario-cloud")],
          spacing: { before: 0, after: 0 },
          indent: { left: 360 },
        }),
        new Paragraph({
          children: [mono("  equipo:   los-rojos")],
          spacing: { before: 0, after: 0 },
          indent: { left: 360 },
        }),
        new Paragraph({
          children: [mono("  ambiente: dev")],
          spacing: { before: 0, after: 120 },
          indent: { left: 360 },
        }),

        // ── 3. Nota de cuenta ────────────────────────────────────────────────
        heading("3. Nota de Cuenta del Equipo", HeadingLevel.HEADING_1),

        buildTable(
          ["Campo", "Valor"],
          [
            ["Correo del equipo",              { text: "angek234122@gmail.com", mono: true }],
            ["Responsable del medio de pago",  "Flores Guevara Ángel Gabriel"],
            ["Fecha límite del plan gratuito", "⚠️ COMPLETAR — ver instrucción abajo"],
          ]
        ),

        warningParagraph(
          "Acción requerida: ingresar a Consola AWS → Billing → Free Tier y anotar aquí la fecha exacta de expiración del plan gratuito de 12 meses. El plan comienza el día del registro de la cuenta."
        ),
        bodyParagraph(
          "Si el plan está próximo a vencer, notificar a todos los integrantes con al menos 15 días de anticipación."
        ),

        // ── 4. Restricciones del plan (Paso 11) ─────────────────────────────
        heading("4. Restricciones del Plan Gratuito — Paso 11", HeadingLevel.HEADING_1),
        bodyParagraph(
          "Las siguientes tres restricciones fueron registradas en el Paso 11 de la práctica y aplican durante toda la vigencia del plan gratuito."
        ),

        buildTable(
          ["#", "Restricción", "Impacto / Acción"],
          [
            [
              "1",
              "No permite Reserved Instances ni Savings Plans",
              "Usar solo instancias On-Demand; no comprometerse a planes de largo plazo.",
            ],
            [
              "2",
              "No da acceso al AWS Marketplace de soluciones de terceros",
              "Las soluciones de terceros del Marketplace no están disponibles en el plan gratuito.",
            ],
            [
              "3",
              "Unirse a una AWS Organization cancela los créditos de inmediato",
              "El equipo NO debe aceptar invitaciones a Organizations mientras conserve créditos.",
            ],
          ]
        ),

        // ── Pie de página ────────────────────────────────────────────────────
        new Paragraph({
          children: [
            normal("Documento generado automáticamente a partir del spec "),
            mono(".kiro/specs/practica-aws-equipo-doc/requirements.md"),
          ],
          spacing: { before: 600, after: 0 },
          alignment: AlignmentType.CENTER,
        }),
      ],
    },
  ],
});

// ── Guardar ───────────────────────────────────────────────────────────────────
const outPath = path.join(__dirname, "..", "practica-aws-equipo-doc.docx");

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outPath, buffer);
  console.log(`✅ Documento generado: ${outPath}`);
});
