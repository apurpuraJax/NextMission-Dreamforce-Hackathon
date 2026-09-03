const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
const PDF = path.resolve(__dirname, '../../test-files/sample_resume_91B.pdf');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ acceptDownloads: true });
  const p = await ctx.newPage();
  const errs=[]; p.on('pageerror',e=>errs.push('PAGEERROR '+e.message));
  p.on('console',m=>{ if(m.type()==='error') errs.push('CONSOLE '+m.text().slice(0,160)); });
  await p.goto(URL,{waitUntil:'domcontentloaded',timeout:90000});
  await p.waitForTimeout(15000);
  await p.locator('input[type=file]').setInputFiles(PDF);
  await p.locator('.nm-resume-dl-btn').waitFor({state:'visible',timeout:180000});
  console.log('download button appeared');

  const dl = p.waitForEvent('download',{timeout:120000}).catch(e=>null);
  await p.locator('.nm-resume-dl-btn').click();
  console.log('clicked; waiting for the agent and the file...');
  const download = await dl;

  if (download) {
    const out='/tmp/nm_resume_out.doc';
    await download.saveAs(out);
    const txt=fs.readFileSync(out,'utf8');
    console.log('filename :', download.suggestedFilename());
    console.log('bytes    :', fs.statSync(out).size);
    console.log('is a doc :', txt.includes('urn:schemas-microsoft-com'));
    console.log('has name :', /Caldwell/i.test(txt));
    console.log('bullets  :', (txt.match(/<li/g)||[]).length);
    console.log('skills   :', /Skills/i.test(txt));
  } else {
    console.log('NO DOWNLOAD EVENT');
    const st = await p.evaluate(() => {
      const deep=(r,s,o=[])=>{o.push(...r.querySelectorAll(s));
        r.querySelectorAll('*').forEach(e=>e.shadowRoot&&deep(e.shadowRoot,s,o));return o;};
      return { err:(deep(document,'.nm-error')[0]||{}).textContent,
               last:(deep(document,'.nm-bubble').slice(-1)[0]||{}).textContent };
    });
    console.log('error   :', st.err||'none');
    console.log('last msg:', (st.last||'').replace(/\s+/g,' ').slice(0,300));
  }
  console.log('js errors:', errs.length?errs.slice(0,3):'none');
  await b.close();
})();
