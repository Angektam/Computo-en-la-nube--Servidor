// =============================================================================
// generar-practica05-doc.js  — P05_LosRojos_02oct2026.docx
// Genera el reporte completo de la Práctica 5 con imágenes reales insertadas.
//
// IDs reales observados en las capturas:
//   VPC        : vpc-0a3c4f2dd9ea86a91    CIDR: 10.0.0.0/16
//   Subnet pub : subnet-05986c1524406e08a  CIDR: 10.0.1.0/24  us-east-1a
//   Subnet priv: subnet-0b6549d5a7ccc669f  CIDR: 10.0.2.0/24  us-east-1b
//   IGW        : igw-087467acdec2d06cd
//   RT pub     : rtb-09767244b65d26b18
//   RT priv    : rtb-0fdf5271411ee3257
//   EC2        : i-0ab6dbe715f440427      IP pub: 3.89.139.236  IP priv: 172.31.27.105
//
// Uso:  node scripts/generar-practica05-doc.js
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
const CAPS_DIR = "C:\\Users\\angek\\OneDrive\\Imágenes\\App Player";

// Mapeo cronológico: cada archivo en orden de captura → marcador del reporte
// 24 archivos, 24 posiciones
const CAPTURAS = [
  // E1 — Red y subredes (evidencia-p05-e1-subredes.sh)
  "Captura de pantalla 2026-10-02 124155.png",  // 01 → 1-A: VPC vpc-0a3c4f2dd9ea86a91 + CIDR
  "Captura de pantalla 2026-10-02 124210.png",  // 02 → 1-B: Subredes 10.0.1.0/24 y 10.0.2.0/24
  "Captura de pantalla 2026-10-02 124221.png",  // 03 → 1-C: Etiquetas subred pública
  "Captura de pantalla 2026-10-02 124230.png",  // 04 → 1-D: Etiquetas subred privada + IGW + resumen rangos

  // E2 — Tablas de ruteo (evidencia-p05-e2-tablas-ruteo.sh)
  "Captura de pantalla 2026-10-02 124611.png",  // 05 → 2-A: Tabla pública rtb con 0.0.0.0/0→igw
  "Captura de pantalla 2026-10-02 124622.png",  // 06 → 2-B: Tabla privada rtb solo local
  "Captura de pantalla 2026-10-02 124633.png",  // 07 → 2-C: Tabla comparativa pública vs privada
  "Captura de pantalla 2026-10-02 124647.png",  // 08 → 2-D: Diferencia lado a lado + ENTREGABLE 2

  // E3 — Subred privada inaccesible (evidencia-p05-e3-privada-inaccesible.sh)
  "Captura de pantalla 2026-10-02 124654.png",  // 09 → 3-A: Tabla privada sin ruta 0.0.0.0/0
  "Captura de pantalla 2026-10-02 124919.png",  // 10 → 3-B: Subred privada AsignarIPpublica=False
  "Captura de pantalla 2026-10-02 124930.png",  // 11 → 3-C: MapPublicIpOnLaunch=False verificado
  "Captura de pantalla 2026-10-02 124941.png",  // 12 → 3-D: SG RDS Capa 3 + intento conexión
  "Captura de pantalla 2026-10-02 124949.png",  // 13 → 3-E: Conexión RECHAZADA/TIMEOUT + resumen 3 capas
  "Captura de pantalla 2026-10-02 124956.png",  // 14 → 3-F: ENTREGABLE 3 CUMPLIDO

  // E4 — Reglas de tráfico (evidencia-p05-e4-security-groups.sh)
  "Captura de pantalla 2026-10-02 125402.png",  // 15 → 4-A: SG EC2 reglas inbound con error + outbound
  "Captura de pantalla 2026-10-02 125411.png",  // 16 → 4-B: SG RDS inbound + verificación
  "Captura de pantalla 2026-10-02 125421.png",  // 17 → 4-C: Tabla resumen REGLAS POR COMPONENTE
  "Captura de pantalla 2026-10-02 125426.png",  // 18 → 4-D: ENTREGABLE 4 CUMPLIDO

  // E5 — NAT Gateway análisis de costo (evidencia-p05-e5-nat-costo.sh)
  "Captura de pantalla 2026-10-02 125617.png",  // 19 → 5-A: NO existe NAT Gateway + CONFIRMADO
  "Captura de pantalla 2026-10-02 125629.png",  // 20 → 5-B: Tabla privada NAT=None
  "Captura de pantalla 2026-10-02 125638.png",  // 21 → 5-C: Presupuesto $10 USD + PASO 6 ANÁLISIS
  "Captura de pantalla 2026-10-02 125648.png",  // 22 → 5-D: Tabla costos NAT $32.40/mes
  "Captura de pantalla 2026-10-02 125655.png",  // 23 → 5-E: ¿Cuándo se necesitaría? + alternativas
  "Captura de pantalla 2026-10-02 125713.png",  // 24 → 5-F: DECISIÓN FINAL + ENTREGABLE 5 CUMPLIDO
];

// Carga una imagen como ImageRun de docx
function img(index, descripcion) {
  const archivo = CAPTURAS[index];
  const ruta = path.join(CAPS_DIR, archivo);
  if (!fs.existsSync(ruta)) {
    console.warn(`  ⚠  No se encontró: ${ruta}`);
    return marcadorFoto(index + 1, descripcion);
  }
  const data = fs.readFileSync(ruta);
  return new Paragraph({
    children: [
      new ImageRun({
        data,
        transformation: { width: 540, height: 260 },
        type: "png",
      }),
    ],
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
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    children: [rb(text, NEGRO)],
    spacing: sp(100, 40),
  });
}
function li(text, lvl = 0) {
  return new Paragraph({
    bullet: { level: lvl },
    children: Array.isArray(text) ? text : [r(text)],
    spacing: sp(0, 80),
  });
}
function br() { return new Paragraph({ children: [r("")], spacing: sp(0, 20) }); }
function pb() { return new Paragraph({ children: [new PageBreak()] }); }

function marcadorFoto(num, descripcion) {
  return new Paragraph({
    children: [
      new TextRun({
        text: `[ CAPTURA ${num}: ${descripcion} ]`,
        bold: true, font: "Calibri", size: 22, color: "FFFFFF",
      }),
    ],
    shading: { type: ShadingType.CLEAR, fill: "2C3E50" },
    alignment: AlignmentType.CENTER,
    spacing: sp(160, 160),
    border: {
      top:    { style: BorderStyle.DASHED, size: 6, color: "F39C12" },
      bottom: { style: BorderStyle.DASHED, size: 6, color: "F39C12" },
      left:   { style: BorderStyle.DASHED, size: 6, color: "F39C12" },
      right:  { style: BorderStyle.DASHED, size: 6, color: "F39C12" },
    },
  });
}

function terminal(lines) {
  return new Paragraph({
    children: lines.map((l, i) =>
      new TextRun({
        text: l + (i < lines.length - 1 ? "\n" : ""),
        font: "Courier New", size: 17, color: "A9D18E",
        break: i > 0 ? 1 : 0,
      })
    ),
    shading: { type: ShadingType.CLEAR, fill: "1E2129" },
    spacing: sp(60, 60),
    indent: { left: 200, right: 200 },
    border: {
      top:    { style: BorderStyle.SINGLE, size: 1, color: "555555" },
      bottom: { style: BorderStyle.SINGLE, size: 1, color: "555555" },
      left:   { style: BorderStyle.SINGLE, size: 1, color: "555555" },
      right:  { style: BorderStyle.SINGLE, size: 1, color: "555555" },
    },
  });
}

function tabla(headers, rows, colWidths = null) {
  const pct = colWidths || headers.map(() => Math.floor(100 / headers.length));
  const cell = (txt, isHead, bgColor, colW) =>
    new TableCell({
      children: [
        new Paragraph({
          children: [new TextRun({ text: txt, bold: isHead, font: "Calibri", size: 20, color: NEGRO })],
          alignment: AlignmentType.CENTER,
          spacing: sp(60, 60),
        }),
      ],
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

// ─── DATOS REALES ─────────────────────────────────────────────────────────────
const ROJO_CLARO_LOCAL = "FADBD8";
const IDS = {
  vpc:        "vpc-0a3c4f2dd9ea86a91",
  subPub:     "subnet-05986c1524406e08a",
  subPriv:    "subnet-0b6549d5a7ccc669f",
  igw:        "igw-087467acdec2d06cd",
  rtPub:      "rtb-09767244b65d26b18",
  rtPriv:     "rtb-0fdf5271411ee3257",
  ec2:        "i-0ab6dbe715f440427",
  ec2IpPub:  "3.89.139.236",
  ec2IpPriv: "172.31.27.105",
};

// ─── CONSTRUCCIÓN ─────────────────────────────────────────────────────────────
const children = [];

// ══════════════════════════════════════════════════════════════════════════════
// PORTADA
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  br(), br(),
  p([rb("FACULTAD DE INGENIERÍA MOCHIS", ROJO)], AlignmentType.CENTER, sp(0, 80)),
  p([rb("Ingeniería de Software", NEGRO)], AlignmentType.CENTER, sp(0, 60)),
  p([r("Cómputo en la Nube — Maestra: Elizabeth Gaxiola Carrillo")], AlignmentType.CENTER, sp(0, 400)),
  p([rb("PRÁCTICA 5", ROJO)], AlignmentType.CENTER, sp(0, 100)),
  p([rb("La red del proyecto", NEGRO)], AlignmentType.CENTER, sp(0, 400)),
  p([rb("Equipo: Los Rojos", ROJO)], AlignmentType.CENTER, sp(0, 200)),
  tabla(
    ["Integrante", "Roles"],
    [
      ["López Payán Kevin Ricardo",    "Documentación · Arquitectura"],
      ["Flores Guevara Ángel Gabriel", "Desarrollo · Seguridad y Costos"],
    ],
    [55, 45]
  ),
  br(),
  p([r("Los Mochis, Sinaloa, México · 02 de octubre de 2026")], AlignmentType.CENTER, sp(200, 0)),
  pb()
);

// ══════════════════════════════════════════════════════════════════════════════
// ENTREGABLE 1 — Red y subredes
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Entregable 1 — La red y sus subredes con los rangos visibles"),
  h2("Justificación del direccionamiento (Criterio 1 — 15 pts)"),
  p([
    r("El bloque elegido es "), rc("10.0.0.0/16"),
    r(", que pertenece al rango privado "), rb("RFC 1918 clase A (10.0.0.0/8)"),
    r(". Este bloque no es enrutable en internet público y AWS lo acepta como espacio de direcciones VPC válido."),
  ]),
  tabla(
    ["Subred", "CIDR", "Hosts útiles", "Zona", "Componente"],
    [
      ["VPC completa",   "10.0.0.0/16",  "65 534", "us-east-1",  "Espacio total del proyecto"],
      ["Subred pública", "10.0.1.0/24",  "254",    "us-east-1a", "EC2: Nginx + Node.js (acceso internet)"],
      ["Subred privada", "10.0.2.0/24",  "254",    "us-east-1b", "RDS: PostgreSQL (sin acceso internet)"],
      ["Reserva futura", "10.0.3-255.x", "~65 k",  "—",          "Escalamiento futuro del proyecto"],
    ],
    [18, 14, 12, 12, 44]
  ),
  br(),
  h2("Tabla de rangos"),
  tabla(
    ["Recurso", "Nombre", "CIDR / Rango", "Zona", "ID"],
    [
      ["VPC",            "vpc-inventario-cloud-los-rojos",         "10.0.0.0/16", "us-east-1",  IDS.vpc],
      ["Subred pública", "subnet-pub-inventario-cloud-los-rojos",  "10.0.1.0/24", "us-east-1a", IDS.subPub],
      ["Subred privada", "subnet-priv-inventario-cloud-los-rojos", "10.0.2.0/24", "us-east-1b", IDS.subPriv],
      ["Internet GW",    "igw-inventario-cloud-los-rojos",         "N/A",         "N/A",         IDS.igw],
    ],
    [22, 32, 14, 12, 20]
  ),
  br(),
  h2("Evidencia en AWS CloudShell"),
  p([rb("Captura 1 — "), r("VPC con CIDR 10.0.0.0/16 y estado available")], AlignmentType.LEFT),
  img(0, "VPC vpc-0a3c4f2dd9ea86a91 — CIDR 10.0.0.0/16 available"),
  br(),
  p([rb("Captura 2 — "), r("Subredes: 10.0.1.0/24 (IPpublica=True) y 10.0.2.0/24 (IPpublica=False)")], AlignmentType.LEFT),
  img(1, "Subredes pública y privada con sus CIDRs y zonas"),
  br(),
  p([rb("Captura 3 — "), r("Etiquetas de la subred pública: tipo=publica, proyecto=inventario-cloud")], AlignmentType.LEFT),
  img(2, "Etiquetas subred pública"),
  br(),
  p([rb("Captura 4 — "), r("Etiquetas subred privada + Internet Gateway + Resumen de rangos")], AlignmentType.LEFT),
  img(3, "Etiquetas subred privada, IGW y resumen de rangos — ENTREGABLE 1 CUMPLIDO"),
);

// ══════════════════════════════════════════════════════════════════════════════
// ENTREGABLE 2 — Tablas de ruteo
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Entregable 2 — Las dos tablas de ruteo"),
  p([
    r("La diferencia fundamental entre la subred pública y la privada reside en sus tablas de ruteo. La "),
    rb("tabla pública"), r(" tiene una ruta "), rc("0.0.0.0/0 → igw-087467acdec2d06cd"),
    r(" que le da salida a internet. La "), rb("tabla privada"),
    r(" solo tiene la ruta local "), rc("10.0.0.0/16 → local"),
    r(", haciendo que RDS sea inalcanzable desde fuera de la VPC."),
  ]),
  br(),
  h2("Tabla pública — rtb-09767244b65d26b18"),
  tabla(
    ["Destino", "Objetivo", "Estado", "Origen"],
    [
      ["10.0.0.0/16", "local",                    "active", "CreateRouteTable"],
      ["0.0.0.0/0",   IDS.igw + " (Internet GW)", "active", "CreateRoute"],
    ],
    [25, 45, 15, 15]
  ),
  br(),
  h2("Tabla privada — rtb-0fdf5271411ee3257"),
  tabla(
    ["Destino", "Objetivo", "Estado", "Origen"],
    [["10.0.0.0/16", "local", "active", "CreateRouteTable"]],
    [25, 45, 15, 15]
  ),
  br(),
  h2("Diferencia clave entre ambas tablas"),
  tabla(
    ["", "Tabla PÚBLICA", "Tabla PRIVADA"],
    [
      ["Ruta local VPC",       "✔  10.0.0.0/16 → local", "✔  10.0.0.0/16 → local"],
      ["Ruta a internet",      "✔  0.0.0.0/0 → IGW",     "✗  NO existe esta ruta"],
      ["IP pública instancias","Auto-asignada (True)",    "No asignada (False)"],
      ["Accesible desde web",  "Sí (HTTP/HTTPS abiertos)","No (inaccesible)"],
    ],
    [30, 35, 35]
  ),
  br(),
  h2("Evidencia en AWS CloudShell"),
  p([rb("Captura 5 — "), r("Tabla pública: rutas 10.0.0.0/16→local y 0.0.0.0/0→igw")], AlignmentType.LEFT),
  img(4, "Tabla pública rtb-09767244b65d26b18 con ruta a internet"),
  br(),
  p([rb("Captura 6 — "), r("Tabla privada: solo ruta 10.0.0.0/16→local")], AlignmentType.LEFT),
  img(5, "Tabla privada rtb-0fdf5271411ee3257 sin ruta a internet"),
  br(),
  p([rb("Captura 7 — "), r("Tabla comparativa pública vs privada")], AlignmentType.LEFT),
  img(6, "Diferencia lado a lado entre tablas de ruteo"),
  br(),
  p([rb("Captura 8 — "), r("Diferencia con ✔/✗ — ENTREGABLE 2 CUMPLIDO")], AlignmentType.LEFT),
  img(7, "Tabla comparativa completa — ENTREGABLE 2 CUMPLIDO"),
);

// ══════════════════════════════════════════════════════════════════════════════
// ENTREGABLE 3 — Subred privada inaccesible
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Entregable 3 — La subred privada no se alcanza desde internet"),
  p([r("Se demuestran tres capas de protección independientes que garantizan que RDS sea inaccesible desde internet.")]),
  br(),
  h2("Capa 1 — Tabla de ruteo sin puerta de salida"),
  p([r("La tabla "), rc("rt-priv"), r(" ("), rc("rtb-0fdf5271411ee3257"), r(") no contiene la ruta "), rc("0.0.0.0/0"), r(". Los paquetes con destino fuera de la VPC no tienen camino y AWS los descarta.")]),
  br(),
  h2("Capa 2 — Sin IP pública"),
  p([r("El atributo "), rc("MapPublicIpOnLaunch = False"), r(" en "), rc("subnet-priv"), r(" significa que ninguna instancia recibe IP pública. Sin IP pública no hay destino al que internet pueda dirigir un paquete.")]),
  br(),
  h2("Capa 3 — Security Group de RDS solo acepta desde EC2"),
  p([r("El SG "), rc("sg-rds-inventario-cloud-los-rojos"), r(" solo permite el puerto "), rc("5432"), r(" desde el SG de EC2. No hay ninguna regla con "), rc("0.0.0.0/0"), r(" como origen.")]),
  br(),
  h2("Resumen: defensa en profundidad"),
  tabla(
    ["Capa", "Mecanismo", "Verificación", "Resultado"],
    [
      ["1", "Sin ruta 0.0.0.0/0 en rt-priv",   "Solo ruta local 10.0.0.0/16", "✔ OK"],
      ["2", "MapPublicIpOnLaunch = false",       "Subred sin IP pública",       "✔ OK"],
      ["3", "SG-RDS: 5432 solo desde SG-EC2",   "Sin regla 0.0.0.0/0",         "✔ OK"],
    ],
    [8, 36, 32, 14]
  ),
  br(),
  h2("Evidencia en AWS CloudShell"),
  p([rb("Captura 9 — "), r("Tabla privada rtb-0fdf5271411ee3257: solo 10.0.0.0/16→local")], AlignmentType.LEFT),
  img(8, "Tabla privada sin ruta 0.0.0.0/0 — Capa 1"),
  br(),
  p([rb("Captura 10 — "), r("Subred privada: AsignarIPpublica=False, subnet-0b6549d5a7ccc669f")], AlignmentType.LEFT),
  img(9, "Subred privada sin IP pública — Capa 2"),
  br(),
  p([rb("Captura 11 — "), r("MapPublicIpOnLaunch=False verificado ✔")], AlignmentType.LEFT),
  img(10, "Verificación MapPublicIpOnLaunch=False"),
  br(),
  p([rb("Captura 12 — "), r("SG RDS Capa 3 + intento de conexión TCP al puerto 5432")], AlignmentType.LEFT),
  img(11, "SG RDS solo acepta desde SG-EC2 + demostración activa"),
  br(),
  p([rb("Captura 13 — "), r("Conexión RECHAZADA/TIMEOUT + resumen DEFENSA EN PROFUNDIDAD")], AlignmentType.LEFT),
  img(12, "Conexión rechazada + 3 capas ✔ OK"),
  br(),
  p([rb("Captura 14 — "), r("ENTREGABLE 3 CUMPLIDO")], AlignmentType.LEFT),
  img(13, "Subred privada inaccesible por 3 capas — ENTREGABLE 3 CUMPLIDO"),
);

// ══════════════════════════════════════════════════════════════════════════════
// ENTREGABLE 4 — Reglas de tráfico por componente
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Entregable 4 — Tabla de reglas de tráfico por componente"),
  h2("Componente 1 — EC2 Nginx + Node.js"),
  p([rb("Security Group: "), r("sg-ec2-inventario-cloud-los-rojos | Subred: PÚBLICA (10.0.1.0/24)")]),
  br(),
  h3("Reglas de Entrada (Inbound)"),
  tabla(
    ["Puerto", "Protocolo", "Origen", "Descripción"],
    [
      ["22",   "TCP", "IP-equipo/32", "SSH — administración restringida (no expuesto a 0.0.0.0/0)"],
      ["80",   "TCP", "0.0.0.0/0",   "HTTP — tráfico web público (Nginx)"],
      ["443",  "TCP", "0.0.0.0/0",   "HTTPS — tráfico web cifrado"],
      ["3000", "TCP", "0.0.0.0/0",   "Node.js API — acceso directo (desarrollo)"],
    ],
    [10, 12, 20, 58]
  ),
  br(),
  h2("Componente 2 — RDS PostgreSQL"),
  p([rb("Security Group: "), r("sg-rds-inventario-cloud-los-rojos | Subred: PRIVADA (10.0.2.0/24)")]),
  br(),
  h3("Reglas de Entrada (Inbound)"),
  tabla(
    ["Puerto", "Protocolo", "Origen", "Descripción"],
    [["5432", "TCP", "sg-ec2-inventario-cloud-los-rojos (solo)", "PostgreSQL — exclusivamente desde EC2"]],
    [10, 12, 38, 40]
  ),
  br(),
  h2("Tabla resumen por componente"),
  tabla(
    ["Componente", "Puerto", "Origen / Destino", "Dirección", "Propósito"],
    [
      ["EC2 Nginx+Node",  "22",    "IP-equipo/32",   "Entrada", "SSH admin restringido"],
      ["EC2 Nginx+Node",  "80",    "0.0.0.0/0",      "Entrada", "HTTP público"],
      ["EC2 Nginx+Node",  "443",   "0.0.0.0/0",      "Entrada", "HTTPS público"],
      ["EC2 Nginx+Node",  "3000",  "0.0.0.0/0",      "Entrada", "Node.js API (dev)"],
      ["EC2 Nginx+Node",  "Todos", "0.0.0.0/0",      "Salida",  "Respuestas + S3 + updates"],
      ["RDS PostgreSQL",  "5432",  "SG-EC2 (solo)",  "Entrada", "PostgreSQL solo desde EC2"],
      ["RDS PostgreSQL",  "Todos", "0.0.0.0/0",      "Salida",  "Respuestas hacia EC2"],
    ],
    [20, 10, 22, 12, 36]
  ),
  br(),
  h2("Evidencia en AWS CloudShell"),
  p([rb("Captura 15 — "), r("SG EC2: reglas inbound (22, 80, 443, 3000) + outbound")], AlignmentType.LEFT),
  img(14, "SG EC2 — reglas de entrada y salida"),
  br(),
  p([rb("Captura 16 — "), r("SG RDS: puerto 5432 solo desde SG-EC2 + verificación")], AlignmentType.LEFT),
  img(15, "SG RDS — 5432 solo desde EC2, sin 0.0.0.0/0"),
  br(),
  p([rb("Captura 17 — "), r("Tabla resumen REGLAS POR COMPONENTE")], AlignmentType.LEFT),
  img(16, "Tabla resumen de reglas de tráfico por componente"),
  br(),
  p([rb("Captura 18 — "), r("ENTREGABLE 4 CUMPLIDO")], AlignmentType.LEFT),
  img(17, "Reglas de tráfico verificadas — ENTREGABLE 4 CUMPLIDO"),
);

// ══════════════════════════════════════════════════════════════════════════════
// ENTREGABLE 5 — Diagrama de red
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Entregable 5 — Diagrama de red del proyecto"),
  p([
    r("El diagrama muestra los flujos de tráfico y la distribución de componentes con los IDs reales de la cuenta AWS."),
  ]),
  br(),
  h2("Tabla de recursos con IDs reales"),
  tabla(
    ["Recurso", "Nombre", "ID"],
    [
      ["VPC",              "vpc-inventario-cloud-los-rojos",           IDS.vpc],
      ["Subred pública",   "subnet-pub-inventario-cloud-los-rojos",    IDS.subPub],
      ["Subred privada",   "subnet-priv-inventario-cloud-los-rojos",   IDS.subPriv],
      ["Internet Gateway", "igw-inventario-cloud-los-rojos",           IDS.igw],
      ["RT pública",       "rt-pub-inventario-cloud-los-rojos",        IDS.rtPub],
      ["RT privada",       "rt-priv-inventario-cloud-los-rojos",       IDS.rtPriv],
      ["EC2",              "srv-inventario-cloud-los-rojos",           IDS.ec2],
    ],
    [20, 38, 42]
  ),
  br(),
  h2("Evidencia en AWS CloudShell (E6 — Diagrama de red)"),
  p([rb("Captura 19 — "), r("Diagrama ASCII con IDs reales en terminal")], AlignmentType.LEFT),
  img(18, "Diagrama de red con IDs reales — parte superior"),
  br(),
  p([rb("Captura 20 — "), r("Tabla de recursos: VPC, subnets, IGW, RT, EC2")], AlignmentType.LEFT),
  img(19, "Tabla de recursos con IDs reales"),
);

// ══════════════════════════════════════════════════════════════════════════════
// ENTREGABLE 6 — NAT Gateway y análisis de costo
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Entregable 6 — Paso 6: salida de la subred privada e implicación de costo"),
  h2("Pregunta del Paso 6"),
  p([rb("¿Cómo haría un servidor de la subred privada para descargar actualizaciones sin ser accesible desde afuera? ¿Qué implicación de costo tiene?")]),
  br(),
  h2("Respuesta"),
  p([
    r("Un servidor en "), rc("10.0.2.0/24"), r(" no tiene ruta a internet — la tabla "), rc("rt-priv"),
    r(" solo contiene "), rc("10.0.0.0/16 → local"), r(". Para conexiones salientes se necesita un "),
    rb("NAT Gateway"), r(": se crea en la subred pública y se agrega "), rc("0.0.0.0/0 → nat-xxxxxx"),
    r(" en la tabla privada. El servidor privado nunca queda expuesto a conexiones entrantes."),
  ]),
  br(),
  h2("Verificación: no existe NAT Gateway en la VPC"),
  p([r("Para esta práctica se decidió "), rb("NO crear el NAT Gateway"), r(". Se confirma que "), rc(IDS.vpc), r(" no tiene ninguno activo y la tabla "), rc(IDS.rtPriv), r(" solo contiene la ruta local.")]),
  br(),
  h2("Costo del NAT Gateway (us-east-1, oct 2026)"),
  tabla(
    ["Concepto", "Tarifa", "Ejemplo mensual"],
    [
      ["Disponibilidad (por hora)",      "$0.045 USD/hora", "~$32.40 USD/mes"],
      ["Datos procesados (por GB)",       "$0.045 USD/GB",  "Variable según tráfico"],
      ["COSTO MÍNIMO sin transferencia", "$32.40 USD/mes",  "Solo por existir 24h × 30d"],
    ],
    [40, 25, 35]
  ),
  br(),
  h2("Presupuesto del equipo vs costo"),
  tabla(
    ["Concepto", "Monto"],
    [
      ["Presupuesto mensual del proyecto", "$10.00 USD/mes"],
      ["Costo NAT Gateway mínimo",         "$32.40 USD/mes"],
      ["Exceso sobre el presupuesto",      "$22.40 USD/mes (+324%)"],
    ],
    [60, 40]
  ),
  br(),
  h2("¿Por qué NO lo necesitamos?"),
  li("RDS es administrado por AWS — no necesita acceso saliente a internet."),
  li("La EC2 (subred pública) tiene acceso directo a internet por su propia tabla de ruteo."),
  li("S3 se accede vía IAM Role desde la EC2 — no pasa por la subred privada."),
  br(),
  h2("Alternativas de menor costo"),
  tabla(
    ["Opción", "Costo/mes", "Cuándo usar"],
    [
      ["Sin NAT (configuración actual)",  "$0.00",     "RDS administrado, no necesita internet"],
      ["VPC Endpoint S3",                 "$0.00",     "Acceso S3 desde subred privada"],
      ["NAT Instance (EC2 t4g.nano)",     "~$3-8 USD", "Internet general, bajo costo"],
      ["NAT Gateway (administrado)",      "~$32+ USD", "Alta disponibilidad, sin admin"],
    ],
    [35, 18, 47]
  ),
  br(),
  p([
    rb("Decisión final: "), r("Se omite el NAT Gateway porque RDS no requiere acceso saliente. "),
    rb("Ahorro: ~$32 USD/mes"), r(" — respeta el presupuesto de $10 USD/mes del equipo."),
  ]),
  br(),
  h2("Evidencia en AWS CloudShell (E5 — NAT y costos)"),
  p([rb("Captura 21 — "), r("NO existe NAT Gateway en la VPC + ✔ CONFIRMADO")], AlignmentType.LEFT),
  img(20, "Sin NAT Gateway en vpc-0a3c4f2dd9ea86a91 — CONFIRMADO"),
  br(),
  p([rb("Captura 22 — "), r("Tabla privada con NAT=None + Presupuesto $10.00 USD")], AlignmentType.LEFT),
  img(21, "Tabla privada sin NAT + presupuesto del equipo"),
  br(),
  p([rb("Captura 23 — "), r("PASO 6 ANÁLISIS: tabla de costos NAT $0.045/hora = $32.40/mes")], AlignmentType.LEFT),
  img(22, "Análisis de costo NAT Gateway — $32.40/mes mínimo"),
  br(),
  p([rb("Captura 24 — "), r("Alternativas de costo + DECISIÓN FINAL — ENTREGABLE 5 CUMPLIDO")], AlignmentType.LEFT),
  img(23, "Alternativas de costo + ahorro ~$32 USD/mes — ENTREGABLE 5 CUMPLIDO"),
);

// ══════════════════════════════════════════════════════════════════════════════
// CONCLUSIONES
// ══════════════════════════════════════════════════════════════════════════════
children.push(
  h1("Conclusiones"),
  p([
    r("La Práctica 5 materializó el diseño de red en infraestructura real de AWS: VPC "),
    rc(IDS.vpc), r(" con CIDR "), rc("10.0.0.0/16"),
    r(" y dos subredes /24 que separan los componentes públicos de los privados."),
  ]),
  p([
    r("La diferencia fundamental entre la subred pública ("), rc("10.0.1.0/24"),
    r(") y la privada ("), rc("10.0.2.0/24"),
    r(") reside en sus tablas de ruteo: la pública tiene "),
    rc("0.0.0.0/0 → " + IDS.igw),
    r("; la privada solo tiene "), rc("10.0.0.0/16 → local"), r("."),
  ]),
  p([
    r("La inaccesibilidad de la subred privada se demuestra con tres mecanismos independientes: sin ruta a internet, sin IP pública y SG que solo acepta desde EC2 — defensa en profundidad que protege los datos del inventario."),
  ]),
  p([
    r("La decisión de no usar NAT Gateway es técnicamente justificada con un ahorro directo de "),
    rb("~$32 USD/mes"), r(", respetando el presupuesto de $10 USD/mes del equipo."),
  ]),
  br(),
  h2("Recursos AWS creados en esta práctica"),
  tabla(
    ["Recurso", "Nombre / ID", "CIDR / Puerto"],
    [
      ["VPC",              IDS.vpc,    "10.0.0.0/16"],
      ["Subred pública",   IDS.subPub,  "10.0.1.0/24 (us-east-1a)"],
      ["Subred privada",   IDS.subPriv, "10.0.2.0/24 (us-east-1b)"],
      ["Internet Gateway", IDS.igw,     "—"],
      ["RT pública",       IDS.rtPub,   "0.0.0.0/0 → IGW"],
      ["RT privada",       IDS.rtPriv,  "solo local"],
      ["EC2",              IDS.ec2 + " (" + IDS.ec2IpPub + ")", "22/80/443/3000"],
    ],
    [25, 45, 30]
  )
);

// ─── Empaquetar ───────────────────────────────────────────────────────────────
const doc = new Document({
  creator:     "Los Rojos — Cómputo en la Nube 2026",
  title:       "Práctica 5 — La red del proyecto",
  description: "VPC, subredes, tablas de ruteo, security groups y análisis de costos",
  sections: [{ children }],
});

const outPath = path.join(__dirname, "..", "P05_LosRojos_02oct2026.docx");
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outPath, buf);
  console.log("\n✔  Generado: " + outPath);
  console.log("   Las 24 capturas de pantalla están insertadas en el documento.\n");
}).catch((e) => {
  console.error("Error:", e.message);
  process.exit(1);
});
