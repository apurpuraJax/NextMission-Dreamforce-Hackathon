const { chromium } = require('playwright');
const path = require('path');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
const RESUME = path.resolve(__dirname, '../../test-files/sample_resume_91B.pdf');
(async () => {
  const b = await chromium.launch();
  const p = await b.newContext({ acceptDownloads: true }).then(c => c.newPage());
  const logs = [];
  p.on('pageerror', e => logs.push('PAGEERROR ' + e.message));
  p.on('console', m => logs.push('CONSOLE[' + m.type() + '] ' + m.text().slice(0,200)));
  p.on('requestfailed', r => logs.push('REQFAIL ' + r.url().slice(0,120) + ' :: ' + (r.failure()||{}).errorText));
  const apiCalls = [];
  p.on('response', async r => {
    if (r.url().includes('apex/execute')) {
      let body = '';
      try { body = (await r.text()).slice(0, 200); } catch(e) {}
      apiCalls.push(r.status() + ' ' + body);
    }
  });
  await p.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await p.waitForTimeout(20000);
  await p.locator('input[type=file]').setInputFiles(RESUME);
  await p.waitForTimeout(60000);

  const state = await p.evaluate(() => {
    const deep = (r, s, o=[]) => { o.push(...r.querySelectorAll(s));
      r.querySelectorAll('*').forEach(e => e.shadowRoot && deep(e.shadowRoot, s, o)); return o; };
    const err = deep(document, '.nm-error')[0];
    return {
      errorShown: err ? err.textContent.replace(/\s+/g,' ').trim() : null,
      typing: deep(document, '.nm-bubble--typing').length,
      bubbles: deep(document, '.nm-bubble').length,
      pdfjsLoaded: typeof window.pdfjsLib !== 'undefined'
    };
  });
  console.log('STATE:', JSON.stringify(state, null, 2));
  console.log('\nAPEX CALLS:'); apiCalls.forEach(c => console.log('  ', c));
  console.log('\nLOGS:'); logs.slice(0,14).forEach(l => console.log('  ', l));
  await b.close();
})();
