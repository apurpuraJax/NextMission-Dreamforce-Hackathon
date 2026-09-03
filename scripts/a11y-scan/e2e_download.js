const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
const RESUME = path.resolve(__dirname, '../../test-files/sample_resume_91B.pdf');

(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ acceptDownloads: true });
  const p = await ctx.newPage();
  const errors = [];
  p.on('pageerror', e => errors.push('pageerror: ' + e.message));
  p.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text().slice(0,160)); });

  await p.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await p.waitForTimeout(9000);

  const fileInput = p.locator('input[type=file]');
  console.log('attach control present :', await fileInput.count() > 0);
  await fileInput.setInputFiles(RESUME);
  console.log('resume attached        : yes');

  // Wait for the button rather than guessing a duration. PDF extraction plus
  // the agent round trip can take well over a minute on a cold page.
  await p.locator('.nm-resume-dl-btn').waitFor({ state: 'visible', timeout: 180000 })
        .catch(() => console.log('download button never appeared within 180s'));
  const transcript = await p.evaluate(() => {
    const deep = (r, s, o=[]) => { o.push(...r.querySelectorAll(s));
      r.querySelectorAll('*').forEach(e => e.shadowRoot && deep(e.shadowRoot, s, o)); return o; };
    return deep(document, '.nm-bubble').map(e => e.textContent.replace(/\s+/g,' ').trim());
  });
  console.log('agent replied          :', transcript.length > 1);
  console.log('reply preview          :', (transcript[transcript.length-1]||'').slice(0,150));

  const dl = p.locator('.nm-resume-dl-btn');
  const dlVisible = await dl.count() > 0;
  console.log('download button shown  :', dlVisible);

  if (dlVisible) {
    const [download] = await Promise.all([
      p.waitForEvent('download', { timeout: 90000 }).catch(() => null),
      dl.click()
    ]);
    if (download) {
      const out = '/tmp/nm_resume_out.doc';
      await download.saveAs(out);
      const size = fs.statSync(out).size;
      const head = fs.readFileSync(out, 'utf8').slice(0, 300);
      console.log('download filename      :', download.suggestedFilename());
      console.log('download bytes         :', size);
      console.log('opens as a document    :', head.includes('<html') && head.includes('urn:schemas-microsoft-com'));
      console.log('contains a real name   :', /CALDWELL|Caldwell/i.test(fs.readFileSync(out,'utf8')));
      console.log('contains bullets       :', (fs.readFileSync(out,'utf8').match(/<li/g)||[]).length);
    } else {
      console.log('DOWNLOAD DID NOT FIRE');
    }
  }
  console.log('JS errors              :', errors.length ? errors.slice(0,3) : 'none');
  await b.close();
})();
