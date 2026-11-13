// Publica una imagen ya construida y subida. Conserva la configuración de la tarea
// y no imprime ni deja en el repositorio sus variables de entorno.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const region = 'us-east-1';
const cluster = 'ecs-inventario-cloud-los-rojos';
const service = 'svc-inventario-cloud-los-rojos';
const repository = 'inventario-nube-losrojos';
const statePath = path.resolve(__dirname, '../test-local/deployment-state.json');

function aws(args) {
  const result = spawnSync('aws', [...args, '--region', region, '--output', 'json'], {
    encoding: 'utf8', env: { ...process.env, AWS_PAGER: '' }, timeout: 60000,
  });
  if (result.status !== 0) throw new Error(result.stderr?.trim() || result.error?.message || 'Falló AWS CLI');
  return JSON.parse(result.stdout);
}

function main() {
  const taggedImage = fs.readFileSync(path.resolve(__dirname, '../test-local/deploy-image.txt'), 'utf8').trim();
  const expectedPrefix = `935710521154.dkr.ecr.${region}.amazonaws.com/${repository}:pedidos-`;
  if (!taggedImage.startsWith(expectedPrefix)) throw new Error('La imagen no corresponde al repositorio previsto');
  const tag = taggedImage.slice(taggedImage.lastIndexOf(':') + 1);
  const { services, failures } = aws(['ecs', 'describe-services', '--cluster', cluster, '--services', service]);
  if (failures?.length || services?.length !== 1) throw new Error('No se encontró el servicio previsto');
  const current = services[0];
  if (current.status !== 'ACTIVE' || current.desiredCount !== 2 || current.runningCount !== 2
    || current.deployments.length !== 1 || current.deployments[0].rolloutState !== 'COMPLETED') {
    throw new Error('El servicio no está estable con sus dos tareas; revisar antes de actualizar');
  }
  const { taskDefinition: previous } = aws(['ecs', 'describe-task-definition', '--task-definition', current.taskDefinition]);
  const keys = ['family', 'taskRoleArn', 'executionRoleArn', 'networkMode', 'containerDefinitions', 'volumes',
    'placementConstraints', 'requiresCompatibilities', 'cpu', 'memory', 'pidMode', 'ipcMode',
    'proxyConfiguration', 'inferenceAccelerators', 'ephemeralStorage', 'runtimePlatform', 'enableFaultInjection'];
  const next = Object.fromEntries(keys.filter(key => previous[key] !== undefined).map(key => [key, previous[key]]));
  if (next.family !== 'td-inventario-cloud-los-rojos') throw new Error('Familia inesperada');
  const container = next.containerDefinitions.find(c => c.name === 'inventario-nube');
  if (!container) throw new Error('No se encontró el contenedor de inventario');
  const { imageDetails } = aws(['ecr', 'describe-images', '--repository-name', repository, '--image-ids', `imageTag=${tag}`]);
  const digest = imageDetails?.[0]?.imageDigest;
  if (!/^sha256:[a-f0-9]{64}$/.test(digest || '')) throw new Error('No se encontró el digest de la imagen publicada');
  container.image = `${taggedImage.slice(0, taggedImage.lastIndexOf(':'))}@${digest}`;
  const state = {
    timestamp: new Date().toISOString(), region, cluster, service,
    previousTaskDefinition: current.taskDefinition, taggedImage, image: container.image,
    desiredCount: current.desiredCount, status: 'prepared',
  };
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'inventario-ecs-'));
  const inputPath = path.join(tempDir, 'task-definition.json');
  let registered;
  try {
    fs.writeFileSync(inputPath, JSON.stringify(next), { mode: 0o600 });
    registered = aws(['ecs', 'register-task-definition', '--cli-input-json', `file://${inputPath}`]);
  } finally {
    if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);
    fs.rmdirSync(tempDir);
  }
  state.newTaskDefinition = registered.taskDefinition.taskDefinitionArn;
  state.status = 'registered';
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  const updated = aws(['ecs', 'update-service', '--cluster', cluster, '--service', service,
    '--task-definition', state.newTaskDefinition]);
  state.status = 'deploying';
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  console.log(JSON.stringify({ ...state, desiredCount: updated.service.desiredCount }, null, 2));
}

try { main(); } catch (err) { console.error(err.message); process.exitCode = 1; }
