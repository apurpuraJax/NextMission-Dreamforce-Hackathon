const { chromium } = require('playwright');
const URL = 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await p.waitForTimeout(6000);

  const r = await p.evaluate(() => {
    const deep = (root, sel, out = []) => {
      out.push(...root.querySelectorAll(sel));
      root.querySelectorAll('*').forEach(e => e.shadowRoot && deep(e.shadowRoot, sel, out));
      return out;
    };
    const f = deep(document, 'input[type=file]')[0];
    const l = deep(document, '.nm-attach')[0];
    if (!f) return { found: false };
    const cs = getComputedStyle(f);
    return {
      found: true,
      accept: f.accept,
      disabled: f.disabled,
      display: cs.display,
      visibility: cs.visibility,
      labelledBy: l ? (l.getAttribute('for') === f.id) : false,
      srText: l ? (l.textContent || '').trim() : null,
      labelBox: l ? l.getBoundingClientRect().width + 'x' + l.getBoundingClientRect().height : null
    };
  });
  console.log(JSON.stringify(r, null, 2));

  // Can a keyboard reach it? Tab through and see if it ever gets focus.
  await p.keyboard.press('Tab');
  let hit = false, chain = [];
  for (let i = 0; i < 30 && !hit; i++) {
    const cur = await p.evaluate(() => {
      let el = document.activeElement;
      while (el && el.shadowRoot && el.shadowRoot.activeElement) el = el.shadowRoot.activeElement;
      return el ? (el.tagName + (el.type ? '[' + el.type + ']' : '') + (el.className ? '.' + String(el.className).split(' ')[0] : '')) : 'none';
    });
    chain.push(cur);
    if (/INPUT\[file\]/.test(cur)) hit = true; else await p.keyboard.press('Tab');
  }
  console.log('reachable by keyboard:', hit);
  console.log('tab order:', chain.slice(-8).join(' -> '));
  await b.close();
})();
