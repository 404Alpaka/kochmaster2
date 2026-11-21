import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = resolve('web');
const server = createServer(async (request, response) => {
  if (request.url === '/favicon.ico') {response.writeHead(204).end();return;}
  const path = resolve(root, '.' + new URL(request.url, 'http://localhost').pathname);
  if (!path.startsWith(root + sep)) {response.writeHead(403).end(); return;}
  try {
    if (request.url === '/test.html') {response.setHeader('Content-Type','text/html'); response.end('<script src="/receipt_tools.js"></script>');return;}
    response.setHeader('Content-Type', {'.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm'}[extname(path)] || 'application/octet-stream');
    response.end(await readFile(path));
  } catch {response.writeHead(404).end();}
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({channel: 'chrome', headless: true});
try {
  const page = await browser.newPage();
  page.on('console', message => {if (message.type() === 'error') console.error(message.text());});
  await page.goto(`http://127.0.0.1:${server.address().port}/test.html`);
  const pick = async (fn, file) => {
    const chooser = page.waitForEvent('filechooser');
    const result = page.evaluate(fn);
    await (await chooser).setFiles(file);
    return JSON.parse(await result);
  };
  if (process.argv[2]) {
    const doc = await pick(() => window.miseReadReceipt('file'), resolve(process.argv[2]));
    assert.match(doc.text, /THUNFISCHSTEAK/);
    assert.match(doc.text, /12 Stk/);
    assert.equal(doc.fingerprint.length, 64);
    assert.ok(doc.text.includes('\n'));
    await mkdir('build/design', {recursive:true});
    await writeFile('build/design/rewe-browser-text.txt', doc.text);
    console.log('REWE PDF: all pages extracted, quantities present, fingerprint valid');
  }
  if (process.argv[3]) {
    const code = await pick(() => window.miseScanBarcode(false), resolve(process.argv[3]));
    assert.equal(code, '4006381333931');
    console.log('Barcode image: EAN-13 decoded');
  }
  if (process.argv[4]) {
    const doc = await pick(() => window.miseReadReceipt('file'), resolve(process.argv[4]));
    assert.match(doc.text, /(?:JOGHURT|Joghurt)/);
    console.log('OCR image: product text recognized');
  }
  if (process.env.LOOKUP_TEST) {
    const product = JSON.parse(await page.evaluate(() => window.miseLookupBarcode('3017620422003')));
    assert.ok(product?.product_name || product?.product_name_de);
    console.log('Open Food Facts: barcode product lookup succeeded from browser');
  }
} finally {await browser.close(); await new Promise(resolve => server.close(resolve));}
