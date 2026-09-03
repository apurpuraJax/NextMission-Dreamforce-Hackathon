const { chromium } = require('playwright');
const path = require('path');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
const PDF = path.resolve(__dirname, '../../test-files/sample_resume_91B.pdf');
(async () => {
  const b = await chromium.launch();
  const p = await b.newContext({ acceptDownloads: true }).then(c => c.newPage());
  const api = [];
  p.on('response', async r => { if (r.url().includes('apex/execute')) {
    let t=''; try { t=(await r.text()).slice(0,180); } catch(e){}
    api.push(r.status()+' '+t); } });
  const errs=[]; p.on('pageerror',e=>errs.push(e.message));
  await p.goto(URL,{waitUntil:'domcontentloaded',timeout:90000});
  await p.waitForTimeout(15000);
  await p.locator('input[type=file]').setInputFiles(PDF);
  await p.waitForTimeout(75000);
  const st = await p.evaluate(() => {
    const deep=(r,s,o=[])=>{o.push(...r.querySelectorAll(s));
      r.querySelectorAll('*').forEach(e=>e.shadowRoot&&deep(e.shadowRoot,s,o));return o;};
    return {
      err: (deep(document,'.nm-error')[0]||{}).textContent,
      bubbles: deep(document,'.nm-bubble').map(e=>e.textContent.replace(/\s+/g,' ').trim().slice(0,180)),
      dlBtn: deep(document,'.nm-resume-dl-btn').length,
      typing: deep(document,'.nm-bubble--typing').length
    };
  });
  console.log('error   :', st.err||'none');
  console.log('typing  :', st.typing, '| download button:', st.dlBtn);
  console.log('bubbles :'); st.bubbles.forEach(x=>console.log('   -',x));
  console.log('apex    :'); api.forEach(x=>console.log('   ',x));
  if (errs.length) console.log('errors  :', errs.slice(0,2));
  await b.close();
})();
