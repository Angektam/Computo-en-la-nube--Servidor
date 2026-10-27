// =============================================================================
// generar-practica06-doc.js  — P06_LosRojos_13oct2026.docx
// Genera el reporte completo de la Práctica 6 con imágenes reales insertadas.
//
// IDs reales de la práctica:
//   VPC        : vpc-0a3c4f2dd9ea86a91
//   Subnet priv1: subnet-0b6549d5a7ccc669f  10.0.2.0/24  us-east-1b
//   Subnet priv2: subnet-0aaa291c3653ab724  10.0.3.0/24  us-east-1c
//   SG RDS     : sg-0734743659216075b
//   SG EC2     : sg-08467d2aba4777abe
//   RDS        : rds-inventario-cloud-los-rojos
//   Endpoint   : rds-inventario-cloud-los-rojos.citeqg0wepbd.us-east-1.rds.amazonaws.com
//   EC2        : i-099eccb4405920a1e   IP: 44.204.127.130
//
// Uso:  node scripts/generar-practica06-doc.js
// =============================================================================

"use strict";
const fs   = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType,
  PageBreak, VerticalAlign, ImageRun,
} = require("docx");

// ─── Paleta ───────────────────────────────────────────────────────────────────
const ROJO       = "C0392B";
const ROJO_CLARO = "FADBD8";
const GRIS_CLARO = "F2F3F4";
const NEGRO      = "1C1C1C";
const AZUL       = "1A5276";

// ─── Ruta de capturas ─────────────────────────────────────────────────────────
const CAPS_DIR = "C:\\Users\\angek\\OneDrive\\Imágenes\\practic a6";

// Capturas en orden cronológico (17 archivos)
const CAPTURAS = [
  "Captura de pantalla 2026-10-13 195551.png",  // 00 → Intento de conexión local (waiting)
  "Captura de pantalla 2026-10-13 195839.png",  // 01 → C1 parte superior (tabla RDS)
  "Captura de pantalla 2026-10-13 195846.png",  // 02 → C1 parte inferior (subredes + SG)
  "Captura de pantalla 2026-10-13 195945.png",  // 03 → RDS desplegada (bloque final)
  "Captura de pantalla 2026-10-13 200010.png",  // 04 → C2 acceso denegado PowerShell
  "Captura de pantalla 2026-10-13 200516.png",  // 05 → C5 respaldos tabla RDS
  "Captura de pantalla 2026-10-13 201216.png",  // 06 → C5 análisis RPO
  "Captura de pantalla 2026-10-13 201223.png",  // 07 → C5 error tildes (contexto)
  "Captura de pantalla 2026-10-13 201304.png",  // 08 → C4 esquema + datos parte 1
  "Captura de pantalla 2026-10-13 201418.png",  // 09 → C4 tablas creadas + INSERT
  "Captura de pantalla 2026-10-13 201452.png",  // 10 → C3 conexión exitosa psql + conninfo
  "Captura de pantalla 2026-10-13 201705.png",  // 11 → SCP schema al EC2
  "Captura de pantalla 2026-10-13 201941.png",  // 12 → C4 consulta productos JOIN
  "Captura de pantalla 2026-10-13 201950.png",  // 13 → C3 prompt inventario=>
  "Captura de pantalla 2026-10-13 202152.png",  // 14 → nc succeeded + psql conectando
  "Captura de pantalla 2026-10-13 202157.png",  // 15 → apt-get install postgresql-client
  "Captura de pantalla 2026-10-13 202227.png",  // 16 → SSH desde PowerShell
];

function img(index, descripcion, w = 540, h = 280) {
  const archivo = CAPTURAS[index];
  const ruta = path.join(CAPS_DIR, archivo);
  if (!fs.existsSync(ruta)) {
    console.warn(`  ⚠  No encontrada: ${ruta}`);
    return marcadorFoto(index + 1, descripcion);
  }
  const data = fs.readFileSync(ruta);
  return new Paragraph({
    children: [new ImageRun({ data, transformation: { width: w, height: h }, type: "png" })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 60, after: 60 },
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
const r  = (t, opts = {}) => new TextRun({ text: t, font: "Calibri", size: 22, color: NEGRO, ...opts });
const rb = (t, color = NEGRO) => r(t, { bold: true, color });
const rc = (t) => new TextRun({ text: t, font: "Courier New", size: 18, color: "2471A3" });
const sp = (before = 0, after = 80) => ({ before, after });

function p(runs, align = AlignmentType.JUSTIFIED, spacing = sp()) {
  const children = Array.isArray(runs) ? runs : [r(runs)];
  return new Paragraph({ children, alignment: align, spacing });
}
function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    children: [rb(text, ROJO)],
    spacing: sp(200, 100),
    border: { bottom: { style: BorderStyle.SINGLE, size: 3, color: ROJO } },
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    children: [rb(text, AZUL)],
    spacing: sp(160, 60),
  });
}
function li(text) {
  return new Paragraph({
    bullet: { level: 0 },
    children: Array.isArray(text) ? text : [r(text)],
    spacing: sp(0, 60),
  });
}
function br() { return new Paragraph({ children: [r("")], spacing: sp(0, 20) }); }
function pb() { return new Paragraph({ children: [new PageBreak()] }); }

function marcadorFoto(num, descripcion) {
  return new Paragraph({
    children: [new TextRun({ text: `[ CAPTURA ${num}: ${descripcion} ]`, bold: true, font: "Calibri", size: 22, color: "FFFFFF" })],
    shading: { type: ShadingType.CLEAR, fill: "2C3E50" },
    alignment: AlignmentType.CENTER,
    spacing: sp(160, 160),
  });
}

function tabla(headers, rows, colWidths = null) {
  const pct = colWidths || headers.map(() => Math.floor(100 / headers.length));
  const cell = (txt, isHead, bgColor, colW) =>
    new TableCell({
      children: [new Paragraph({
        children: [new TextRun({ text: txt, bold: isHead, font: "Calibri", size: 20, color: NEGRO })],
        alignment: AlignmentType.CENTER, spacing: sp(60, 60),
      })],
      width: { size: colW, type: WidthType.PERCENTAGE },
      shading: bgColor ? { type: ShadingType.CLEAR, fill: bgColor } : undefined,
      verticalAlign: VerticalAlign.CENTER,
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
    });
  const hRow = new TableRow({ children: headers.map((h, i) => cell(h, true, ROJO_CLARO, pct[i])) });
  const dRows = rows.map((row, ri) =>
    new TableRow({ children: row.map((v, i) => cell(v, false, ri % 2 === 0 ? GRIS_CLARO : "FFFFFF", pct[i])) })
  );
  return new Table({ rows: [hRow, ...dRows], width: { size: 100, type: WidthType.PERCENTAGE } });
}

// ─── CONSTRUCCIÓN ─────────────────────────────────────────────────────────────
const children = [];

// ══════════════════════════════════════════════════════════════════════════════
// PORTADA
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  br(), br(),
  p([rb("UNIVERSIDAD AUTÓNOMA DE SINALOA", ROJO)], AlignmentType.CENTER, sp(0, 40)),
  p([rb("FACULTAD DE INGENIERÍA MOCHIS", ROJO)], AlignmentType.CENTER, sp(0, 80)),
  p([r("Licenciatura en Ingeniería de Software")], AlignmentType.CENTER, sp(0, 60)),
  p([r("Cómputo en la Nube — Maestra: Elizabeth Gaxiola Carrillo")], AlignmentType.CENTER, sp(0, 400)),
  p([rb("PRÁCTICA 06", ROJO)], AlignmentType.CENTER, sp(0, 100)),
  p([rb("La base de datos del proyecto en subred privada", NEGRO)], AlignmentType.CENTER, sp(0, 400)),
  p([rb("Equipo: Los Rojos", ROJO)], AlignmentType.CENTER, sp(0, 200)),
  tabla(
    ["Integrante", "Matrícula"],
    [
      ["Flores Guevara Ángel Gabriel", ""],
      ["López Payán Kevin Ricardo",    ""],
    ],
    [60, 40]
  ),
  br(),
  p([r("Los Mochis, Sinaloa, México · 13 de octubre de 2026")], AlignmentType.CENTER, sp(200, 0)),
  pb()
);

// ══════════════════════════════════════════════════════════════════════════════
// 1. INTRODUCCIÓN
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("1. Introducción"),
  p([
    r("Una base de datos administrada delega al proveedor las tareas que consumen más tiempo del administrador: parches, respaldos automáticos y conmutación ante falla. "),
    r("En esta práctica se desplegó una instancia de "),
    rb("Amazon RDS PostgreSQL 15"), r(" en la subred privada de la VPC del proyecto, siguiendo la decisión de arquitectura documentada en la Tarea 1 del segundo parcial."),
  ]),
  p([
    r("La base queda fuera del alcance de internet gracias a tres mecanismos independientes: sin IP pública, sin ruta 0.0.0.0/0 en la tabla de ruteo privada, y el Security Group que solo acepta conexiones desde el grupo del servidor EC2."),
  ]),
  br(),
  h2("Recursos desplegados"),
  tabla(
    ["Recurso", "Nombre / ID", "Valor"],
    [
      ["Instancia RDS",    "rds-inventario-cloud-los-rojos",                                    "PostgreSQL 15.7, db.t3.micro"],
      ["Endpoint",         "rds-inventario-cloud-los-rojos.citeqg0wepbd.us-east-1.rds.amazonaws.com", "Puerto 5432"],
      ["Subred privada 1", "subnet-0b6549d5a7ccc669f",                                          "10.0.2.0/24 — us-east-1b"],
      ["Subred privada 2", "subnet-0aaa291c3653ab724",                                          "10.0.3.0/24 — us-east-1c"],
      ["DB Subnet Group",  "dbsg-inventario-cloud-los-rojos",                                    "2 subredes, 2 zonas AZ"],
      ["SG de RDS",        "sg-0734743659216075b",                                               "Puerto 5432 solo desde EC2"],
      ["SG de EC2",        "sg-08467d2aba4777abe",                                               "SSH/HTTP/HTTPS/3000"],
      ["EC2",              "i-099eccb4405920a1e",                                                "IP pública: 44.204.127.130"],
    ],
    [22, 46, 32]
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 2. CAPTURA 1 — BASE DESPLEGADA
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("2. Captura 1 — Base desplegada: sin acceso público y cifrado activo"),
  p([r("Se ejecutó "), rc("evidencia-p06-c1-base-desplegada.sh"), r(" en AWS CloudShell para verificar los criterios de la lista de cotejo.")]),
  br(),
  h2("Criterios verificados"),
  tabla(
    ["Criterio", "Valor obtenido", "Puntos", "Estado"],
    [
      ["La base está en subred privada y sin acceso público", "PubliclyAccessible = False",    "25", "✔ CUMPLIDO"],
      ["El grupo de seguridad referencia al grupo del servidor", "Origen: sg-08467d2aba4777abe (EC2)", "20", "✔ CUMPLIDO"],
      ["El cifrado en reposo está activo",                    "StorageEncrypted = True",       "10", "✔ CUMPLIDO"],
      ["DB Subnet Group con ≥ 2 zonas de disponibilidad",    "us-east-1b + us-east-1c",       "—",  "✔ CUMPLIDO"],
    ],
    [42, 28, 10, 20]
  ),
  br(),
  p([rb("Captura 1-A — "), r("Datos generales de la instancia RDS (tabla completa)")], AlignmentType.LEFT),
  img(1, "Tabla RDS: cifrado, IP pública, endpoint, subnet group", 540, 300),
  br(),
  p([rb("Captura 1-B — "), r("Subredes del DB Subnet Group y reglas del SG de RDS")], AlignmentType.LEFT),
  img(2, "Subredes en 2 AZ + SG RDS referenciando SG EC2", 540, 260),
  br(),
  p([rb("Captura 1-C — "), r("Instancia desplegada con todos los parámetros — salida final del script de despliegue")], AlignmentType.LEFT),
  img(3, "INSTANCIA RDS DESPLEGADA — IP Publica=False, Cifrado=True", 540, 300),
);

// ══════════════════════════════════════════════════════════════════════════════
// 3. CAPTURA 2 — ACCESO DENEGADO DESDE LOCAL
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("3. Captura 2 — Intento fallido de conexión desde fuera de la red"),
  p([
    r("Se ejecutó "), rc("Test-NetConnection"), r(" desde PowerShell en el equipo local (IP: 192.168.100.20) hacia el endpoint de RDS en el puerto 5432. La conexión "),
    rb("debe fallar"), r(" porque la base no tiene IP pública y el SG de RDS no tiene ninguna regla que permita tráfico desde internet."),
  ]),
  br(),
  h2("Resultado esperado vs obtenido"),
  tabla(
    ["Parámetro", "Valor", "Interpretación"],
    [
      ["RemoteAddress",    "10.0.3.165",   "IP privada de RDS — no enrutable desde internet"],
      ["RemotePort",       "5432",         "Puerto PostgreSQL"],
      ["SourceAddress",    "192.168.100.20", "IP local del equipo de desarrollo"],
      ["TcpTestSucceeded", "False",        "✔ Conexión fallida — aislamiento confirmado"],
      ["PingSucceeded",    "False",        "✔ ICMP también bloqueado"],
    ],
    [28, 22, 50]
  ),
  br(),
  p([rb("Captura 2-A — "), r("Intento pendiente (waiting for response)")], AlignmentType.LEFT),
  img(0, "PowerShell: Test-NetConnection esperando respuesta — timeout", 540, 180),
  br(),
  p([rb("Captura 2-B — "), r("Resultado final: TcpTestSucceeded = False")], AlignmentType.LEFT),
  img(4, "PowerShell: TcpTestSucceeded=False, PingSucceeded=False", 540, 220),
  br(),
  p([
    r("Este resultado es la evidencia concreta del aislamiento de red. La dirección "),
    rc("10.0.3.165"), r(" es una IP privada RFC 1918 — no tiene camino desde internet. El SG de RDS tampoco tiene regla con "), rc("0.0.0.0/0"), r("."),
  ]),
);

// ══════════════════════════════════════════════════════════════════════════════
// 4. CAPTURA 3 — CONEXIÓN EXITOSA DESDE EC2
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("4. Captura 3 — Conexión exitosa desde el servidor EC2"),
  p([
    r("Desde el servidor EC2 ("), rc("ubuntu@ip-10-0-1-229"), r(", IP privada 10.0.1.229) se instaló el cliente PostgreSQL y se verificó la conectividad al puerto 5432 de RDS. La conexión "),
    rb("sí debe funcionar"), r(" porque el SG de RDS permite tráfico desde el SG del EC2."),
  ]),
  br(),
  h2("Pasos ejecutados"),
  li([rb("Paso 1: "), r("Instalar postgresql-client en Ubuntu 22.04")]),
  li([rb("Paso 2: "), r("Verificar conectividad TCP con nc -zv -w 5")]),
  li([rb("Paso 3: "), r("Conectarse a la base con psql y ejecutar \\conninfo y SELECT version()")]),
  br(),
  p([rb("Captura 3-A — "), r("Instalación de postgresql-client en EC2")], AlignmentType.LEFT),
  img(15, "apt-get install postgresql-client — 4 paquetes instalados", 540, 280),
  br(),
  p([rb("Captura 3-B — "), r("nc succeeded: conectividad TCP confirmada")], AlignmentType.LEFT),
  img(14, "nc -zv: Connection to RDS 5432 port succeeded!", 540, 160),
  br(),
  p([rb("Captura 3-C — "), r("Sesión psql abierta: prompt inventario=>")], AlignmentType.LEFT),
  img(13, "psql conectado: prompt inventario=>", 540, 200),
  br(),
  p([rb("Captura 3-D — "), r("\\conninfo y SELECT version() ejecutados desde EC2")], AlignmentType.LEFT),
  img(10, "psql conninfo + SELECT version() — PostgreSQL 15.7, SSL TLSv1.2", 540, 260),
  br(),
  p([
    r("La sesión muestra conexión desde "), rc("10.0.1.229"), r(" (EC2, subred pública) hacia "),
    rc("10.0.3.165"), r(" (RDS, subred privada) usando SSL con cifrado "), rb("ECDHE-RSA-AES256-GCM-SHA384 (256 bits)"),
    r(". La comunicación entre subredes dentro de la VPC funciona correctamente."),
  ]),
);

// ══════════════════════════════════════════════════════════════════════════════
// 5. CAPTURA 4 — ESQUEMA Y CONSULTA
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("5. Captura 4 — Esquema del proyecto creado y consulta con resultados"),
  p([
    r("Se transfirió el archivo "), rc("schema-p06.sql"), r(" al EC2 con "), rc("scp"),
    r(" y se ejecutó con "), rc("psql -f"), r(". El script creó las 5 tablas del modelo de datos e insertó registros ficticios de prueba."),
  ]),
  br(),
  h2("Modelo de datos implementado"),
  tabla(
    ["Tabla", "Descripción", "Registros insertados"],
    [
      ["usuarios",    "Cuentas del sistema con roles (administrador, bodega, cajero)", "5"],
      ["categorias",  "Agrupación de productos (Abarrotes, Bebidas, Limpieza, etc.)",  "5"],
      ["productos",   "Inventario con código, precio, stock actual y mínimo",           "7"],
      ["movimientos", "Entradas, salidas y ajustes de inventario con auditoría",        "5"],
      ["pedidos",     "Pedidos automáticos generados cuando stock ≤ mínimo",            "2"],
    ],
    [18, 56, 26]
  ),
  br(),
  p([rb("Captura 4-A — "), r("SCP del archivo SQL al EC2")], AlignmentType.LEFT),
  img(11, "scp schema-p06.sql al EC2 — 9601 bytes transferidos", 540, 100),
  br(),
  p([rb("Captura 4-B — "), r("Ejecución del schema: 5 CREATE TABLE + INSERT")], AlignmentType.LEFT),
  img(9, "CREATE TABLE x5, INSERT 0 5/5/7/5/2 — todas las tablas creadas", 540, 300),
  br(),
  p([rb("Captura 4-C — "), r("Consulta de usuarios, categorías y productos con JOIN")], AlignmentType.LEFT),
  img(8, "SELECT con datos ficticios: usuarios, categorías, productos con stock", 540, 320),
  br(),
  p([rb("Captura 4-D — "), r("Consulta completa: productos con estado de stock, movimientos y pedidos")], AlignmentType.LEFT),
  img(12, "SELECT productos JOIN categorias + movimientos + pedidos pendientes", 540, 320),
  br(),
  p([
    rb("Nota: "), r("No se usaron datos personales reales. Todos los registros son ficticios: "),
    rc("admin@miscelanea.test"), r(", "), rc("bodega@miscelanea.test"), r(", etc."),
  ]),
);

// ══════════════════════════════════════════════════════════════════════════════
// 6. CAPTURA 5 — RESPALDOS Y RPO
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("6. Captura 5 — Retención de respaldos y RPO"),
  p([
    r("Se consultó la configuración de respaldos automáticos de la instancia RDS. La cuenta de "),
    rb("AWS Academy limita la retención a 1 día"), r(" (en producción real se configurarían 7 días)."),
  ]),
  br(),
  h2("Configuración de respaldos"),
  tabla(
    ["Parámetro", "Valor configurado", "Observación"],
    [
      ["Retención",          "1 día (límite AWS Academy)", "En producción real: 7 días"],
      ["Ventana de respaldo", "05:00–06:00 UTC",           "Fuera del horario laboral"],
      ["Frecuencia",          "Diaria (automática)",        "RDS la ejecuta sin intervención"],
      ["Tipo",                "Snapshot + WAL continuo",    "Habilita Point-in-Time Recovery"],
      ["Cifrado",             "True (AES-256)",             "Los respaldos también están cifrados"],
    ],
    [28, 30, 42]
  ),
  br(),
  h2("Análisis del RPO"),
  tabla(
    ["Escenario", "RPO resultante", "Implicación"],
    [
      ["Con respaldo diario solamente", "~24 horas", "Se pierden hasta 24 h de transacciones en el peor caso"],
      ["Con PITR activado (WAL)",       "~5 minutos", "Restauración a cualquier segundo dentro del período"],
      ["Para la miscelánea",            "24 h aceptable", "Movimientos del día se reconstruyen de notas físicas"],
    ],
    [30, 20, 50]
  ),
  br(),
  p([rb("Captura 5-A — "), r("Tabla de configuración RDS: retención 1 día, ventana 05:00-06:00, cifrado True")], AlignmentType.LEFT),
  img(5, "Tabla RDS: Retencion_dias=1, Ventana_respaldo=05:00-06:00, Cifrado=True", 540, 120),
  br(),
  p([rb("Captura 5-B — "), r("Análisis completo del RPO")], AlignmentType.LEFT),
  img(6, "Análisis RPO: 24h con respaldo diario, ~5min con PITR", 540, 320),
  br(),
  p([
    rb("Nota para la práctica 15: "), r("Con la retención activa se podrá usar PITR para restaurar la base a un punto exacto dentro de la ventana de retención. La práctica 15 profundizará en este mecanismo."),
  ]),
);

// ══════════════════════════════════════════════════════════════════════════════
// 7. SEGURIDAD Y COSTOS
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("7. Seguridad y control de costos"),
  h2("Credencial de la base de datos"),
  p([
    r("La contraseña del usuario "), rc("postgres"), r(" "),
    rb("no se almacenó en el repositorio ni en este reporte"), r(". Se guardó fuera del código siguiendo la instrucción del paso 4 de la práctica. En la práctica 14 se migrará a AWS Secrets Manager."),
  ]),
  br(),
  h2("Control de costos"),
  tabla(
    ["Recurso", "Acción al terminar", "Costo mientras detenido"],
    [
      ["EC2 t3.micro",     "Detenido (stop)",      "Solo almacenamiento EBS (~$0.08/GB-mes)"],
      ["RDS db.t3.micro",  "Detenido (stop)",      "Solo almacenamiento gp2 ($0.115/GB-mes)"],
      ["Tiempo máx. RDS detenida", "7 días consecutivos", "Se reinicia automáticamente pasado ese límite"],
    ],
    [28, 28, 44]
  ),
  br(),
  p([
    rb("ADVERTENCIA: "), r("Una base administrada del tamaño mínimo suele estar en la capa gratuita, pero consume una cuota mensual de horas. Es el recurso que con más frecuencia genera el primer cobro inesperado del semestre. Se revisará el gasto el lunes siguiente."),
  ]),
);

// ══════════════════════════════════════════════════════════════════════════════
// 8. LISTA DE COTEJO
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("8. Lista de cotejo"),
  tabla(
    ["Criterio", "Puntos", "Evidencia", "Cumple"],
    [
      ["La base está en subred privada y sin acceso público",                     "25", "Captura 1: PubliclyAccessible=False",           "✔"],
      ["El grupo de seguridad referencia al grupo del servidor y no a rango abierto", "20", "Captura 1: origen sg-08467d2aba4777abe",   "✔"],
      ["El cifrado en reposo está activo",                                         "10", "Captura 1: StorageEncrypted=True",             "✔"],
      ["Se presenta evidencia del intento fallido y de la conexión exitosa",       "20", "Capturas 2 y 3",                              "✔"],
      ["El esquema corresponde al modelo de datos del proyecto",                   "15", "Captura 4: 5 tablas + consultas con JOIN",     "✔"],
      ["La credencial no aparece en el repositorio ni en el reporte",              "10", "Contraseña guardada fuera del repo",           "✔"],
      ["TOTAL",                                                                   "100", "",                                            ""],
    ],
    [46, 10, 34, 10]
  ),
);

// ══════════════════════════════════════════════════════════════════════════════
// 9. CONCLUSIONES
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  pb(),
  h1("9. Conclusiones"),
  p([
    r("La Práctica 06 completó el ciclo de infraestructura iniciado en las prácticas anteriores. La base de datos "),
    rb("PostgreSQL 15.7"), r(" ("), rc("rds-inventario-cloud-los-rojos"), r(") quedó operando en la subred privada "),
    rc("10.0.3.0/24"), r(" (us-east-1c), sin IP pública, con cifrado AES-256 en reposo y comunicación cifrada TLSv1.2 en tránsito."),
  ]),
  p([
    r("El aislamiento se demostró con evidencia concreta: desde el equipo local (IP 192.168.100.20) la conexión devolvió "),
    rc("TcpTestSucceeded : False"), r("; desde el servidor EC2 (10.0.1.229) la misma conexión resultó en "),
    rc("Connection succeeded!"), r(". Esto confirma que solo el EC2 dentro de la VPC puede alcanzar la base."),
  ]),
  p([
    r("El modelo de datos del Sistema de Inventario quedó implementado con las cinco tablas del diseño (usuarios, categorías, productos, movimientos, pedidos) y datos de prueba ficticios listos para las siguientes prácticas."),
  ]),
  br(),
  h2("Relación con el entregable E2"),
  li("El componente de datos del diagrama de arquitectura queda documentado con IDs reales."),
  li("El modelo de datos está implementado en RDS — no solo diseñado en papel."),
  li("La evidencia de aislamiento y cifrado en reposo está lista para el apartado de seguridad del documento final."),
);

// ─── Empaquetar ───────────────────────────────────────────────────────────────
const doc = new Document({
  creator:     "Los Rojos — Cómputo en la Nube 2026",
  title:       "Práctica 06 — La base de datos del proyecto en subred privada",
  description: "RDS PostgreSQL en subred privada, cifrado, aislamiento y esquema del proyecto",
  sections: [{ children }],
});

const outPath = path.join(__dirname, "..", "P06_LosRojos_13oct2026.docx");
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outPath, buf);
  console.log("\n✔  Generado: " + outPath);
  console.log("   Imágenes insertadas desde: " + CAPS_DIR);
  console.log("");
}).catch((e) => {
  console.error("Error:", e.message);
  process.exit(1);
});
