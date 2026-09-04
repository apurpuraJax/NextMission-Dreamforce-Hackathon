/*
 * The hero graphic, checked in a real browser at real widths.
 *
 * The one that matters is mobile. The art it replaced was decorative and was
 * hidden below 46rem with display:none. This graphic is NOT decorative: it
 * carries nine wage figures and the screen-reader copy of the whole data set.
 * Hiding it on a phone would take real content away from the people most
 * likely to be on one. This fails if it is not visible on a phone.
 *
 *   node hero_check.js
 */
const { chromium } = require('playwright-core');

const URL = process.env.NM_URL || 'https://orgfarm-3bfff135af.my.site.com/nextmission/';

const FIGURES = ['$107,230','$82,320','$58,640','$97,550','$64,650',
                 '$60,600','$129,180','$99,130','$61,860'];

// Anything the agent does not hold. If one of these is on the page the hero and
// the agent are quoting different numbers for the same job, in one screenshot.
const STALE = ['$102,010','$80,880','$57,440','$93,600','$62,830',
               '$58,410','$124,910','$96,800','$60,340','May 2024'];

let failures = 0;
function check(ok, label, detail) {
  if (!ok) failures++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'} ${label}${detail ? '  ' + detail : ''}`);
}

(async () => {
  const browser = await chromium.launch();

  for (const vp of [
    { name: 'desktop', width: 1280, height: 900 },
    { name: 'tablet',  width: 820,  height: 1180 },
    { name: 'phone',   width: 390,  height: 844 },
    { name: 'small phone', width: 320, height: 700 }
  ]) {
    const ctx  = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
    const page = await ctx.newPage();
    // domcontentloaded, not networkidle: the chat widget keeps a connection
    // open, so networkidle never fires on this page.
    await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForSelector('figure.nm-art', { timeout: 60000 }).catch(() => {});
    await page.waitForTimeout(4000);

    console.log(`\n── ${vp.name} (${vp.width}x${vp.height}) ──`);

    const art = page.locator('figure.nm-art').first();
    const count = await art.count();
    check(count > 0, 'graphic is in the DOM');
    if (count === 0) { await ctx.close(); continue; }

    // The whole point on mobile.
    check(await art.isVisible(), 'graphic is VISIBLE (not display:none)');

    const box = await art.boundingBox();
    check(!!box && box.width > 0 && box.height > 0, 'graphic has real size',
          box ? `${Math.round(box.width)}x${Math.round(box.height)}` : '');

    // Page-level sideways scroll, reported but NOT counted against the hero.
    // At 320px the page overflows by ~69px and the cause is Salesforce's own
    // component-wrapper-spacer around the chat widget: the host measures 377px
    // while none of its children exceed 320. That is LWR page layout, fixable
    // in Builder, and it predates this graphic. Attributing it here would send
    // the next person to rewrite CSS that is not the problem.
    const overflow = await page.evaluate(() =>
      document.documentElement.scrollWidth - document.documentElement.clientWidth);
    if (overflow > 1) {
      console.log(`  NOTE page scrolls sideways by ${overflow}px (LWR wrapper, not the hero)`);
    } else {
      check(true, 'no horizontal page scroll');
    }

    // What IS the hero's responsibility: it must never be wider than the viewport.
    const fits = !!box && box.width <= vp.width + 1;
    check(fits, 'graphic fits the viewport',
          box ? `${Math.round(box.width)}px in ${vp.width}px` : '');

    // Nothing sticking out of the card.
    const spill = await page.evaluate(() => {
      const a = document.querySelector('figure.nm-art');
      if (!a) return -1;
      const ar = a.getBoundingClientRect();
      let worst = 0;
      a.querySelectorAll('*').forEach(el => {
        const r = el.getBoundingClientRect();
        if (r.width === 0) return;
        worst = Math.max(worst, Math.round(r.right - ar.right));
      });
      return worst;
    });
    check(spill <= 2, 'no content spills out of the card', `worst ${spill}px`);

    // Pause control: present, operable, and big enough to hit.
    const btn = page.locator('figure.nm-art button.nm-toggle').first();
    check(await btn.count() > 0, 'pause control present');
    if (await btn.count() > 0) {
      const b = await btn.boundingBox();
      check(!!b && b.width >= 44 && b.height >= 44, 'control is at least 44x44',
            b ? `${Math.round(b.width)}x${Math.round(b.height)}` : '');
      const label = (await btn.innerText()).trim();
      check(/Pause animation|Play animation/.test(label), 'control is labelled', `"${label}"`);
    }

    const text = await page.locator('figure.nm-art').first().innerText();
    const html = await page.locator('figure.nm-art').first().innerHTML();

    // Every figure, including the screen-reader copy, comes from our data.
    const missing = FIGURES.filter(f => !html.includes(f));
    check(missing.length === 0, 'all nine stored figures present',
          missing.length ? 'missing ' + missing.join(', ') : '');

    const stale = STALE.filter(f => html.includes(f));
    check(stale.length === 0, 'no figure the agent does not hold',
          stale.length ? 'FOUND ' + stale.join(', ') : '');

    check(html.includes('May&nbsp;2025') || text.includes('May 2025'),
          'cites the release the agent actually uses');

    await ctx.close();
  }

  // Reduced motion: nothing may animate, and the control must say Play.
  console.log('\n── prefers-reduced-motion: reduce ──');
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 900 }, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await page.waitForSelector('figure.nm-art', { timeout: 60000 }).catch(() => {});
  await page.waitForTimeout(4000);

  const pressed = await page.locator('figure.nm-art button.nm-toggle').first()
    .getAttribute('aria-pressed');
  check(pressed === 'false', 'motion is OFF by default', `aria-pressed=${pressed}`);

  const label = (await page.locator('figure.nm-art button.nm-toggle').first().innerText()).trim();
  check(/Play animation/.test(label), 'control offers Play, not Pause', `"${label}"`);

  const animating = await page.evaluate(() => {
    const els = document.querySelectorAll('figure.nm-art .nm-scene, figure.nm-art .nm-node');
    let n = 0;
    els.forEach(el => {
      const a = getComputedStyle(el).animationName;
      if (a && a !== 'none') n++;
    });
    return n;
  });
  check(animating === 0, 'nothing is animating', `${animating} animated element(s)`);

  // And the data is still all there when the animation never runs.
  const html = await page.locator('figure.nm-art').first().innerHTML();
  const missing = FIGURES.filter(f => !html.includes(f));
  check(missing.length === 0, 'all figures still present with motion off',
        missing.length ? 'missing ' + missing.join(', ') : '');

  await ctx.close();
  await browser.close();

  console.log('\n' + (failures === 0 ? 'HERO OK AT EVERY WIDTH' : `${failures} CHECK(S) FAILED`));
  process.exit(failures ? 1 : 0);
})();
