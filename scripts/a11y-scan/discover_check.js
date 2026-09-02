const { chromium } = require('playwright');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await p.waitForTimeout(9000);
  const r = await p.evaluate(() => {
    const deep = (root, sel, out = []) => {
      out.push(...root.querySelectorAll(sel));
      root.querySelectorAll('*').forEach(e => e.shadowRoot && deep(e.shadowRoot, sel, out));
      return out;
    };
    const txt = el => (el.textContent || '').replace(/\s+/g, ' ').trim();
    const greeting = deep(document, '.nm-bubble').map(txt)[0] || '';
    const attach = deep(document, '.nm-attach')[0];
    const page = txt(document.body).toLowerCase();
    return {
      greetingMentionsResume: /resume|paperclip/i.test(greeting),
      greeting: greeting.slice(0, 260),
      attachTooltip: attach ? attach.getAttribute('title') : null,
      siteMentionsResumeRewrite: page.includes('resume rewritten') || page.includes('rewrite'),
      siteMentionsWordDoc: page.includes('word document'),
      siteMentionsNeverUploaded: page.includes('never uploaded')
    };
  });
  console.log(JSON.stringify(r, null, 2));
  await b.close();
})();
