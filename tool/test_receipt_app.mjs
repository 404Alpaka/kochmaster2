import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFile,mkdir} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root=resolve('build/web');
const server=createServer(async(req,res)=>{
 const url=new URL(req.url,'http://localhost');
 const path=resolve(root,'.'+(url.pathname==='/'?'/index.html':url.pathname));
 if(!path.startsWith(root+sep)){res.writeHead(403).end();return;}
 try{res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.json':'application/json','.png':'image/png','.ttf':'font/ttf'})[extname(path)]||'application/octet-stream');res.end(await readFile(path));}catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const browser=await chromium.launch({channel:'chrome',headless:true});
const page=await browser.newPage({viewport:{width:390,height:900}});
const origin=`http://127.0.0.1:${server.address().port}`;
try{
 page.on('pageerror',error=>console.error('Page error:',error.message));
 await page.goto(origin);
 await page.waitForSelector('flt-semantics-placeholder',{state:'attached',timeout:60000});
 await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());
 await page.getByRole('button',{name:'Vorrat',exact:true}).click({timeout:60000});
 const upload=page.getByRole('button',{name:/Bon importieren/});
 await upload.scrollIntoViewIfNeeded();
 const chooser=page.waitForEvent('filechooser');
 await upload.click();await(await chooser).setFiles(resolve(process.argv[2]));
 await page.getByText('Einkauf erkannt.',{exact:true}).waitFor({timeout:60000});
 await mkdir('build/design',{recursive:true});
 await page.screenshot({path:'build/design/receipt-app-preview.png'});
 const confirm=page.getByRole('checkbox',{name:/Auswahl, Mengen und Lagerorte geprüft/});
 for(let i=0;i<12 && !(await confirm.count());i++){await page.mouse.move(160,450);await page.mouse.wheel(0,400);await page.waitForTimeout(150);}
 await confirm.scrollIntoViewIfNeeded();await confirm.click();
 await page.getByRole('button',{name:/Produkte zum Vorrat hinzufügen/}).click();
 await page.getByRole('button',{name:'Vorrat hinzufügen',exact:true}).waitFor();
 const stored=await page.evaluate(()=>JSON.parse(localStorage.getItem('mise-preferences-guest')));
 assert.ok(stored.pantry.length>40);
 assert.equal(stored.pantry.find(item=>item.name==='JA! H-MILCH 1,5%').amount,'12 Packungen');
 assert.ok(!stored.pantry.some(item=>item.name.includes('TOIPA')));
 assert.equal(stored.importedReceiptIds.length,1);
 assert.ok(!JSON.stringify(stored).includes('Kartenzahlung'));
 await page.screenshot({path:'build/design/receipt-app-pantry.png'});
 await page.reload();
 await page.waitForSelector('flt-semantics-placeholder',{state:'attached'});
 await page.evaluate(()=>document.querySelector('flt-semantics-placeholder').click());
 await page.getByRole('button',{name:'Vorrat',exact:true}).click();
 await page.getByRole('button',{name:'Vorrat hinzufügen',exact:true}).waitFor();
 console.log(`Flutter import: ${stored.pantry.length} pantry entries saved locally; package quantity and non-food exclusion verified; reload succeeded`);
} catch(error){await page.screenshot({path:'build/design/receipt-app-failure.png'});console.error((await page.locator('body').innerText()).slice(0,2500));throw error;}
finally{await browser.close();await new Promise(r=>server.close(r));}
