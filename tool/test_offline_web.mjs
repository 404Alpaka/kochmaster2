import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFile, mkdir} from 'node:fs/promises';
import {resolve, extname, sep} from 'node:path';
import assert from 'node:assert/strict';

// Build with USE_DEMO=true, then run prepare_offline_web.mjs first.
const require = createRequire(import.meta.url);
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = resolve('build/web');
const mime = {'.html':'text/html', '.js':'text/javascript', '.mjs':'text/javascript',
  '.wasm':'application/wasm', '.json':'application/json', '.png':'image/png',
  '.jpg':'image/jpeg', '.ttf':'font/ttf'};
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const path = resolve(root, '.' + (url.pathname === '/' ? '/index.html' : url.pathname));
  if (!path.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try {
    res.setHeader('Content-Type', mime[extname(path)] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'no-store');
    res.end(await readFile(path));
  } catch { res.writeHead(404).end(); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const browser = await chromium.launch({channel:'chrome', headless:true});
const context = await browser.newContext({viewport:{width:430, height:1000}});
let page = await context.newPage();
const origin = `http://127.0.0.1:${server.address().port}`;
const errors = [];
const observe = p => p.on('pageerror', e => errors.push(e.message));
observe(page);
async function semantics() {
  await page.locator('flt-semantics-placeholder').waitFor({state:'attached', timeout:60000});
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
  await page.getByRole('button', {name:'Rezepte', exact:true}).waitFor({timeout:60000});
}
async function reveal(locator) {
  for (let i=0; i<20; i++) {
    if (await locator.count()) { await locator.scrollIntoViewIfNeeded(); return; }
    await page.mouse.move(200, 550);
    await page.mouse.wheel(0, 450);
    await page.waitForTimeout(100);
  }
  throw new Error('Control not found: ' + locator);
}
try {
  await page.goto(origin);
  await semantics();
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller) await new Promise(resolve =>
      navigator.serviceWorker.addEventListener('controllerchange', resolve, {once:true}));
  });
  await page.getByRole('button', {name:'Rezepte', exact:true}).click();
  await page.getByRole('textbox').fill('Tomaten-Spinat');
  const actions = page.getByRole('button', {name:'Rezeptaktionen für Tomaten-Spinat-Pasta'});
  await reveal(actions);
  await actions.click();
  await page.getByText('Zum Wochenplan hinzufügen', {exact:true}).click();
  await page.getByText('Montag', {exact:true}).click();
  await page.getByRole('button', {name:'Korb', exact:true}).click();
  const noodles = () => page.getByRole('checkbox', {name:/Nudeln/});
  await reveal(noodles());
  await noodles().check();
  await page.waitForFunction(() => Object.entries(localStorage).some(([k,v]) =>
    k.includes('offline:demo:guest:week:') && v.includes('pasta') &&
    JSON.parse(v).plan.checked.some(item => item.ingredient_id === 'pasta')));

  const cached = await page.evaluate(async () => {
    const names = (await caches.keys()).filter(k => k.startsWith('mise-shell-'));
    return (await (await caches.open(names[0])).keys()).map(r => r.url);
  });
  assert.ok(cached.some(url => url.endsWith('/canvaskit/canvaskit.wasm')));
  assert.ok(cached.some(url => url.endsWith('/main.dart.js')));
  assert.ok(cached.every(url => url.startsWith(origin + '/') && !url.includes('/rest/v1/') && !url.includes('/auth/')));
  // Close the page to discard its Dart memory; the next start has no network.
  await page.close();
  await context.setOffline(true);
  page = await context.newPage();
  observe(page);
  await page.goto(origin, {waitUntil:'load'});
  await semantics();
  await page.getByRole('button', {name:'Korb', exact:true}).click();
  await reveal(noodles());
  assert.equal(await noodles().isChecked(), true);
  await noodles().uncheck();
  await page.waitForFunction(() => Object.entries(localStorage).some(([k,v]) =>
    k.includes('offline:demo:guest:week:') && v.includes('pasta') &&
    !JSON.parse(v).plan.checked.some(item => item.ingredient_id === 'pasta')));
  await page.reload();
  await semantics();
  await page.getByRole('button', {name:'Korb', exact:true}).click();
  await reveal(noodles());
  assert.equal(await noodles().isChecked(), false);
  assert.deepEqual(errors, []);
  await mkdir('build/design', {recursive:true});
  await page.screenshot({path:'build/design/offline-shopping.png'});
  console.log(`Offline web restart and offline shopping persistence passed; ${cached.length} static assets cached; no runtime errors.`);
} catch (error) {
  await mkdir('build/design', {recursive:true});
  await page.screenshot({path:'build/design/offline-failure.png'}).catch(() => {});
  console.error((await page.locator('body').innerText()).slice(0,4000));
  throw error;
} finally {
  await browser.close();
  await new Promise(r => server.close(r));
}
