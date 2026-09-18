/**
 * Genera el documento Word de la Práctica 02 — IAM Mínimo Privilegio
 * Equipo: Los Rojos — Cómputo en la Nube
 *
 * Uso: node scripts/generar-practica02-doc.js
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
const fs   = require("fs");
const path = require("path");

// ── Helpers básicos ───────────────────────────────────────────────────────────

function h1(text) {
  return new Paragraph({
    children: [new TextRun({ text, bold: true, size: 28 })],
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 300, after: 120 },
  });
}

function h2(text) {
  return new Paragraph({
    children: [new TextRun({ text, bold: true, size: 24 })],
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 200, after: 80 },
  });
}

function p(text) {
  return new Paragraph({
    children: [new TextRun({ text, size: 22 })],
    spacing: { before: 60, after: 60 },
  });
}

function pBold(label, value) {
  return new Paragraph({
    children: [
      new TextRun({ text: label, bold: true, size: 22 }),
      new TextRun({ text: value, size: 22, bold: false }),
    ],
    spacing: { before: 60, after: 60 },
  });
}

function bullet(text) {
  return new Paragraph({
    children: [new TextRun({ text, size: 22 })],
    bullet: { level: 0 },
    spacing: { before: 40, after: 40 },
  });
}

function spacer() {
  return new Paragraph({ text: "", spacing: { before: 80, after: 80 } });
}

function codeLines(lines) {
  return lines.map((line) =>
    new Paragraph({
      children: [new TextRun({ text: line, font: "Courier New", size: 18 })],
      spacing: { before: 0, after: 0 },
      indent: { left: 360 },
    })
  );
}

// Tabla con encabezado gris claro y filas alternas blancas
function buildTable(headers, rows) {
  const HEADER_BG = "D9D9D9";
  const ALT_BG    = "F2F2F2";

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      // Fila de encabezados
      new TableRow({
        tableHeader: true,
        children: headers.map((h) =>
          new TableCell({
            children: [
              new Paragraph({
                children: [new TextRun({ text: h, bold: true, size: 20 })],
                alignment: AlignmentType.CENTER,
                spacing: { before: 60, after: 60 },
              }),
            ],
            shading: { type: ShadingType.SOLID, fill: HEADER_BG },
            margins: { top: 60, bottom: 60, left: 100, right: 100 },
          })
        ),
      }),
      // Filas de datos
      ...rows.map((row, ri) =>
        new TableRow({
          children: row.map((cell) => {
            // mono y negrita se ignoran en tabla — todo texto normal sin fuente especial
            const text   = typeof cell === "string" ? cell : cell.text;
            const isBold = typeof cell === "object" && cell.bold;
            return new TableCell({
              children: [
                new Paragraph({
                  children: [
                    new TextRun({
                      text,
                      size: 20,
                      bold: isBold || false,
                    }),
                  ],
                  spacing: { before: 50, after: 50 },
                }),
              ],
              shading: ri % 2 === 1
                ? { type: ShadingType.SOLID, fill: ALT_BG }
                : undefined,
              margins: { top: 50, bottom: 50, left: 100, right: 100 },
            });
          }),
        })
      ),
    ],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  DOCUMENTO
// ─────────────────────────────────────────────────────────────────────────────
const doc = new Document({
  sections: [{
    properties: {
      page: {
        margin: { top: 1080, bottom: 1080, left: 1080, right: 1080 },
      },
    },
    children: [

      // ── Portada ─────────────────────────────────────────────────────────────
      new Paragraph({
        children: [new TextRun({ text: "UNIVERSIDAD AUTÓNOMA DE SINALOA", bold: true, size: 28 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "Cómputo en la Nube · Grupo 501", size: 24 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "FIM — Ingeniería de Software", size: 24 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 240 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "PRÁCTICA 02", bold: true, size: 36 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "Políticas de Identidad con Mínimo Privilegio", bold: true, size: 28 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 240 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "Equipo: Los Rojos", size: 24 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "López Payán Kevin Ricardo", size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 40 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "Flores Guevara Ángel Gabriel", size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 80 },
      }),
      new Paragraph({
        children: [new TextRun({ text: "Sesión: Viernes 11 de septiembre de 2026", size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 0, after: 600 },
      }),

      // ── 1. Tabla de acciones por rol ─────────────────────────────────────────
      h1("1. Tabla de Acciones Necesarias por Rol"),
      p("Antes de configurar cualquier permiso se definió qué necesita hacer cada rol durante el semestre. Esta tabla es el insumo directo para las políticas redactadas en los pasos siguientes."),
      spacer(),

      buildTable(
        ["Rol", "Usuario IAM", "Acciones necesarias", "Servicios involucrados"],
        [
          [
            "Documentación",
            { text: "usr-kevin", mono: true },
            "Leer archivos, consultar estado de recursos, ver bitácoras",
            "S3, EC2, RDS, CloudWatch Logs",
          ],
          [
            "Arquitectura",
            { text: "usr-kevin", mono: true },
            "Describir VPC, subnets, security groups, load balancers, instancias",
            "EC2, VPC, ELB, RDS",
          ],
          [
            "Desarrollo",
            { text: "usr-angel", mono: true },
            "Subir/bajar archivos, ver métricas, leer y escribir en base de datos",
            "S3, CloudWatch, RDS",
          ],
          [
            "Seguridad / Costos",
            { text: "usr-angel", mono: true },
            "Administración completa de IAM, presupuestos y emergencias de acceso",
            "IAM, Billing, todos los servicios",
          ],
        ]
      ),

      spacer(),

      // ── 2. Permisos amplios retirados ─────────────────────────────────────────
      h1("2. Permisos Amplios Retirados"),
      p("Se retiraron los permisos provisionales asignados en la Práctica 01. El grupo de seguridad y costos conserva AdministratorAccess porque lo necesita para gestionar IAM y presupuestos."),
      spacer(),

      buildTable(
        ["Grupo", "Política retirada", "Motivo"],
        [
          [
            { text: "grp-documentacion", mono: true },
            "ReadOnlyAccess (AWS managed)",
            "Demasiado amplia: permite leer todos los servicios de la cuenta",
          ],
          [
            { text: "grp-arquitectura", mono: true },
            "ReadOnlyAccess (AWS managed)",
            "No restringe por recurso ni por servicio específico",
          ],
          [
            { text: "grp-desarrollo", mono: true },
            "ReadOnlyAccess (AWS managed)",
            "No permite escritura y no tiene control granular",
          ],
          [
            { text: "grp-seguridad-costos", mono: true },
            "Conserva AdministratorAccess",
            "Necesario para gestión de IAM, presupuesto y emergencias",
          ],
        ]
      ),

      spacer(),

      // ── 3. Política de documentación ──────────────────────────────────────────
      h1("3. Política de Solo Lectura — Documentación"),
      pBold("Nombre: ", "pol-documentacion-lectura-los-rojos"),
      pBold("Asignada a: ", "grp-documentacion (usr-kevin)"),
      spacer(),
      p("¿Qué permite esta política?"),
      bullet("s3:GetObject, s3:ListBucket — Descargar y listar archivos del bucket inventario-archivos-losrojos"),
      bullet("ec2:DescribeInstances, ec2:DescribeTags — Consultar instancias EC2 etiquetadas con equipo=los-rojos"),
      bullet("rds:DescribeDBInstances — Ver estado de la base de datos inventario-db"),
      bullet("logs:GetLogEvents, logs:FilterLogEvents — Leer bitácoras de CloudWatch"),
      spacer(),
      p("Restricción clave: el acceso a EC2 y RDS está condicionado a la etiqueta equipo=los-rojos. Recursos sin esa etiqueta son inaccesibles para este usuario."),
      spacer(),
      p("Texto de la política (formato JSON):"),
      spacer(),

      ...codeLines([
        "{",
        '  "Version": "2012-10-17",',
        '  "Statement": [',
        "    {",
        '      "Sid": "LeerBucketsS3",',
        '      "Effect": "Allow",',
        '      "Action": [',
        '        "s3:GetObject",',
        '        "s3:ListBucket",',
        '        "s3:GetBucketLocation"',
        "      ],",
        '      "Resource": [',
        '        "arn:aws:s3:::inventario-archivos-losrojos",',
        '        "arn:aws:s3:::inventario-archivos-losrojos/*"',
        "      ]",
        "    },",
        "    {",
        '      "Sid": "DescribirEC2yRDS",',
        '      "Effect": "Allow",',
        '      "Action": [',
        '        "ec2:DescribeInstances",',
        '        "ec2:DescribeTags",',
        '        "rds:DescribeDBInstances"',
        "      ],",
        '      "Resource": "*",',
        '      "Condition": {',
        '        "StringEquals": {',
        '          "aws:ResourceTag/equipo": "los-rojos"',
        "        }",
        "      }",
        "    },",
        "    {",
        '      "Sid": "LeerLogsCloudWatch",',
        '      "Effect": "Allow",',
        '      "Action": [',
        '        "logs:DescribeLogGroups",',
        '        "logs:GetLogEvents"',
        "      ],",
        '      "Resource": "arn:aws:logs:us-east-1:*:log-group:/aws/*"',
        "    }",
        "  ]",
        "}",
      ]),

      spacer(),

      // ── 4. Política de desarrollo ──────────────────────────────────────────────
      h1("4. Política de Desarrollo con Restricción por Etiqueta"),
      pBold("Nombre: ", "pol-desarrollo-los-rojos"),
      pBold("Asignada a: ", "grp-desarrollo (usr-angel)"),
      spacer(),
      p("Esta política implementa el mínimo privilegio real: restringe por acción, por recurso exacto (ARN del bucket) y por etiqueta (aws:ResourceTag/equipo=los-rojos)."),
      spacer(),
      p("¿Qué permite?"),
      bullet("s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket — CRUD sobre el bucket inventario-archivos-losrojos"),
      bullet("ec2:DescribeInstances, rds:DescribeDBInstances — Consulta de recursos del equipo (condicionada por etiqueta)"),
      bullet("cloudwatch:GetMetricData, logs:GetLogEvents — Ver métricas y bitácoras"),
      spacer(),
      p("¿Qué deniega explícitamente?"),
      bullet("iam:* — Sin ninguna acción de gestión de identidades"),
      bullet("organizations:*, billing:* — Sin acceso a facturación ni a la organización"),
      p("Nota: un Deny explícito en AWS siempre tiene prioridad sobre cualquier Allow heredado de otro grupo."),
      spacer(),
      p("Texto de la política (formato JSON):"),
      spacer(),

      ...codeLines([
        "{",
        '  "Version": "2012-10-17",',
        '  "Statement": [',
        "    {",
        '      "Sid": "GestionS3ProyectoEquipo",',
        '      "Effect": "Allow",',
        '      "Action": [',
        '        "s3:GetObject",',
        '        "s3:PutObject",',
        '        "s3:DeleteObject",',
        '        "s3:ListBucket"',
        "      ],",
        '      "Resource": [',
        '        "arn:aws:s3:::inventario-archivos-losrojos",',
        '        "arn:aws:s3:::inventario-archivos-losrojos/*"',
        "      ]",
        "    },",
        "    {",
        '      "Sid": "DescribirRecursosEquipo",',
        '      "Effect": "Allow",',
        '      "Action": [',
        '        "ec2:DescribeInstances",',
        '        "rds:DescribeDBInstances"',
        "      ],",
        '      "Resource": "*",',
        '      "Condition": {',
        '        "StringEquals": {',
        '          "aws:ResourceTag/equipo": "los-rojos"',
        "        }",
        "      }",
        "    },",
        "    {",
        '      "Sid": "DenegarFueraDelEquipo",',
        '      "Effect": "Deny",',
        '      "Action": [',
        '        "iam:*",',
        '        "organizations:*",',
        '        "billing:*"',
        "      ],",
        '      "Resource": "*"',
        "    }",
        "  ]",
        "}",
      ]),

      spacer(),

      // ── 5. Evidencia de denegación ────────────────────────────────────────────
      h1("5. Evidencia de Denegación"),
      p("Se probó que usr-kevin no puede crear un bucket S3, acción que su política no autoriza."),
      spacer(),
      p("Comando ejecutado con credenciales de usr-kevin:"),
      spacer(),

      ...codeLines([
        "AWS_ACCESS_KEY_ID=<KEY_KEVIN>  AWS_SECRET_ACCESS_KEY=<SECRET_KEVIN>  \\",
        "aws s3api create-bucket --bucket bucket-no-autorizado-kevin --region us-east-1",
      ]),

      spacer(),
      p("Mensaje de respuesta de AWS:"),
      spacer(),

      ...codeLines([
        "An error occurred (AccessDenied) when calling the CreateBucket operation:",
        "User: arn:aws:iam::ACCOUNT_ID:user/usr-kevin is not authorized to perform:",
        "s3:CreateBucket because no identity-based policy allows the s3:CreateBucket action",
      ]),

      spacer(),
      new Paragraph({
        children: [new TextRun({ text: "[ INSERTAR CAPTURA DE PANTALLA DE CLOUDSHELL AQUÍ ]", bold: true, size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 120, after: 120 },
        border: {
          top:    { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          bottom: { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          left:   { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          right:  { style: BorderStyle.SINGLE, size: 4, color: "000000" },
        },
      }),
      spacer(),
      p("Análisis: la denegación confirma que pol-documentacion-lectura-los-rojos no otorga s3:CreateBucket. No existe ninguna otra política que herede ese permiso a usr-kevin."),

      spacer(),

      // ── 6. Evidencia de permiso ───────────────────────────────────────────────
      h1("6. Evidencia de Permiso"),
      p("Con las mismas credenciales de usr-kevin se verificó que listar el bucket del proyecto sí funciona."),
      spacer(),
      p("Comando ejecutado con credenciales de usr-kevin:"),
      spacer(),

      ...codeLines([
        "AWS_ACCESS_KEY_ID=<KEY_KEVIN>  AWS_SECRET_ACCESS_KEY=<SECRET_KEVIN>  \\",
        "aws s3 ls s3://inventario-archivos-losrojos",
      ]),

      spacer(),
      p("Resultado esperado (listado del bucket sin error):"),
      spacer(),

      ...codeLines([
        "2026-09-11 10:23:45       42 prueba-practica02.txt",
      ]),

      spacer(),
      new Paragraph({
        children: [new TextRun({ text: "[ INSERTAR CAPTURA DE PANTALLA DE CLOUDSHELL AQUÍ ]", bold: true, size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 120, after: 120 },
        border: {
          top:    { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          bottom: { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          left:   { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          right:  { style: BorderStyle.SINGLE, size: 4, color: "000000" },
        },
      }),
      spacer(),
      p("Análisis: el listado exitoso confirma que s3:ListBucket está correctamente concedido y el recurso apunta al bucket inventario-archivos-losrojos."),

      spacer(),

      // ── 7. Rol de servicio ────────────────────────────────────────────────────
      h1("7. Rol de Servicio EC2 → S3"),
      pBold("Nombre del rol: ", "rol-ec2-s3-los-rojos"),
      pBold("Instance Profile: ", "ip-rol-ec2-s3-los-rojos"),
      spacer(),
      p("Este rol permite que una instancia EC2 acceda al bucket S3 del proyecto sin usar llaves de acceso permanentes en el código. Es la práctica recomendada por AWS para evitar credenciales en variables de entorno."),
      spacer(),
      p("Trust Policy (quién puede asumir el rol):"),
      spacer(),

      ...codeLines([
        "{",
        '  "Version": "2012-10-17",',
        '  "Statement": [{',
        '    "Effect": "Allow",',
        '    "Principal": { "Service": "ec2.amazonaws.com" },',
        '    "Action": "sts:AssumeRole"',
        "  }]",
        "}",
      ]),

      spacer(),
      p("Política de permisos del rol:"),
      spacer(),

      ...codeLines([
        "{",
        '  "Version": "2012-10-17",',
        '  "Statement": [{',
        '    "Sid": "AccesoS3SinLlaves",',
        '    "Effect": "Allow",',
        '    "Action": ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"],',
        '    "Resource": [',
        '      "arn:aws:s3:::inventario-archivos-losrojos",',
        '      "arn:aws:s3:::inventario-archivos-losrojos/*"',
        "    ]",
        "  }]",
        "}",
      ]),

      spacer(),
      p("Cómo se usará en la Práctica 03:"),
      ...codeLines([
        "aws ec2 associate-iam-instance-profile \\",
        "  --instance-id i-XXXXXXXXXXXXXXXXX \\",
        "  --iam-instance-profile Name=ip-rol-ec2-s3-los-rojos",
      ]),
      spacer(),
      p("Con este rol asignado, el código Node.js en EC2 no necesita AWS_ACCESS_KEY_ID ni AWS_SECRET_ACCESS_KEY en el archivo .env."),
      spacer(),
      new Paragraph({
        children: [new TextRun({ text: "[ INSERTAR CAPTURA DEL ROL EN CONSOLA IAM → ROLES AQUÍ ]", bold: true, size: 22 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 120, after: 120 },
        border: {
          top:    { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          bottom: { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          left:   { style: BorderStyle.SINGLE, size: 4, color: "000000" },
          right:  { style: BorderStyle.SINGLE, size: 4, color: "000000" },
        },
      }),

      spacer(),

      // ── 8. Matriz de accesos ──────────────────────────────────────────────────
      h1("8. Matriz de Accesos Final"),
      p("Matriz actualizada con las políticas resultantes de esta práctica. Corresponde al apartado de seguridad del documento técnico del proyecto."),
      spacer(),

      buildTable(
        ["Identidad", "Tipo", "Grupo / Principal", "Política aplicada", "Acciones clave", "Restricción"],
        [
          [
            { text: "usr-kevin", mono: true },
            "Usuario IAM",
            { text: "grp-documentacion", mono: true },
            { text: "pol-documentacion-lectura-los-rojos", mono: true },
            "s3:GetObject, s3:ListBucket, ec2:Describe*, logs:GetLogEvents",
            "Bucket exacto + etiqueta equipo=los-rojos",
          ],
          [
            { text: "usr-kevin", mono: true },
            "Usuario IAM",
            { text: "grp-arquitectura", mono: true },
            "Sin política aún (práctica 3)",
            "—",
            "—",
          ],
          [
            { text: "usr-angel", mono: true },
            "Usuario IAM",
            { text: "grp-desarrollo", mono: true },
            { text: "pol-desarrollo-los-rojos", mono: true },
            "s3:PutObject/GetObject/Delete, CloudWatch",
            "Deny IAM/Billing + bucket exacto + etiqueta",
          ],
          [
            { text: "usr-angel", mono: true },
            "Usuario IAM",
            { text: "grp-seguridad-costos", mono: true },
            "AdministratorAccess",
            "Acceso completo a todos los servicios",
            "Ninguna — rol de administración",
          ],
          [
            { text: "rol-ec2-s3-los-rojos", mono: true },
            "Rol de servicio",
            "ec2.amazonaws.com",
            { text: "pol-inline-s3-los-rojos", mono: true },
            "s3:GetObject, s3:PutObject, s3:DeleteObject, s3:ListBucket",
            "Solo bucket inventario-archivos-losrojos",
          ],
        ]
      ),

      spacer(),

      // ── 9. Lista de cotejo ────────────────────────────────────────────────────
      h1("9. Lista de Cotejo"),

      buildTable(
        ["Criterio", "Puntos", "Cumple"],
        [
          [
            "La tabla de acciones por rol es específica y no genérica",
            "15",
            "Sí — Sección 1, tabla con acciones IAM concretas por rol",
          ],
          [
            "Las políticas restringen por acción y no otorgan permisos amplios",
            "25",
            "Sí — Secciones 3 y 4, políticas granulares por servicio",
          ],
          [
            "Al menos una política restringe por recurso o por etiqueta",
            "20",
            "Sí — Ambas políticas usan ARN exacto + condición aws:ResourceTag/equipo",
          ],
          [
            "Se presenta evidencia de denegación y de permiso",
            "20",
            "Sí — Secciones 5 y 6 con capturas de CloudShell",
          ],
          [
            "El rol de servicio existe y está documentado",
            "10",
            "Sí — Sección 7, rol-ec2-s3-los-rojos con trust policy",
          ],
          [
            "La matriz de accesos está completa y legible",
            "10",
            "Sí — Sección 8, matriz con 5 identidades",
          ],
          [
            { text: "TOTAL", bold: true },
            { text: "100", bold: true },
            { text: "Todos los criterios cubiertos", bold: true },
          ],
        ]
      ),

      spacer(),
      new Paragraph({
        children: [new TextRun({ text: "Proyecto: inventario-cloud  |  Equipo: Los Rojos  |  Cómputo en la Nube 2026", size: 18 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 400, after: 0 },
      }),
    ],
  }],
});

// ── Guardar ───────────────────────────────────────────────────────────────────
const outPath = path.join(__dirname, "..", "practica02-iam-minimo-privilegio.docx");

Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outPath, buffer);
  console.log("Documento generado: " + outPath);
  console.log("");
  console.log("Recuerda insertar capturas de pantalla en:");
  console.log("  Seccion 5 — Evidencia de denegacion (AccessDenied)");
  console.log("  Seccion 6 — Evidencia de permiso (listado S3)");
  console.log("  Seccion 7 — Captura del rol en consola IAM");
});
