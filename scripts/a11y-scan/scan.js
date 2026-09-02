/**
 * axe-core accessibility scan of the LIVE Next Mission site.
 *
 * Scans the page as an anonymous visitor, then again after a real conversation
 * has been started, because the chat renders its results client side and a scan
 * of the initial page alone would miss everything the veteran actually reads.
 *
 * Ruleset: WCAG 2.0 A/AA + WCAG 2.1 A/AA + best practices.
 *   node scan.js
 */
const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');

const URL = process.env.NM_URL || 'https://orgfarm-3bfff135af.my.site.com/nextmission/';
const WCAG = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];
const BEST = ['best-practice'];

function report(label, results, kind) {
  const v = results.violations;
  console.log('\n' + '='.repeat(72));
  console.log(`${label}  [${kind}]`);
  console.log(`  passes: ${results.passes.length}   violations: ${v.length}   incomplete: ${results.incomplete.length}`);
  console.log('='.repeat(72));
  for (const issue of v) {
    console.log(`\n  [${issue.impact}] ${issue.id} — ${issue.help}`);
    console.log(`     ${issue.helpUrl.split('?')[0]}`);
    console.log(`     tags: ${issue.tags.filter(t => t.startsWith('wcag')).join(', ')}`);
    for (const node of issue.nodes.slice(0, 3)) {
      console.log(`     -> ${node.html.replace(/\s+/g, ' ').slice(0, 110)}`);
    }
    if (issue.nodes.length > 3) console.log(`     ...and ${issue.nodes.length - 3} more`);
  }
  for (const inc of results.incomplete) {
    console.log(`\n  [needs review] ${inc.id} — ${inc.help} (${inc.nodes.length} node(s))`);
    for (const n of inc.nodes.slice(0, 5)) {
      console.log(`     -> ${n.html.replace(/\s+/g, ' ').slice(0, 120)}`);
      if (n.any && n.any[0] && n.any[0].message) console.log(`        ${n.any[0].message.slice(0, 130)}`);
    }
  }
  return v.length;
}

(async () => {
  const browser = await chromium.launch();
  // axe-core requires an explicit context, not browser.newPage().
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const page = await context.newPage();
  let total = 0;
  try {
    // LWR keeps connections open, so networkidle never fires. Wait for the
    // widget itself to exist instead.
    await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForSelector('.nm-widget', { timeout: 90000 }).catch(() => {});
    await page.waitForSelector('input.nm-input', { state: 'attached', timeout: 90000 }).catch(() => {});
    await page.waitForTimeout(8000);

    total += report('STATE 1 — landing page as an anonymous visitor',
      await new AxeBuilder({ page }).withTags(WCAG).analyze(), 'WCAG 2.0/2.1 A + AA');
    report('STATE 1 — best practice (advisory, not required for AA)',
      await new AxeBuilder({ page }).withTags(BEST).analyze(), 'best-practice');

    // Drive a real turn so cards, chips, the stepper and the mentor block are
    // all in the DOM when the second scan runs.
    // LWC rewrites id attributes to keep them unique, so #nm-input never matches.
    const input = page.locator('input.nm-input').first();
    console.log(`\n  widget present: ${await page.locator('.nm-widget').count() > 0}, input present: ${await input.count() > 0}`);
    if (await input.count()) {
      await input.fill('Army 88M');
      await input.press('Enter');
      await page.waitForTimeout(25000);
      await input.fill('show me the roles');
      await input.press('Enter');
      await page.waitForTimeout(30000);
      total += report('STATE 2 — mid-conversation, occupation cards rendered',
        await new AxeBuilder({ page }).withTags(WCAG).analyze(), 'WCAG 2.0/2.1 A + AA');
      report('STATE 2 — best practice (advisory, not required for AA)',
        await new AxeBuilder({ page }).withTags(BEST).analyze(), 'best-practice');
    } else {
      console.log('\n  (chat input not found; conversation state not scanned)');
    }
  } finally {
    await browser.close();
  }
  console.log(`\nTOTAL VIOLATIONS: ${total}`);
  process.exit(total === 0 ? 0 : 1);
})();
