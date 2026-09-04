# Next Mission — hero graphic

Replacement for the road illustration in the hero. One military specialty code fans out
into named civilian occupations with real federal wage figures. Three codes cycle, six
seconds each, across three service branches.

---

## Files

| File | What it is |
|---|---|
| `nextmission-hero.html` | **The component.** Self-contained markup + `<style>` + `<script>`. No external fonts, images or libraries. |
| `nextmission-cover.png` | 1600×900 hackathon cover @2×. |
| `nextmission-cover-it.png` | Same cover, leading with the 25B cyber mapping. |
| `nextmission-hero-3531-marine-transport.png` | Card alone, Marine Corps 3531 @3×. |
| `nextmission-hero-hm-navy-corpsman.png` | Card alone, Navy HM @3×. |
| `nextmission-hero-25b-army-it.png` | Card alone, Army 25B @3×. |
| `nextmission-mark.svg` / `.png` | Logo mark. Two service chevrons, and a third that has broken formation and become an arrow. |
| `nextmission-logo.svg` / `.png` | Horizontal lockup with tagline. |
| `cover.template.html`, `render.js`, `shoot.js`, `audit.js` | Sources — regenerate the PNGs or re-run the audit. |

---

## Embedding

**Experience Builder** — add an HTML component (or Rich Content Editor in source mode) and
paste the whole of `nextmission-hero.html`. Nothing else to configure.

**LWC** — split the three blocks into `nextMissionHero.html`, `.css`, and the script into
`connectedCallback`. Locker/Lightning Web Security is fine with all of it: no `eval`, no
`document.write`, no globals.

**Sizing.** It is responsive and container-query driven. Your current hero image slot is
about 426px wide, where it works but gets tight. **560–680px is the sweet spot** — if you can
let that column grow, do. Below ~336px of content width it collapses to a single labelled
column on its own.

**Fonts.** It asks for Poppins first and falls back cleanly to the system stack. If your site
already loads a brand face, change `--nm-font` at the top of the CSS and everything follows.

**Recolouring.** All colour lives in eleven custom properties on `.nm-hero`. Change those and
nothing else. If you shift the greens, re-check contrast — the current values have ~0.15
of headroom over the AA floor at the tightest pair, not a lot.

**Changing the data.** Each scene is one `.nm-scene` block: a chip (branch / code / title)
and three `.nm-node` items. Copy a block, change the strings, bump `--s` by 6s, and update
`--nm-cycle` to `scenes × 6s`. The screen-reader list at the bottom is a separate copy of
the same data — **update it too**, or it goes stale silently.

---

## Accessibility

This is the part I'd read before shipping.

- **Motion never starts uninvited.** If the visitor's OS asks for reduced motion, the graphic
  loads fully composed and paused, and the button says Play. It's opt-in from there.
  *(WCAG 2.3.3)*
- **Visible pause control.** The loop runs longer than five seconds, which obliges a stop
  mechanism. Real `<button>`, keyboard reachable, `aria-pressed`, visible focus ring. *(2.2.2)*
- **Nothing lives only in the animation.** The stage is `aria-hidden`; all three mappings and
  all nine wage figures sit below it as headings and lists, so a screen reader gets the whole
  set rather than whichever scene happened to be showing. *(1.1.1)*
- **Contrast.** Tightest text pair 5.20:1 (branch label on the dark chip); body-size text
  6.7:1–10.3:1; connectors 4.65:1, markers 9.81:1, button border 4.89:1 against a 3:1 floor.
  *(1.4.3, 1.4.11)*
- **No meaning in colour alone.** Every node is named. *(1.4.1)*
- **Real text, not text in an image.** All type is HTML in `rem`, so it honours the visitor's
  own font size — verified intact at a 24px root. *(1.4.4)*
- **Reflow** to a single column with no horizontal scroll and nothing clipped. *(1.4.10)*
- **No flashing.** Opacity fades and a slow dash drift, nowhere near 3Hz. *(2.3.1)*
- **Windows High Contrast** handled explicitly — a `forced-colors` block restores borders to
  everything that relied on a background fill.
- **Works with JavaScript off**: static, complete, legible.

Verified with axe-core against WCAG 2.2 AA — **zero violations**. Contrast ratios computed
from the tokens (`node audit.js` re-runs both).

### One thing deliberately not shipped

A standalone animated `.svg`. An SVG loaded as an image can't carry a pause button, and a
looping animation with no way to stop it fails 2.2.2 — on the one project where that would be
least forgivable. The HTML component does everything the SVG would have done, and yields.

---

## The wage figures

All nine are published BLS medians, **May 2025 OEWS**, not illustrative numbers.

| Specialty | Civilian occupation | Median / yr |
|---|---|---|
| USMC 3531 · Motor Vehicle Operator | Transportation, Storage & Distribution Manager | $107,230 |
| | Logistician | $82,320 |
| | Heavy & Tractor-Trailer Truck Driver | $58,640 |
| USN HM · Hospital Corpsman | Registered Nurse | $97,550 |
| | Surgical Technologist | $64,650 |
| | Paramedic | $60,600 |
| USA 25B · Information Technology Specialist | Information Security Analyst | $129,180 |
| | Network & Computer Systems Administrator | $99,130 |
| | Computer User Support Specialist | $61,860 |

Caveat: BLS retired the static per-occupation OEWS pages for the current period, so these come
from the Occupational Outlook Handbook, which quotes the same OEWS medians. Two of them are
narrower than the headline figure on their OOH page — Paramedics (29-2043) alone rather than
combined EMTs-and-paramedics, and Surgical Technologists (29-2055) alone rather than combined
with surgical assistants. Both are the correct figures for the titles shown.

Before you demo, swap these for whatever your own pipeline returns. The point of the graphic
is that the numbers come from your data.
