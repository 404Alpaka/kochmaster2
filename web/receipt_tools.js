/* Local receipt processing. Documents never leave the browser. */
(() => {
  const vendor = new URL('vendor/receipts/', document.baseURI).href;
  const scripts = new Map();
  function loadScript(file) {
    if (!scripts.has(file)) scripts.set(file, new Promise((resolve, reject) => {
      const script = document.createElement('script');
      const timeout = setTimeout(() => { script.remove(); scripts.delete(file); reject(new Error('Die Erkennung konnte nicht geladen werden. Bitte Verbindung prüfen.')); }, 30000);
      script.src = vendor + file;
      script.onload = () => { clearTimeout(timeout); resolve(); };
      script.onerror = () => { clearTimeout(timeout); scripts.delete(file); reject(new Error('Die Erkennung konnte nicht geladen werden. Bitte neu laden.')); };
      document.head.append(script);
    }));
    return scripts.get(file);
  }
  function pickFile(accept, capture = false) {
    return new Promise(resolve => {
      const input = document.createElement('input');
      input.type = 'file'; input.accept = accept;
      if (capture) input.setAttribute('capture', 'environment');
      input.style.display = 'none'; document.body.append(input);
      const finish = file => { input.remove(); resolve(file); };
      input.addEventListener('change', () => finish(input.files?.[0] || null), {once: true});
      input.addEventListener('cancel', () => finish(null), {once: true});
      input.click();
    });
  }
  async function withOcr(action) {
    await loadScript('tesseract.min.js');
    const worker = await Tesseract.createWorker('deu+eng', 1, {
      workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@6.0.1/dist/worker.min.js',
      corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@6.0.0',
      langPath: 'https://tessdata.projectnaptha.com/4.0.0',
    });
    try { return await action(worker); } finally { await worker.terminate(); }
  }
  function textLines(items) {
    const rows = [];
    for (const item of items) {
      if (!item.str?.trim()) continue;
      const y = item.transform[5], x = item.transform[4];
      let row = rows.find(row => Math.abs(row.y - y) < 2);
      if (!row) { row = {y, items: []}; rows.push(row); }
      row.items.push({x, text: item.str});
    }
    return rows.sort((a, b) => b.y - a.y).map(row => row.items.sort((a,b) => a.x-b.x).map(item => item.text).join(' ')).join('\n');
  }
  async function pdfText(bytes) {
    const pdfjs = await import(vendor + 'pdf.min.mjs');
    pdfjs.GlobalWorkerOptions.workerSrc = vendor + 'pdf.worker.min.mjs';
    const loading = pdfjs.getDocument({data: bytes, isEvalSupported: false, stopAtErrors: true});
    let pdf;
    try {
      pdf = await loading.promise;
      if (pdf.numPages > 15) throw new Error('Bitte einen Bon mit höchstens 15 Seiten auswählen.');
      const pages = [];
      for (let n = 1; n <= pdf.numPages; n++) {
        const page = await pdf.getPage(n);
        const text = textLines((await page.getTextContent()).items);
        if (text.trim().length >= 30) { pages.push(text); continue; }
        // Scanned PDF pages need OCR instead of an invisible/empty text layer.
        const viewport = page.getViewport({scale: Math.min(2, 2500 / page.getViewport({scale: 1}).height)});
        const canvas = document.createElement('canvas');
        canvas.width = Math.ceil(viewport.width); canvas.height = Math.ceil(viewport.height);
        await page.render({canvasContext: canvas.getContext('2d'), viewport}).promise;
        pages.push(await withOcr(async worker => (await worker.recognize(canvas)).data.text));
        canvas.width = canvas.height = 0;
      }
      return pages.join('\n\n');
    } finally { await loading.destroy(); }
  }
  window.miseReadReceipt = async mode => {
    const file = await pickFile(mode === 'camera' ? 'image/*' : '.pdf,.txt,.csv,.jpg,.jpeg,.png,.webp,application/pdf,text/plain,image/*', mode === 'camera');
    if (!file) return JSON.stringify(null);
    if (file.size > 15 * 1024 * 1024) throw new Error('Die Datei darf höchstens 15 MB groß sein.');
    if (!file.size) throw new Error('Diese Datei ist leer.');
    const bytes = new Uint8Array(await file.arrayBuffer());
    const fingerprint = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))).map(b => b.toString(16).padStart(2, '0')).join('');
    let text;
    if (new TextDecoder().decode(bytes.slice(0, 5)) === '%PDF-') text = await pdfText(bytes);
    else if (/\.(?:txt|csv)$/i.test(file.name)) text = new TextDecoder('utf-8').decode(bytes);
    else if (file.type.startsWith('image/') || /\.(?:jpe?g|png|webp)$/i.test(file.name)) {
      text = await withOcr(async worker => (await worker.recognize(file)).data.text);
    } else throw new Error('Bitte einen PDF-Bon, ein JPG-/PNG-Bild oder eine Textdatei auswählen.');
    if (!text?.trim()) throw new Error('Kein lesbarer Text gefunden. Bitte einen schärferen Bon oder ein digitales PDF verwenden.');
    return JSON.stringify({text, name: file.name, fingerprint});
  };
  async function cameraCode() {
    await loadScript('zxing-browser.min.js');
    return new Promise((resolve, reject) => {
      const overlay = document.createElement('div');
      overlay.style.cssText = 'position:fixed;inset:0;z-index:99999;background:#193f35;color:white;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:20px;padding:24px;font:16px sans-serif';
      const title = document.createElement('p'); title.textContent = 'Produktbarcode in die Kamera halten';
      const video = document.createElement('video'); video.setAttribute('playsinline',''); video.muted = true; video.style.cssText = 'width:min(100%,640px);max-height:65vh;object-fit:contain';
      const cancel = document.createElement('button'); cancel.textContent = 'Abbrechen'; cancel.style.cssText = 'padding:14px 28px;border-radius:12px;border:0;font-size:16px';
      overlay.append(title, video, cancel); document.body.append(overlay); cancel.focus();
      let controls, done = false;
      const finish = (code, error) => {
        if (done) return; done = true; clearTimeout(timer);
        controls?.stop(); video.srcObject?.getTracks().forEach(track => track.stop());
        overlay.remove(); document.removeEventListener('keydown', onKey);
        error ? reject(error) : resolve(code);
      };
      const onKey = event => { if (event.key === 'Escape') finish(null); };
      document.addEventListener('keydown', onKey);
      cancel.onclick = () => finish(null);
      const timer = setTimeout(() => finish(null, new Error('Kein Barcode erkannt. Versuche ein Foto oder gib die Nummer ein.')), 60000);
      const reader = new ZXingBrowser.BrowserMultiFormatReader();
      reader.decodeFromConstraints({video: {facingMode: {ideal: 'environment'}}, audio: false}, video,
        (result, error, scanControls) => { controls = scanControls; if (done) {scanControls?.stop(); return;} if (result) finish(result.getText()); }
      ).then(value => { controls = value; if (done) controls.stop(); }).catch(error => finish(null, new Error('Kamera nicht verfügbar oder Zugriff abgelehnt. Bitte Barcode-Foto oder Nummer verwenden.')));
    });
  }
  window.miseScanBarcode = async camera => {
    if (camera) return JSON.stringify(await cameraCode());
    const file = await pickFile('image/*');
    if (!file) return JSON.stringify(null);
    if (file.size > 15 * 1024 * 1024) throw new Error('Das Bild darf höchstens 15 MB groß sein.');
    await loadScript('zxing-browser.min.js');
    const url = URL.createObjectURL(file);
    try { return JSON.stringify((await new ZXingBrowser.BrowserMultiFormatReader().decodeFromImageUrl(url)).getText()); }
    catch { throw new Error('Kein Produktbarcode erkannt. Bitte Nummer eingeben oder ein schärferes Foto verwenden.'); }
    finally { URL.revokeObjectURL(url); }
  };
  window.miseLookupBarcode = async code => {
    if (!/^\d{8,14}$/.test(code)) throw new Error('Ungültige Barcodenummer.');
    const response = await fetch('https://world.openfoodfacts.org/api/v2/product/' + code + '.json?fields=product_name_de,product_name,quantity,categories_tags&app_name=Kochmaster', {signal: AbortSignal.timeout(15000)});
    if (!response.ok) throw new Error('Die Produktdatenbank ist momentan nicht erreichbar. Bitte später erneut versuchen oder manuell erfassen.');
    const data = await response.json();
    return JSON.stringify(data.status === 1 ? data.product : null);
  };
})();
