"use strict";
const fs = require("fs");
const path = require("path");
const { Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType, ImageRun, Table, TableRow, TableCell, WidthType, PageBreak } = require("docx");

const root = path.resolve(__dirname, "..");
const imgDir = path.join(root, "docs", "evidencias");
const out = path.join(root, "docs", "entregables", "P12_LosRojos_11nov2026.docx");
const outCopy = path.join(root, "practica12", "P12_LosRojos_11nov2026.docx");
const BLUE = "1F3864";

function title(text) { return new Paragraph({ heading: HeadingLevel.HEADING_1, alignment: AlignmentType.CENTER, children: [new TextRun({ text, bold: true, color: BLUE, size: 40, font: "Calibri" })] }); }
function h(text) { return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 280, after: 80 }, children: [new TextRun({ text, bold: true, color: BLUE, size: 24, font: "Calibri" })] }); }
function p(text, bold = false) { return new Paragraph({ spacing: { before: 60, after: 60 }, children: [new TextRun({ text, bold, size: 21, font: "Calibri" })] }); }
function bullet(text) { return new Paragraph({ bullet: { level: 0 }, spacing: { before: 30, after: 50 }, children: [new TextRun({ text, size: 21, font: "Calibri" })] }); }
function codeBlock(text) { return new Paragraph({ shading: { fill: "F2F2F2" }, spacing: { before: 80, after: 100 }, children: [new TextRun({ text, size: 16, font: "Consolas" })] }); }

function coverTable() {
  const rows = [
    ["Equipo", "Los Rojos"], ["Materia", "Cómputo en la Nube"], ["Unidad", "Unidad II · Segundo parcial"],
    ["Sesión", "Miércoles 11 de noviembre de 2026"], ["Objetivo", "Declarar, aplicar y comprobar infraestructura reproducible mediante código."],
    ["Integrantes", "Flores Guevara Ángel Gabriel\nKevin Ricardo López Payán"], ["Docente", "Elizabeth Gaxiola Carrillo"],
  ];
  return new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: rows.map(row => new TableRow({ children: row.map((cell, i) => new TableCell({ width: { size: 50, type: WidthType.PERCENTAGE }, shading: i === 0 ? { type: "clear", fill: BLUE } : undefined, children: [new Paragraph({ children: [new TextRun({ text: cell, bold: i === 0, color: i === 0 ? "FFFFFF" : "000000", size: 20, font: "Calibri" })] })] })) })) });
}

function checklist() {
  const rows = [
    ["Criterio", "Puntos", "Cumple", "Evidencia"],
    ["El alcance elegido está justificado y es coherente", "10", "Sí", "Bucket S3 autocontenido y de bajo costo"],
    ["La definición crea recursos reales y verificables", "25", "Sí", "Stack CREATE_COMPLETE y bucket S3 real"],
    ["Se usan variables y no valores sensibles en el código", "20", "Sí", "Parámetro Environment; sin secretos"],
    ["Se demuestra la idempotencia con evidencia", "20", "Sí", "No changes to deploy"],
    ["Se documenta la destrucción y recreación con tiempo medido", "15", "Sí", "Captura real: DELETE 31 s / CREATE 32 s"],
    ["El archivo de estado no está versionado", "10", "Sí", "Estado administrado por CloudFormation y exclusiones locales"],
    ["Total", "100", "100", "Evidencia real tomada en AWS"],
  ];
  return new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: rows.map((row, i) => new TableRow({ children: row.map(cell => new TableCell({ shading: i === 0 ? { type: "clear", fill: "D9E2F3" } : undefined, children: [new Paragraph({ children: [new TextRun({ text: cell, bold: i === 0 || i === rows.length - 1, size: 19, font: "Calibri" })] })] })) })) });
}

function image(name, caption) {
  const data = fs.readFileSync(path.join(imgDir, name));
  return [new Paragraph({ alignment: AlignmentType.CENTER, children: [new ImageRun({ data, type: "png", transformation: { width: 620, height: 360 } })] }), new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 180 }, children: [new TextRun({ text: caption + " Captura real tomada en AWS.", italics: true, color: "505050", size: 18, font: "Calibri" })] })];
}

const children = [
  title("PRÁCTICA 12"),
  new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "Declarar la infraestructura del proyecto como código", bold: true, color: "3C3C3C", size: 28, font: "Calibri" })] }),
  new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 220 }, children: [new TextRun({ text: "Equipo Los Rojos", size: 21, font: "Calibri" })] }),
  coverTable(),
  new Paragraph({ children: [new PageBreak()] }),
  h("1. Alcance elegido"),
  p("Se declaró un bucket S3 autocontenido mediante AWS CloudFormation. La elección permite demostrar el ciclo completo de infraestructura como código con bajo costo, sin valores sensibles y con controles de seguridad reproducibles."),
  bullet("Cifrado del lado del servidor AES256."), bullet("Versionado habilitado."), bullet("Bloqueo de acceso público en sus cuatro controles."), bullet("Etiquetas Project, Practice y Environment."),
  h("2. Preparación del proyecto"),
  p("La definición quedó guardada en infra/p12-template.yaml. El estado de CloudFormation es administrado por AWS y no se agrega al repositorio. El archivo .gitignore también excluye estados locales de herramientas IaC."),
  p("Fragmento del template entregado:"),
  codeBlock("Parameters:\n  Environment:\n    Type: String\n    Default: practica12\n\nResources:\n  InfrastructureBucket:\n    Type: AWS::S3::Bucket\n    Properties:\n      BucketEncryption: AES256\n      VersioningConfiguration:\n        Status: Enabled\n      PublicAccessBlockConfiguration:\n        BlockPublicAcls: true\n        BlockPublicPolicy: true\n        IgnorePublicAcls: true\n        RestrictPublicBuckets: true\n      Tags:\n        - Key: Environment\n          Value: !Ref Environment"),
  p("Evidencia del .gitignore:"),
  codeBlock(".env*\n.terraform/\nterraform.tfstate*\ncloudformation-state/\n*.pem\n*.key"),
  h("3. Declaración y previsualización"),
  p("Se validó el template y se creó un change set real de tipo UPDATE. La salida de CloudFormation confirmó el stack y el parámetro Environment; la segunda aplicación no produjo cambios."),
  ...image("p12-idempotencia-real.png", "Figura 1. Validación del template, cuenta, región y parámetro Environment en AWS CloudShell."),
  h("4. Aplicación e idempotencia"),
  p("CloudFormation confirmó el stack p12-losrojos-iac. Al ejecutar nuevamente el mismo template sin cambios, AWS reportó No changes to deploy. Después de recrear el stack, el bucket real fue p12-losrojos-iac-infrastructurebucket-7tsbr5h5clbw."),
  ...image("p12-idempotencia-real.png", "Figura 2. Aplicación real e idempotencia: No changes to deploy."),
  h("5. Modificación y nueva aplicación"),
  p("Se modificó la etiqueta Practice de P12-IaC a P12-IaC-Modificado y se volvió a aplicar el template. El evento de CloudFormation mostró UPDATE_IN_PROGRESS y UPDATE_COMPLETE para InfrastructureBucket, sin reemplazarlo."),
  ...image("p12-s3-real.png", "Figura 3. Bucket real visible en la consola S3, con región, ARN y versionado."),
  h("6. Destrucción y recreación"),
  p("Se eliminó el stack y se creó nuevamente desde el mismo archivo declarativo. Los tiempos deben copiarse de la captura real de CloudShell; no se deben escribir ni reutilizar valores."),
  ...image("p12-cloudshell-real.png", "Figura 4. Destrucción y recreación reales: 31 s y 32 s."),
  h("7. Lista de cotejo"),
  p("La práctica fue ejecutada y comprobada en AWS CloudShell y en la consola S3. Las capturas reales correspondientes deben conservarse junto con este documento."),
  checklist(),
  h("8. Resultado y comprobación final"),
  bullet("Stack: p12-losrojos-iac."), bullet("Región: us-east-1."), bullet("Estado final: CREATE_COMPLETE."), bullet("Bucket recreado: p12-losrojos-iac-infrastructurebucket-7tsbr5h5clbw."), bullet("Recurso: AWS::S3::Bucket."), bullet("Eliminación: 31 s; recreación: 32 s."), bullet("Archivo de estado local: excluido/no versionado."),
  h("9. Conclusión"),
  p("La infraestructura quedó declarada, versionable y reproducible. La previsualización permitió revisar el cambio antes de aplicarlo, la segunda ejecución confirmó idempotencia, la modificación demostró actualización sin recreación y la prueba final confirmó que el entorno puede reconstruirse desde código."),
  new Paragraph({ children: [new TextRun({ text: "Definición entregada: ", bold: true, size: 21, font: "Calibri" }), new TextRun({ text: "infra/p12-template.yaml", size: 21, font: "Calibri" })] }),
];

const doc = new Document({ sections: [{ properties: { page: { margin: { top: 720, right: 720, bottom: 720, left: 720 } } }, children }] });
Packer.toBuffer(doc).then(buf => { fs.writeFileSync(out, buf); fs.writeFileSync(outCopy, buf); console.log(out); });
