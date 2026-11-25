import {createHash} from 'node:crypto';
import {readFile, readdir, writeFile} from 'node:fs/promises';
import {resolve, relative, sep} from 'node:path';

const root = resolve(process.argv[2] ?? 'build/web');
const bootstrapPath = resolve(root, 'flutter_bootstrap.js');
const bootstrap = (await readFile(bootstrapPath, 'utf8'))
  .replace('const miseOfflineBuild = false;', 'const miseOfflineBuild = true;');
if (!bootstrap.includes('const miseOfflineBuild = true;')) {
  throw new Error('Build with the project web/flutter_bootstrap.js before preparing offline assets.');
}
await writeFile(bootstrapPath, bootstrap);

async function files(dir) {
  const result = [];
  for (const entry of await readdir(dir, {withFileTypes: true})) {
    const path = resolve(dir, entry.name);
    if (entry.isDirectory()) result.push(...await files(path));
    else result.push(relative(root, path).split(sep).join('/'));
  }
  return result;
}
const core = new Set(['index.html', 'flutter_bootstrap.js', 'flutter.js', 'main.dart.js',
  'receipt_tools.js', 'manifest.json', 'favicon.png']);
const assets = (await files(root)).filter(path =>
  !path.endsWith('.map') && (core.has(path) || path.startsWith('assets/') ||
    path.startsWith('icons/') || path.startsWith('vendor/') ||
    (path.startsWith('canvaskit/') && /\/canvaskit\.(?:js|wasm)$/.test(path)))
).sort();
for (const required of ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'canvaskit/canvaskit.wasm']) {
  if (!assets.includes(required)) throw new Error(`Missing offline artifact: ${required}`);
}
const template = await readFile('web/offline_worker.js', 'utf8');
const hash = createHash('sha256').update(template);
let bytes = 0;
for (const path of assets) {
  const content = await readFile(resolve(root, path));
  hash.update(path).update(content);
  bytes += content.length;
}
const version = hash.digest('hex').slice(0, 20);
await writeFile(resolve(root, 'offline_worker.js'), template
  .replace('MISE_BUILD_VERSION', version)
  .replace('const ASSETS = []; // MISE_BUILD_ASSETS', `const ASSETS = ${JSON.stringify(assets)};`));
console.log(`Offline shell ${version}: ${assets.length} files, ${(bytes / 1024 / 1024).toFixed(1)} MiB.`);
