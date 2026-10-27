const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, BorderStyle, ShadingType, AlignmentType,
  convertInchesToTwip, UnderlineType, LevelFormat, NumberFormat
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── helpers ────────────────────────────────────────────────────────────────
function b(text, size = 22) {
  return new TextRun({ text, bold: true, size, font: "Calibri", color: "1F1F1F" });
}
function t(text, size = 22) {
  return new TextRun({ text, size, font: "Calibri", color: "1F1F1F" });
}
function mono(text, size = 20) {
  return new TextRun({ text, size, font: "Courier New", color: "1F1F1F" });
}

function p(...runs) {
  return new Paragraph({
    spacing: { before: 0, after: 120 },
    children: runs,
  });
}

function heading(text, level = 1) {
  return new Paragraph({
    spacing: { before: 280, after: 120 },
    children: [
      new TextRun({
        text,
        bold: true,
        size: level === 1 ? 26 : 23,
        font: "Calibri",
        color: "1F3864",
        underline: level === 1 ? { type: UnderlineType.SINGLE } : undefined,
      }),
    ],
  });
}

function bullet(text, indent = 0) {
  return new Paragraph({
    spacing: { before: 0, after: 80 },
    indent: { left: 360 + indent * 360 },
    children: [t("- " + text)],
  });
}

function sp(n = 200) {
  return new Paragraph({ spacing: { before: 0, after: n }, children: [] });
}

// Tabla sencilla con bordes grises
function simpleTable(headers, rows) {
  const borderDef = {
    style: BorderStyle.SINGLE,
    size: 4,
    color: "AAAAAA",
  };
  const cellBorders = {
    top: borderDef, bottom: borderDef, left: borderDef, right: borderDef,
  };

  const headerRow = new TableRow({
    tableHeader: true,
    children: headers.map(h =>
      new TableCell({
        borders: cellBorders,
        shading: { type: ShadingType.SOLID, fill: "D9E1F2" },
        margins: { top: 80, bottom: 80, left: 120, right: 120 },
        children: [new Paragraph({ children: [b(h, 20)] })],
      })
    ),
  });

  const dataRows = rows.map((row, ri) =>
    new TableRow({
      children: row.map(cell =>
        new TableCell({
          borders: cellBorders,
          shading: { type: ShadingType.SOLID, fill: ri % 2 === 0 ? "FFFFFF" : "F2F2F2" },
          margins: { top: 60, bottom: 60, left: 120, right: 120 },
          children: [new Paragraph({ children: [t(cell, 20)] })],
        })
      ),
    })
  );

  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [headerRow, ...dataRows],
  });
}

// ── DOCUMENTO ─────────────────────────────────────────────────────────────────
const doc = new Document({
  numbering: {
    config: [],
  },
  sections: [
    {
      properties: {
        page: {
          margin: {
            top: convertInchesToTwip(1),
            bottom: convertInchesToTwip(1),
            left: convertInchesToTwip(1.18),
            right: convertInchesToTwip(1.18),
          },
        },
      },
      children: [

        // PORTADA
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 80 },
          children: [new TextRun({ text: "Universidad Autónoma de Sinaloa", bold: true, size: 24, font: "Calibri", color: "1F1F1F" })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 80 },
          children: [t("Facultad de Ingeniería Mochis · Cómputo en la Nube", 22)],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 160, after: 80 },
          children: [new TextRun({ text: "Parte 2 — Alta disponibilidad y escalamiento automático", bold: true, size: 28, font: "Calibri", color: "1F3864" })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 80 },
          children: [t("Sistema de Gestión de Inventarios — Equipo Los Rojos", 22)],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 0, after: 400 },
          children: [t("López Payán Kevin Ricardo · Flores Guevara Ángel Gabriel", 22)],
        }),

        // ═══════════════════════════════════════════════════════════════════
        // PUNTO 1
        // ═══════════════════════════════════════════════════════════════════
        heading("1. Arquitectura actual y puntos únicos de falla"),

        p(t("La arquitectura actual del sistema cuenta con tres componentes principales desplegados en la región us-east-1 de AWS: una instancia EC2 t3.micro con la API en Node.js y Express, una base de datos RDS PostgreSQL db.t3.micro y un bucket S3 que aloja el frontend estático. El problema es que cada componente representa un punto único de falla.")),

        p(b("Punto de falla 1 — EC2 única (us-east-1a):"), t(" toda la lógica de la API corre en una sola instancia en una sola zona de disponibilidad. Si la instancia se cae o la zona falla, ningún usuario puede registrar ventas ni consultar el inventario.")),

        p(b("Punto de falla 2 — RDS Single-AZ (us-east-1a):"), t(" la base de datos no tiene réplica en otra zona. Si la zona us-east-1a falla, se pierden todos los movimientos de inventario hasta que se restaure desde el último respaldo automático.")),

        p(b("Punto de falla 3 — Sin balanceador de carga:"), t(" no hay ningún componente que detecte si la EC2 dejó de responder y redirija el tráfico. El sistema es todo o nada: o la instancia está arriba, o el servicio está caído.")),

        p(t("En resumen, la arquitectura actual no tiene redundancia en ninguna capa. Cualquier fallo de instancia o de zona de disponibilidad resulta en interrupción total del servicio.")),

        sp(),

        // ═══════════════════════════════════════════════════════════════════
        // PUNTO 2
        // ═══════════════════════════════════════════════════════════════════
        heading("2. Arquitectura rediseñada: ALB + 2 EC2 en 2 AZ + RDS Multi-AZ"),

        p(t("Para eliminar los puntos únicos de falla identificados, la arquitectura se rediseña de la siguiente manera:")),

        bullet("Se agrega un Application Load Balancer (ALB) expuesto en dos subredes públicas, una en us-east-1a y otra en us-east-1b. El ALB recibe todo el tráfico HTTPS del exterior y lo distribuye entre las instancias disponibles."),
        bullet("Se despliegan dos instancias EC2 t3.micro, cada una en una zona de disponibilidad diferente (us-east-1a y us-east-1b), ambas en subredes públicas con el mismo grupo de seguridad sg-api que permite tráfico al puerto 3000 únicamente desde el ALB."),
        bullet("La base de datos RDS PostgreSQL se configura en modo Multi-AZ: una instancia primaria en us-east-1a y una réplica síncrona en us-east-1b. Ambas en subredes privadas. En caso de fallo de la AZ primaria, AWS hace el failover automático en menos de 60 segundos."),
        bullet("Los grupos de seguridad se configuran en cadena: sg-alb acepta tráfico externo en 80/443; sg-api acepta tráfico al puerto 3000 solo desde sg-alb; sg-rds acepta tráfico al puerto 5432 solo desde sg-api."),

        sp(80),
        p(t("Con este diseño, si una zona de disponibilidad falla por completo, el ALB deja de enviarle tráfico a la EC2 de esa zona y sigue atendiendo con la EC2 de la otra zona. La RDS hace failover automático a la réplica standby. El sistema permanece disponible sin intervención manual.")),

        sp(),

        // ═══════════════════════════════════════════════════════════════════
        // PUNTO 3
        // ═══════════════════════════════════════════════════════════════════
        heading("3. Verificación de estado: ruta, frecuencia y umbral de fallos"),

        p(t("El ALB verifica el estado de cada instancia EC2 mediante el endpoint "), mono("GET /health"), t(" definido en el requerimiento funcional RF-13 del anteproyecto. Este endpoint retorna HTTP 200 con el mensaje "), mono('{"db":"ok","s3":"ok"}'), t(" cuando la API puede conectarse a la base de datos y al bucket S3; retorna HTTP 500 si alguno de los dos servicios no responde.")),

        sp(80),

        simpleTable(
          ["Parámetro", "Valor configurado", "Justificación"],
          [
            ["Ruta", "GET /health", "Declarada en RF-13; verifica conexión a RDS y S3 en cada llamada"],
            ["Protocolo", "HTTP (puerto 3000)", "El TLS termina en el ALB; la comunicación interna es HTTP"],
            ["Intervalo entre checks", "30 segundos", "Detecta fallos en menos de un minuto sin saturar la instancia"],
            ["Timeout por intento", "5 segundos", "Más que suficiente para /health; el RNF-01 exige < 500 ms en condiciones normales"],
            ["Fallos para marcar Unhealthy", "2 consecutivos", "2 x 30 s = 60 s máximo antes de retirar la instancia. Evita retiradas por fallos transitorios de red"],
            ["Éxitos para volver a Healthy", "3 consecutivos", "90 s de estabilidad antes de reintroducirla, compatible con el período de calentamiento de 120 s"],
            ["Código HTTP esperado", "200", "Cualquier otro código o timeout se trata como fallo"],
          ]
        ),

        sp(120),
        p(t("Cuando el ALB detecta dos fallos consecutivos en una instancia, la marca como no disponible y deja de enviarle tráfico. Al mismo tiempo, Auto Scaling recibe la notificación y lanza una nueva instancia de reemplazo. Cuando la nueva instancia pasa tres verificaciones consecutivas, el ALB empieza a enviarle tráfico.")),

        sp(),

        // ═══════════════════════════════════════════════════════════════════
        // PUNTO 4
        // ═══════════════════════════════════════════════════════════════════
        heading("4. Usuarios simultáneos en pico y en valle — peticiones por segundo"),

        p(t("El sistema tiene cuatro usuarios potenciales: la propietaria (administrador), el encargado de bodega, el cajero y el proceso automático de alertas de stock. El supuesto del ejercicio es que una instancia t3.micro atiende 14 peticiones por segundo al 50% de uso del procesador.")),

        sp(80),

        simpleTable(
          ["Escenario", "Usuarios activos", "Req/usuario/seg", "Total req/seg", "EC2 necesarias"],
          [
            ["Valle (madrugada)", "1 — propietaria revisa reportes", "~1", "1 req/s", "1 EC2 al 7% CPU"],
            ["Uso normal (día laboral)", "3 — cajero, bodega y admin", "~2", "6 req/s", "1 EC2 al 43% CPU"],
            ["Pico (corte diario + ventas)", "4 — todos + cron de alertas", "~4", "16 req/s", "2 EC2 al 57% CPU c/u"],
          ]
        ),

        sp(120),
        p(t("En el pico, 4 usuarios generan aproximadamente 16 peticiones por segundo. Dividiendo entre 14 req/s por instancia se necesitan 1.14 instancias, es decir, 2 instancias activas para mantener cada una por debajo del 70% de CPU. En el valle, con 1 req/s, una sola instancia opera al 7% y es suficiente.")),

        sp(),

        // ═══════════════════════════════════════════════════════════════════
        // PUNTO 5
        // ═══════════════════════════════════════════════════════════════════
        heading("5. Mínimo, deseado y máximo — política de escalamiento"),

        p(b("Mínimo: 1 instancia.")),
        p(t("Siempre debe existir al menos una EC2 activa para que la propietaria pueda consultar el inventario desde casa en cualquier momento, que es el problema principal descrito en el anteproyecto. En el valle, una instancia opera al 7% de CPU, por lo que no se justifica mantener más de una.")),

        p(b("Deseado: 2 instancias.")),
        p(t("Con 3 empleados activos durante el día el sistema genera alrededor de 6 req/s, lo que representa un 43% de CPU en una sola instancia. Con 2 instancias eso baja al 21%, dejando margen amplio antes del umbral de escalamiento. Además, con 2 instancias en 2 zonas de disponibilidad diferentes se cumple la condición de alta disponibilidad real.")),

        p(b("Máximo: 3 instancias.")),
        p(t("El pico máximo real es 16 req/s y se cubre con 2 instancias. La tercera instancia existe como colchón de seguridad para absorber picos imprevistos o para cubrir el tiempo de calentamiento si una instancia falla y está siendo reemplazada. Además, 3 instancias t3.micro se mantienen dentro de los créditos del programa AWS Academy.")),

        sp(80),
        heading("Politica de escalamiento", 2),

        p(b("Tipo: "), t("Target Tracking Policy (Política de objetivo de seguimiento). AWS ajusta automáticamente el número de instancias para mantener la métrica elegida cerca del valor objetivo, sin necesidad de definir reglas de escalamiento hacia arriba y hacia abajo por separado.")),

        p(b("Metrica: "), mono("CPUUtilization"), t(" — promedio de CPU de todas las instancias del grupo en cada momento.")),

        p(b("Valor objetivo: "), t("70%. Tomando el supuesto de 14 req/s al 50% de CPU, el 70% corresponde aproximadamente a 19.6 req/s por instancia. Ese umbral deja un margen del 30% antes de que la instancia se sature y el tiempo de respuesta empiece a subir por encima del límite de 500 ms establecido en el RNF-01. Si se eligiera un objetivo más bajo, como 40%, las instancias escalarían demasiado pronto y se estarían gastando créditos innecesariamente.")),

        p(b("Período de calentamiento: "), t("120 segundos. Es el tiempo que necesita una nueva EC2 para arrancar Node.js, cargar las variables de entorno desde el archivo .env y pasar la primera verificación de estado del ALB.")),

        p(b("Período de gracia: "), t("60 segundos. El ALB espera este tiempo antes de enviar tráfico real a una instancia nueva, evitando errores 502 en el navegador del cliente mientras la API todavía está inicializando.")),

        sp(80),

        simpleTable(
          ["Configuración", "Valor", "Motivo"],
          [
            ["Mínimo", "1 EC2", "Acceso remoto de la propietaria en cualquier momento"],
            ["Deseado", "2 EC2", "Carga normal del día + alta disponibilidad en 2 zonas"],
            ["Máximo", "3 EC2", "Pico con colchón de seguridad + límite de créditos Academy"],
            ["Tipo de política", "Target Tracking", "AWS gestiona el escalamiento automáticamente"],
            ["Métrica", "CPUUtilization", "Indicador directo de carga de la API"],
            ["Objetivo", "70%", "Margen del 30% antes de saturar; cumple RNF-01 < 500 ms"],
            ["Calentamiento", "120 s", "Arranque de Node.js + carga de variables de entorno"],
            ["Gracia (ALB)", "60 s", "Evita errores 502 al nuevo servidor mientras inicia"],
          ]
        ),

      ],
    },
  ],
});

// ── Guardar ────────────────────────────────────────────────────────────────
const outPath = path.join(__dirname, "..", "Parte2_LosRojos_AltaDisponibilidad.docx");
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outPath, buf);
  console.log("Archivo generado:", outPath);
}).catch(err => { console.error(err); process.exit(1); });
