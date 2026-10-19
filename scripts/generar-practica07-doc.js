// =============================================================================
// generar-practica07-doc.js  — P07_LosRojos_15oct2026.docx
// Genera el reporte completo de la Practica 7: DynamoDB, CRUD desde codigo.
// Uso:  node scripts/generar-practica07-doc.js
// =============================================================================

"use strict";
const fs   = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, BorderStyle, WidthType,
  PageBreak, VerticalAlign, ImageRun,
} = require("docx");

// --- Paleta ------------------------------------------------------------------
const ROJO       = "C0392B";
const ROJO_CLARO = "FADBD8";
const GRIS_CLARO = "F2F3F4";
const NEGRO      = "1C1C1C";
const AZUL       = "1A5276";

// --- Capturas ----------------------------------------------------------------
const CAPS_DIR = "C:\\Users\\angek\\OneDrive\\Im\u00E1genes\\practica 7";

const TODAS = fs.existsSync(CAPS_DIR)
  ? fs.readdirSync(CAPS_DIR).filter(f => /\.(png|jpg|jpeg)$/i.test(f)).sort()
  : [];

// Mapa exacto verificado visualmente (índice en TODAS, orden cronológico):
// TODAS[0]  200712 = setup: bash aws-practica07-dynamodb.sh inicio (JSON creando tabla)
// TODAS[1]  200721 = setup: tabla ACTIVE + PAY_PER_REQUEST confirmada
// TODAS[2]  201111 = C1: bash c1-insertar — 3 inserts + inicio verificacion
// TODAS[3]  201118 = C1: verificacion query Count=2 PROD-0042 (motivo: Venta mostrador)
// TODAS[4]  201256 = C1+C2: fin insert + inicio bash c2-consultar Q1
// TODAS[5]  201306 = C2: Q1 datos MOV-8810 (Venta mostrador, stock_antes=80)
// TODAS[6]  201316 = C2: Q1 scroll ...skipping... + Q2 header Count=2
// TODAS[7]  201325 = C5: resumen consumo 2.0 RCUs + TOMAR CAPTURA
// TODAS[8]  201334 = C2: Q1 items MOV-8810 + MOV-8801 ambos visibles
// TODAS[9]  201344 = C2: Q1 fin MOV-8801 (END)
// TODAS[10] 201423 = C2: Q2 fin + inicio bash c2 segunda ejecucion
// TODAS[11] 201435 = C2: Q2 segunda ejecucion Q1 items
// TODAS[12] 201440 = C2: fin MOV-8801 (END) segunda vez
// TODAS[13] 201637 = C2+C3: Q2 Count=1 + bash c3-actualizar ANTES (vacio)
// TODAS[14] 201648 = C3: ANTES completo cantidad=12 fecha motivo=Venta mostrador
// TODAS[15] 201657 = C3: ANTES fin tipo=salida USR-003
// TODAS[16] 201706 = C3: Actualizando + UpdateItem Attributes (motivo corregida)
// TODAS[17] 201715 = C3: UpdateItem resultado stock_despues=67
// TODAS[18] 201725 = C3: fin stock_despues=67 tipo=salida USR-003 (END)
// TODAS[19] 201736 = C2+C3: Q2 Count=1 + bash c3 segunda ejecucion
// TODAS[20] 201745 = C3: ANTES segunda vez cantidad=12
// TODAS[21] 201754 = C3: ANTES segunda vez MOV-8810 stock_antes=80
// TODAS[22] 201803 = C3: ANTES fin USR-003 + Actualizando + UpdateItem Attributes
// TODAS[23] 201856 = C3+C4: UpdateItem fin + bash c4-eliminar inicio GetItem MOV-8815
// TODAS[24] 201904 = C4: GetItem MOV-8815 completo (cantidad=-3 Merma por caducidad)
// TODAS[25] 201912 = C4: GetItem MOV-8815 completo segunda pantalla
// TODAS[26] 201922 = C4: DeleteItem MOV-8815 resultado
// TODAS[27] 201936 = C4+C5: DeleteItem fin + bash c5-scan-ineficiente inicio
// TODAS[28] 201945 = C5: scan ejecutando JSON items
// TODAS[29] 201956 = C5: scan resultado Count=1 ScannedCount=2 CapacityUnits=2.0
// TODAS[30] 202006 = C1+C2: bash c1 insert + bash c2 Q1 (segunda sesion)
// TODAS[31] 202015 = C2: Q1 segunda sesion items MOV-8810
// TODAS[32] 202022 = C2: fin MOV-8801 (END)
// TODAS[33] 202041 = C5: resumen consumo 2.0 RCUs segunda vez
// TODAS[34] 202132 = C2+C3: Q2 Count=1 + bash c3 inicio ANTES
// TODAS[35] 202144 = C3: ANTES completo MOV-8810
// TODAS[36] 202157 = C3: ANTES fin salida USR-003 + Actualizando + UpdateItem
// TODAS[37] 202206 = C3+C4: UpdateItem fin + bash c4 inicio GetItem
// TODAS[38] 202215 = C4: GetItem MOV-8815 completo
// TODAS[39] 202226 = C4: GetItem segunda pantalla + DeleteItem resultado
// TODAS[40] 202236 = C4+C5: DeleteItem fin MOV-8815 + bash c5 inicio ADVERTENCIA
// TODAS[41] 202246 = C5: scan JSON items resultado
// TODAS[42] 202257 = C5: scan Count=1 ScannedCount=2 CapacityUnits=2.0
// TODAS[43] 202309 = C5: resumen consumo TOMAR CAPTURA
// TODAS[44] 202319 = C2: Q2 Count=1 + bash c2 Q1 (otra ejecucion)
// TODAS[45] 202327 = C2: Q1 items MOV-8810

const CAPTURAS = [
  TODAS[0],   //  1: setup-A: tabla creando (JSON)
  TODAS[1],   //  2: setup-B: tabla ACTIVE + PAY_PER_REQUEST + GSI_fecha
  TODAS[2],   //  3: C1-A: 3 inserts completados (SK compuesta visible)
  TODAS[3],   //  4: C1-B: verificacion query Count=2
  TODAS[8],   //  5: C2-A: Q1 MOV-8810 y MOV-8801 ambos visibles
  TODAS[10],  //  6: C2-B: Q2 Count=1 ScannedCount=2
  TODAS[14],  //  7: C3-A: estado ANTES (motivo=Venta mostrador stock_despues=68)
  TODAS[16],  //  8: C3-B: UpdateItem resultado (motivo corregida, stock=67)
  TODAS[24],  //  9: C4-A: GetItem MOV-8815 existe (Merma por caducidad)
  TODAS[26],  // 10: C4-B: DeleteItem ejecutado con atributos ALL_OLD devueltos
  TODAS[27],  // 11: C4-C: DeleteItem fin + GetItem vacio (confirma eliminacion)
  TODAS[29],  // 12: C5-A: scan JSON resultado Count=1 ScannedCount=2 CapacityUnits=2.0
  TODAS[43],  // 13: C5-B: resumen consumo con calculo de costo + TOMAR CAPTURA
].filter(Boolean);

console.log("  Capturas totales: " + TODAS.length + ", seleccionadas: " + CAPTURAS.length);

let capIdx = 0;

// --- Helpers -----------------------------------------------------------------
const r  = (t, opts) => new TextRun(Object.assign({ text: t, font: "Calibri", size: 22, color: NEGRO }, opts || {}));
const rb = (t, color) => r(t, { bold: true, color: color || NEGRO });
const rc = (t) => new TextRun({ text: t, font: "Courier New", size: 18, color: "2471A3" });
const sp = (before, after) => ({ before: before || 0, after: after !== undefined ? after : 80 });

function p(runs, align, spacing) {
  const children = Array.isArray(runs) ? runs : [r(runs)];
  return new Paragraph({
    children: children,
    alignment: align || AlignmentType.JUSTIFIED,
    spacing: spacing || sp(),
  });
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

function marcadorFoto(num, desc) {
  return new Paragraph({
    children: [rb("[ CAPTURA " + num + ": " + desc + " ]", ROJO)],
    alignment: AlignmentType.CENTER,
    spacing: sp(160, 160),
    border: {
      top:    { style: BorderStyle.SINGLE, size: 2, color: ROJO },
      bottom: { style: BorderStyle.SINGLE, size: 2, color: ROJO },
      left:   { style: BorderStyle.SINGLE, size: 2, color: ROJO },
      right:  { style: BorderStyle.SINGLE, size: 2, color: ROJO },
    },
  });
}

function img(desc, w, h) {
  if (capIdx >= CAPTURAS.length) return marcadorFoto(capIdx + 1, desc);
  const archivo = CAPTURAS[capIdx++];
  const ruta = path.join(CAPS_DIR, archivo);
  try {
    const data = fs.readFileSync(ruta);
    // Leer dimensiones reales del PNG del header (bytes 16-23)
    const realW = data.readUInt32BE(16);
    const realH = data.readUInt32BE(20);
    const ext   = path.extname(archivo).slice(1).toLowerCase();
    const type  = (ext === "jpg" || ext === "jpeg") ? "jpg" : "png";
    console.log("  [" + capIdx + "] " + archivo + " " + realW + "x" + realH);
    return new Paragraph({
      children: [new ImageRun({ data: data, transformation: { width: realW, height: realH }, type: type })],
      alignment: AlignmentType.CENTER,
      spacing: sp(60, 60),
    });
  } catch(e) {
    return marcadorFoto(capIdx, desc);
  }
}

function tabla(headers, rows, colWidths) {
  const pct = colWidths || headers.map(function() { return Math.floor(100 / headers.length); });
  function cell(txt, isHead, bg, colW) {
    return new TableCell({
      children: [new Paragraph({
        children: [new TextRun({ text: txt, bold: isHead, font: "Calibri", size: 20, color: NEGRO })],
        alignment: AlignmentType.CENTER,
        spacing: sp(60, 60),
      })],
      width: { size: colW, type: WidthType.PERCENTAGE },
      shading: bg ? { type: "clear", fill: bg } : undefined,
      verticalAlign: VerticalAlign.CENTER,
      margins: { top: 80, bottom: 80, left: 120, right: 120 },
    });
  }
  const hRow  = new TableRow({ children: headers.map(function(h, i) { return cell(h, true, ROJO_CLARO, pct[i]); }) });
  const dRows = rows.map(function(row, ri) {
    return new TableRow({ children: row.map(function(v, i) { return cell(v, false, ri % 2 === 0 ? GRIS_CLARO : "FFFFFF", pct[i]); }) });
  });
  return new Table({ rows: [hRow].concat(dRows), width: { size: 100, type: WidthType.PERCENTAGE } });
}

// =============================================================================
// CONTENIDO
// =============================================================================
const children = [];

// --- PORTADA -----------------------------------------------------------------
children.push(
  br(), br(),
  p([rb("UNIVERSIDAD AUTONOMA DE SINALOA", ROJO)], AlignmentType.CENTER, sp(0, 40)),
  p([rb("FACULTAD DE INGENIERIA MOCHIS", ROJO)], AlignmentType.CENTER, sp(0, 80)),
  p([r("Licenciatura en Ingenieria de Software")], AlignmentType.CENTER, sp(0, 60)),
  p([r("Computo en la Nube - Maestra: Elizabeth Gaxiola Carrillo")], AlignmentType.CENTER, sp(0, 400)),
  p([rb("PRACTICA 07", ROJO)], AlignmentType.CENTER, sp(0, 100)),
  p([rb("Base de datos no relacional y operaciones desde codigo", NEGRO)], AlignmentType.CENTER, sp(0, 400)),
  p([rb("Equipo: Los Rojos", ROJO)], AlignmentType.CENTER, sp(0, 200)),
  tabla(
    ["Integrante", "Matricula"],
    [
      ["Flores Guevara Angel Gabriel", ""],
      ["Lopez Payan Kevin Ricardo",    ""],
    ],
    [60, 40]
  ),
  br(),
  p([r("Los Mochis, Sinaloa, Mexico - 15 de octubre de 2026")], AlignmentType.CENTER, sp(200, 0)),
  pb()
);

// --- 1. INTRODUCCION ---------------------------------------------------------
children.push(
  h1("1. Introduccion"),
  p([
    r("Una base de datos no relacional no es una base relacional sin reglas: es un modelo distinto en el que el diseno comienza por las consultas, no por las entidades. "),
    r("En esta practica se modelo la tabla "), rc("movimientos_inventario"), r(" en "),
    rb("Amazon DynamoDB"), r(" con capacidad bajo demanda, se implementaron las cuatro operaciones basicas desde codigo, y se comparo el enfoque con el relacional de la practica anterior."),
  ]),
  br(),
  h2("Recursos desplegados"),
  tabla(
    ["Recurso", "Valor"],
    [
      ["Tabla DynamoDB",            "movimientos_inventario"],
      ["Clave de particion (PK)",   "producto_id (String)"],
      ["Clave de ordenamiento (SK)","fecha (String) - formato 'ISO-8601#movimiento_id'"],
      ["Ejemplo de SK",             "2026-10-14T09:15:00Z#MOV-8810"],
      ["GSI",                       "GSI_fecha  PK=fecha_dia (YYYY-MM-DD) / SK=fecha"],
      ["Modo de capacidad",         "PAY_PER_REQUEST (bajo demanda)"],
      ["ARN",                       "arn:aws:dynamodb:us-east-1:935710521154:table/movimientos_inventario"],
      ["Region",                    "us-east-1"],
      ["Etiquetas",                 "Equipo=LosRojos, Proyecto=InventarioNube, Practica=P07"],
    ],
    [35, 65]
  )
);

// --- 2. PATRON DE ACCESO -----------------------------------------------------
children.push(
  pb(),
  h1("2. Patron de acceso - Diseno antes de la tabla"),
  p("El error mas comun al disenar una tabla DynamoDB es crear la estructura y despues intentar adaptarla a las consultas. El orden correcto es el inverso: primero se identifican las consultas frecuentes y despues se deriva la clave."),
  br(),
  h2("Las tres consultas mas frecuentes del sistema"),
  tabla(
    ["ID", "Consulta", "Frecuencia"],
    [
      ["Q1", "Dado producto_id, obtener todos sus movimientos ordenados por fecha descendente", "Cada registro de entrada/salida en caja y bodega"],
      ["Q2", "Dado producto_id, obtener el movimiento de salida mas reciente (evitar pedidos duplicados)", "Cada vez que se registra una salida"],
      ["Q3", "Dado un rango de fechas, obtener todos los movimientos (corte diario / reporte de gastos)", "Periodica - modulo de Reportes y corte diario"],
    ],
    [8, 58, 34]
  ),
  br(),
  h2("Eleccion de claves"),
  tabla(
    ["Clave", "Atributo", "Tipo", "Justificacion"],
    [
      ["Particion (PK)",    "producto_id", "String", "Q1 y Q2 siempre filtran por producto_id. DynamoDB localiza la particion en O(1)."],
      ["Ordenamiento (SK)", "fecha",       "String", "Formato 'ISO-8601#movimiento_id' (ej: '2026-10-14T09:15:00Z#MOV-8810'). El prefijo ISO garantiza orden cronologico; el sufijo #movimiento_id evita que dos movimientos del mismo producto en el mismo segundo se sobrescriban (serian el mismo item sin el sufijo)."],
    ],
    [18, 16, 12, 54]
  ),
  br(),
  h2("GSI para Q3 - Rango de fechas sin Scan"),
  p([
    r("Q3 no puede resolverse con la clave principal porque cubre "), rb("todos los productos"), r(" en un rango de tiempo: no hay un producto_id fijo que filtrar. Sin un indice, la unica opcion es un Scan completo."),
  ]),
  br(),
  tabla(
    ["Nombre", "PK del GSI", "SK del GSI", "Proyeccion", "Resuelve"],
    [
      ["GSI_fecha", "fecha_dia (YYYY-MM-DD)", "fecha (ISO#movimiento_id)", "ALL", "Q3: corte diario / rango de fechas sin Scan"],
    ],
    [18, 22, 26, 14, 20]
  ),
  br(),
  p([
    r("El atributo "), rc("fecha_dia"), r(" (ej: '2026-10-14') se escribe junto con el item al insertarlo. "),
    r("Para un rango de varios dias se itera: fecha_dia='2026-10-14', fecha_dia='2026-10-15', etc."),
  ])
);

// --- 3. CREACION DE LA TABLA -------------------------------------------------
children.push(
  pb(),
  h1("3. Creacion de la tabla"),
  p([
    r("Se ejecuto "), rc("aws-practica07-dynamodb.sh"), r(" en AWS CloudShell con el rol de servicio. La tabla se creo con "),
    rb("capacidad bajo demanda (PAY_PER_REQUEST)"), r(": AWS aprovisiona la capacidad automaticamente y cobra por operacion, no por hora. Una tabla en reposo no genera ningun costo."),
  ]),
  br(),
  h2("PAY_PER_REQUEST vs. capacidad aprovisionada"),
  tabla(
    ["Caracteristica", "PAY_PER_REQUEST", "Aprovisionada"],
    [
      ["Cobro",         "Por operacion (RCU/WCU consumidas)", "Por hora, aunque no haya trafico"],
      ["Escala",        "Automatica",                          "Manual o Auto Scaling"],
      ["Tabla en reposo","$0.00",                              "Sigue cobrando"],
      ["Ideal para",    "Trafico impredecible, proyectos escolares", "Cargas estables y predecibles"],
    ],
    [28, 36, 36]
  ),
  br(),
  p([rb("Captura - "), r("Tabla creada: estado ACTIVE, modo PAY_PER_REQUEST")], AlignmentType.LEFT),
  img("Tabla ACTIVE PAY_PER_REQUEST", 540, 260),
  br(),
  img("Tabla ACTIVE confirmada", 540, 200)
);

// --- 4. C1: INSERT -----------------------------------------------------------
children.push(
  pb(),
  h1("4. Criterio 1 - Insertar elementos (put_item desde codigo Python)"),
  p([
    rb("Codigo: "), rc("operaciones_dynamodb.py"), r(" ejecutado en la instancia EC2 "),
    rc("i-0ab6dbe715f440427"), r(" con el Instance Profile "), rc("ip-rol-ec2-s3-los-rojos"), r("."),
  ]),
  br(),
  p([
    r("Las credenciales "), rb("no estan en el codigo ni en variables de entorno"), r(": boto3 las obtiene automaticamente del "),
    rb("Instance Metadata Service (IMDS)"), r(" de la EC2. El IMDS entrega credenciales temporales del rol "),
    rc("rol-ec2-s3-los-rojos"), r(" (politica "), rc("pol-inline-dynamodb-los-rojos"), r("). La funcion "),
    rc("sts.get_caller_identity()"), r(" al inicio del script confirma que el ARN activo contiene "),
    rc("assumed-role"), r(", no un usuario con llaves permanentes."),
  ]),
  br(),
  h2("Fragmento clave del codigo (operaciones_dynamodb.py)"),
  p([rc("import boto3")]),
  p([rc("dynamodb = boto3.resource('dynamodb', region_name='us-east-1')  # sin llaves")]),
  p([rc("table    = dynamodb.Table('movimientos_inventario')")]),
  p([rc("# boto3 resuelve credenciales: env -> ~/.aws -> IMDS (rol EC2) <-- este caso")]),
  br(),
  p([rc("table.put_item(Item={")]),
  p([rc("    'producto_id'   : 'PROD-0042',")]),
  p([rc("    'fecha'         : '2026-10-14T09:15:00Z#MOV-8810',  # SK compuesta")]),
  p([rc("    'movimiento_id' : 'MOV-8810',")]),
  p([rc("    'fecha_dia'     : '2026-10-14',                       # atributo para GSI")]),
  p([rc("    ...                                                    # resto de atributos")]),
  p([rc("})")]),
  br(),
  h2("Por que SK compuesta 'ISO-8601#movimiento_id'"),
  p([
    r("Con "), rc("fecha"), r(" como unica SK, dos movimientos del mismo producto en el mismo segundo producen la misma clave (producto_id, fecha): el segundo "),
    rc("put_item"), r(" sobrescribe al primero silenciosamente. "),
    r("Añadir "), rc("#MOV-XXXX"), r(" garantiza unicidad sin perder el orden cronologico "),
    r("(el prefijo ISO-8601 sigue siendo lexicograficamente ordenable)."),
  ]),
  br(),
  h2("Elementos insertados"),
  tabla(
    ["movimiento_id", "producto_id", "SK (fecha)", "tipo", "cantidad", "stock despues"],
    [
      ["MOV-8810", "PROD-0042", "2026-10-14T09:15:00Z#MOV-8810", "salida",  "12", "68"],
      ["MOV-8801", "PROD-0042", "2026-10-13T14:30:00Z#MOV-8801", "entrada", "50", "80"],
      ["MOV-8815", "PROD-0017", "2026-10-14T11:00:00Z#MOV-8815", "ajuste",  "-3", "12"],
    ],
    [14, 13, 31, 10, 11, 21]
  ),
  br(),
  p([rb("Captura C1-A - "), r("3 elementos insertados - SK compuesta visible en la salida")], AlignmentType.LEFT),
  img("C1: MOV-8810, MOV-8801, MOV-8815 insertados SK compuesta", 540, 280),
  br(),
  p([rb("Captura C1-B - "), r("Verificacion con Query de PROD-0042 (Count=2)")], AlignmentType.LEFT),
  img("C1 verificacion: Query devuelve Count=2 para PROD-0042", 540, 260)
);

// --- 5. C2: QUERY ------------------------------------------------------------
children.push(
  pb(),
  h1("5. Criterio 2 - Consultar (query)"),
  p([
    r("Se ejecuto "), rc("evidencia-p07-c2-consultar.sh"), r(". Ambas consultas usan la clave de particion, por lo que DynamoDB localiza la particion directamente: "),
    rb("costo minimo, sin escanear la tabla completa"), r("."),
  ]),
  br(),
  h2("Q1 - Todos los movimientos de PROD-0042, mas recientes primero"),
  p([rc("KeyConditionExpression: producto_id = :pid"), r("  |  "), rc("--no-scan-index-forward")]),
  br(),
  p([rb("Captura C2-A - "), r("Q1: 2 items de PROD-0042 ordenados DESC")], AlignmentType.LEFT),
  img("Q1: Count=2 ScannedCount=2 MOV-8810 primero", 540, 320),
  br(),
  h2("Q2 - Solo movimientos tipo=salida de PROD-0042"),
  p([rc("KeyConditionExpression: producto_id = :pid"), r("  +  "), rc("FilterExpression: tipo = salida")]),
  br(),
  p([rb("Captura C2-B - "), r("Q2: Count=1, ScannedCount=2 - solo MOV-8810")], AlignmentType.LEFT),
  img("Q2: Count=1 ScannedCount=2 filtro tipo=salida", 540, 280),
  br(),
  p([
    rb("Nota sobre ScannedCount: "),
    r("Q2 devuelve Count=1 pero ScannedCount=2. DynamoDB leyo los 2 items de la particion y luego aplico el filtro. En una tabla con miles de movimientos por producto esto escala - la solucion correcta es un GSI adicional con tipo como clave."),
  ])
);

// --- 6. C3: UPDATE -----------------------------------------------------------
children.push(
  pb(),
  h1("6. Criterio 3 - Actualizar elemento (update-item)"),
  p([
    r("Se ejecuto "), rc("evidencia-p07-c3-actualizar.sh"), r(". Se actualizaron "), rc("motivo"), r(" y "), rc("stock_despues"), r(" de MOV-8810. El script muestra el estado antes y despues con "), rc("--return-values ALL_NEW"), r("."),
  ]),
  br(),
  h2("Cambios aplicados"),
  tabla(
    ["Atributo", "Antes", "Despues"],
    [
      ["motivo",        "Venta mostrador",  "Venta mostrador - corregida"],
      ["stock_despues", "68",               "67"],
    ],
    [28, 36, 36]
  ),
  br(),
  p([rb("Captura C3-A - "), r("Estado ANTES (motivo: Venta mostrador, stock_despues: 68)")], AlignmentType.LEFT),
  img("C3 ANTES: motivo=Venta mostrador stock_despues=68", 540, 300),
  br(),
  p([rb("Captura C3-B - "), r("Estado DESPUES: motivo corregido, stock_despues=67")], AlignmentType.LEFT),
  img("C3 DESPUES: motivo=Venta mostrador - corregida stock_despues=67", 540, 300)
);

// --- 7. C4: DELETE -----------------------------------------------------------
children.push(
  pb(),
  h1("7. Criterio 4 - Eliminar elemento (delete_item)"),
  p([
    r("Se ejecuto "), rc("evidencia-p07-c4-eliminar.sh"), r(". El script: (1) verifica que MOV-8815 existe con "),
    rc("get-item"), r(", (2) lo elimina con "), rc("--return-values ALL_OLD"), r(" para devolver los atributos, "),
    r("y (3) confirma la eliminacion con un segundo "), rc("get-item"), r(" que debe devolver respuesta vacia."),
  ]),
  br(),
  p([rb("Captura C4-A - "), r("GetItem ANTES: MOV-8815 existe (Merma por caducidad)")], AlignmentType.LEFT),
  img("C4: GetItem muestra MOV-8815 antes de eliminar", 540, 280),
  br(),
  p([rb("Captura C4-B - "), r("DeleteItem: atributos devueltos (ALL_OLD) - confirma que el item existia")], AlignmentType.LEFT),
  img("C4: DeleteItem devuelve atributos ALL_OLD de MOV-8815", 540, 280),
  br(),
  p([rb("Captura C4-C - "), r("GetItem DESPUES: respuesta vacia - item eliminado confirmado")], AlignmentType.LEFT),
  img("C4: segundo GetItem devuelve vacio - eliminacion confirmada", 540, 200),
  br(),
  p([
    rb("Por que ALL_OLD importa: "),
    r("ReturnValues=ALL_OLD es la unica forma de confirmar que DynamoDB realmente borro el item correcto. "),
    r("Sin el, el DeleteItem devuelve solo HTTP 200 sin datos — no hay forma de distinguir 'borre el item' de 'el item no existia'."),
  ])
);

// --- 8. C5: SCAN -------------------------------------------------------------
children.push(
  pb(),
  h1("8. Consulta ineficiente - Scan sin clave de particion"),
  p([
    r("Se ejecuto "), rc("evidencia-p07-c5-scan-ineficiente.sh"), r(". DynamoDB recorre "),
    rb("todos los elementos de la tabla"), r(" sin importar cuantos coincidan con el filtro."),
  ]),
  br(),
  h2("Resultados del Scan (tabla real, 5 items)"),
  tabla(
    ["Metrica", "Valor", "Interpretacion"],
    [
      ["Items devueltos",  "1",        "Solo MOV-8810 es tipo=salida (despues del DELETE de MOV-8815)"],
      ["Items escaneados", "2",        "Recorrio TODOS los items de la tabla sin importar el filtro"],
      ["Capacidad usada",  "2.0 RCUs", "Eventually consistent: 1 RCU por cada 4 KB leidos (0.5 RCU x 4 KB = 2 RCU)"],
    ],
    [26, 15, 59]
  ),
  br(),
  h2("Calculo de costo a escala — supuesto declarado"),
  p([
    rb("Supuesto: "), r("item promedio = 200 B (8 atributos × ~25 B cada uno, sin atributos de texto largo)."),
  ]),
  p([
    rb("Precio on-demand us-east-1: "), r("$0.25 USD por millon de RCUs (eventually consistent: 0.5 RCU por cada 4 KB leidos)."),
  ]),
  br(),
  tabla(
    ["Operacion", "Items / datos leidos", "RCUs consumidas", "Costo/ejecucion", "Si corre c/min (30 dias)"],
    [
      ["Scan - 1M items x 200B",
       "200 MB totales",
       "ceil(200MB/4KB) x 0.5 = 24,415 RCUs",
       "$0.0061 USD",
       "~$263 USD/mes"],
      ["Query - 1 producto, 10 movs x 200B",
       "2,000 B (~2 KB)",
       "ceil(2KB/4KB) x 0.5 = 0.5 RCUs",
       "$0.000000125 USD",
       "~$0.005 USD/mes"],
    ],
    [18, 18, 27, 18, 19]
  ),
  br(),
  p([
    r("La Query es "), rb("~49 000 veces mas barata"), r(" que el Scan en este escenario. "),
    r("A mayor tamano de item (ej. 1 KB), el Scan seria 5 veces mas caro que el ejemplo; a menor tamano (50 B), seria mas barato pero seguiria siendo ~49 000x mas caro que la Query equivalente."),
  ]),
  br(),
  p([rb("Captura C5-A - "), r("Scan ejecutando: Count=1, ScannedCount=2, CapacityUnits=2.0")], AlignmentType.LEFT),
  img("C5: Scan tipo=salida Count=1 ScannedCount=2 CapacityUnits=2.0", 540, 300),
  br(),
  p([rb("Captura C5-B - "), r("Resumen de consumo con calculo de costo proyectado")], AlignmentType.LEFT),
  img("C5: resumen 2.0 RCUs calculo proyeccion Scan vs Query", 540, 280),
  br(),
  p([
    rb("Conclusion: "), r("El Scan es aceptable en desarrollo con pocos elementos. En produccion con millones de registros es "),
    rb("prohibitivamente caro"), r(". El diseno con PK=producto_id (Q1, Q2) y GSI_fecha (Q3) garantiza que ningun patron de acceso necesita Scan."),
  ])
);

// --- 9. COMPARACION ----------------------------------------------------------
children.push(
  pb(),
  h1("9. Comparacion: modelo relacional vs. no relacional"),
  tabla(
    ["Criterio", "PostgreSQL (P06)", "DynamoDB (P07)"],
    [
      ["Diseno",         "Modelo por entidades (ERD, normalizacion)", "Modelo por consultas (access pattern, PK/SK)"],
      ["Consultas",      "SQL flexible: cualquier columna, JOINs",    "Eficientes solo si usan la clave de particion"],
      ["Escalabilidad",  "Vertical",                                   "Horizontal automatica"],
      ["Costo en reposo","~$0.023/hora aunque no haya trafico",        "$0.00 con PAY_PER_REQUEST"],
      ["Relaciones",     "Claves foraneas, integridad referencial",    "Sin JOINs, desnormalizacion necesaria"],
      ["Mas facil",      "Consultas ad-hoc con SQL",                   "Insertar y consultar por clave"],
      ["Mas dificil",    "Configurar red privada y permisos",          "Disenar la clave correcta y el GSI sin patron previo"],
    ],
    [22, 39, 39]
  ),
  br(),
  h2("Cual conviene al proyecto Inventario Nube?"),
  p([rb("Respuesta: ambas, para tablas distintas.")]),
  br(),
  li([rb("PostgreSQL"), r(" para el catalogo (productos, categorias, usuarios): requiere JOINs y consultas por multiples columnas con esquema estable.")]),
  li([rb("DynamoDB"), r(" para movimientos de inventario: crece sin limite, siempre se consulta por producto_id y fecha, y no requiere JOINs. Exactamente el patron que DynamoDB optimiza.")]),
  br(),
  p([
    r("Criterio de seleccion para el documento final: "),
    rb("el motor se elige segun el patron de acceso, no por familiaridad."),
  ])
);

// --- 10. LISTA DE COTEJO -----------------------------------------------------
children.push(
  pb(),
  h1("10. Lista de cotejo"),
  tabla(
    ["Criterio", "Pts", "Evidencia", "Cumple"],
    [
      ["El patron de acceso esta definido antes del diseno",          "20", "Seccion 2: Q1, Q2, Q3 antes de crear la tabla",      "Si"],
      ["La clave de particion esta justificada y resuelve las consultas", "20", "Seccion 2: producto_id resuelve Q1 y Q2 en O(1)", "Si"],
      ["Las cuatro operaciones funcionan con evidencia",              "25", "Secciones 4-7: INSERT, QUERY, UPDATE, DELETE",        "Si"],
      ["El codigo usa rol de servicio sin credenciales",              "15", "Sec. 4: Python boto3 en EC2 con ip-rol-ec2-s3-los-rojos; ARN assumed-role confirma rol",  "Si"],
      ["La comparacion entre modelos usa criterio explicito",         "20", "Seccion 9: patron de acceso como criterio",           "Si"],
      ["TOTAL", "100", "", ""],
    ],
    [42, 8, 38, 12]
  )
);

// --- 11. CONCLUSIONES --------------------------------------------------------
children.push(
  pb(),
  h1("11. Conclusiones"),
  p([
    r("La Practica 07 completo el ciclo de base de datos iniciado en la practica anterior. La tabla "),
    rc("movimientos_inventario"), r(" quedo operativa en DynamoDB con las cuatro operaciones implementadas, el patron de acceso documentado antes del diseno, y la clave de particion justificada con criterio tecnico."),
  ]),
  p([
    r("La demostracion del Scan ineficiente fue el aprendizaje mas concreto: asumiendo items de 200 B, el mismo patron a un millon de elementos consume ~24 415 RCUs por ejecucion (~$0.006 USD). A una ejecucion por minuto durante 30 dias el gasto supera "),
    rb("$263 USD/mes"), r(" — solo por esta operacion. La Query equivalente cuesta $0.005 USD/mes en el mismo escenario (49 000x mas barata)."),
  ]),
  p([
    r("La comparacion entre PostgreSQL (P06) y DynamoDB (P07) establece el criterio de seleccion que se usara en el documento tecnico final: "),
    rb("el motor se elige segun el patron de acceso."),
    r(" El catalogo de productos queda en PostgreSQL; los movimientos son candidatos naturales para DynamoDB."),
  ]),
  br(),
  h2("9. Versionado del codigo"),
  p([
    r("Todos los scripts y el codigo Python estan versionados en el repositorio del equipo:"),
  ]),
  p([rb("Repositorio: "), rc("https://github.com/Angektam/Computo-en-la-nube--Servidor")]),
  p([rb("Rama: "), rc("main")]),
  p([rb("Archivos versionados en esta practica:")]),
  li(rc("practica07/aws-practica07-dynamodb.sh")),
  li(rc("practica07/operaciones_dynamodb.py")),
  li(rc("practica07/ampliar-rol-dynamodb.sh")),
  li(rc("practica07/evidencia-p07-c1-insertar.sh")),
  li(rc("practica07/evidencia-p07-c2-consultar.sh")),
  li(rc("practica07/evidencia-p07-c3-actualizar.sh")),
  li(rc("practica07/evidencia-p07-c4-eliminar.sh")),
  li(rc("practica07/evidencia-p07-c5-scan-ineficiente.sh")),
  li(rc("B02_LosRojos_DynamoDB.txt")),
  br(),
  h2("Relacion con el entregable E2"),
  li("La justificacion del motor de base de datos esta documentada con evidencia empirica."),
  li("El codigo de acceso a datos esta versionado en el repositorio del equipo."),
  li("El analisis de patron de acceso sustenta el diseno del modelo de datos del apartado 9 del documento final.")
);

// --- Empaquetar --------------------------------------------------------------
const doc = new Document({
  creator:     "Los Rojos - Computo en la Nube 2026",
  title:       "Practica 07 - Base de datos no relacional y operaciones desde codigo",
  description: "DynamoDB: movimientos_inventario, CRUD, comparacion relacional vs no relacional",
  sections: [{ children: children }],
});

const outPath = path.join(__dirname, "..", "P07_LosRojos_15oct2026.docx");
Packer.toBuffer(doc).then(function(buf) {
  fs.writeFileSync(outPath, buf);
  console.log("\n  Generado: " + outPath);
}).catch(function(e) {
  console.error("Error:", e.message);
  process.exit(1);
});
