const { chromium } = require('playwright');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';

const HELPER = `
  window.__d = (sel) => {
    const out = [];
    const walk = (root) => {
      out.push(...root.querySelectorAll(sel));
      root.querySelectorAll('*').forEach(e => { if (e.shadowRoot) walk(e.shadowRoot); });
    };
    walk(document);
    return out;
  };
`;

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto(URL + '?nc=' + Date.now(), { waitUntil: 'domcontentloaded', timeout: 90000 });
  await p.waitForTimeout(15000);
  await p.evaluate(HELPER);

  const click = async (sel, match) => p.evaluate(([s, m]) => {
    const el = window.__d(s).find(x => x.textContent.toLowerCase().includes(m));
    if (!el) return false; el.click(); return true;
  }, [sel, match]);

  console.log('starter helicopters :', await click('.nm-chip', 'helicopter'));
  await p.waitForTimeout(26000);
  await p.evaluate(HELPER);
  console.log('chip "roles" clicked:', await click('.nm-chip', 'what jobs fit') || await click('.nm-chip', 'roles'));
  await p.waitForTimeout(36000);
  await p.evaluate(HELPER);

  const r = await p.evaluate(() => ({
    cardList:    window.__d('.nm-messages ul.nm-cards').length,
    cardItems:   window.__d('.nm-messages .nm-card-li').length,
    positions:   window.__d('.nm-messages .nm-card-title .nm-sr-only').map(e => e.textContent.trim()).slice(0, 6),
    showAll:     (window.__d('.nm-show-all')[0] || {}).textContent,
    stepButtons: window.__d('.nm-step-btn').length,
    stepLabels:  window.__d('.nm-step-btn .nm-step-label').map(e => e.textContent.trim()),
    stepStatus:  window.__d('.nm-steps .nm-sr-only').map(e => e.textContent.trim()),
    chips:       window.__d('.nm-chip').map(c => c.textContent.trim())
  }));
  console.log(JSON.stringify(r, null, 2));
  console.log('js errors:', errs.length ? errs.slice(0, 2) : 'none');
  await b.close();
})();
