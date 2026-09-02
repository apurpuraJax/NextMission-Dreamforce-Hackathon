# Accessibility — Next Mission

## The claim you can make

> The Next Mission site was scanned with **axe-core 4.13** (Deque Systems) driven
> through Playwright against the **live public site**, in two states: the landing
> page as an anonymous visitor, and mid-conversation with occupation cards
> rendered. Ruleset: **WCAG 2.0 Level A and AA plus WCAG 2.1 Level A and AA**.
>
> **Result: 0 violations. 53 checks passed.**
>
> Re-run 2026-09-02 after adding resume upload, which introduced a file input:
> still **0 violations**. The attach control was verified separately on the live
> site as a 44x44 target, correctly labelled, and reachable by keyboard.

Reproduce it:

```
cd scripts/a11y-scan && npm install && node scan.js
```

axe-core is the engine behind Lighthouse's accessibility audit and most
enterprise accessibility tooling, so this is the same check a judge would run.

## What was scanned, and why two states

An LWR site renders client side, so scanning the initial HTML alone would miss
everything a veteran actually reads. The scan drives a real conversation first
("Army 88M", then "show me the roles") so the occupation cards, suggestion
chips, journey stepper and live region are all in the DOM for the second pass.

| State | WCAG A/AA violations | Checks passed |
| --- | --- | --- |
| Landing page, anonymous | **0** | 26 |
| Mid-conversation, cards rendered | **0** | 27 |

## What is NOT clean, stated plainly

One **best-practice** finding remains, which is advisory and not required for
AA conformance:

* `region` — "All page content should be contained by landmarks", raised on
  `<a class="skip-to-main">Skip to Main</a>`. That element is **Salesforce's own
  Experience Cloud theme markup**, not ours. It is not editable from our
  components and does not affect AA conformance.

Two items come back as **"needs review"** rather than pass or fail, and both are
artefacts of Lightning Web Components rather than defects:

* `aria-valid-attr-value` on five `aria-labelledby` references. LWC rewrites
  `id` attributes to keep them unique (`nm-how` becomes `nm-how-25`) and rewrites
  the references to match, so they resolve correctly. axe cannot traverse the
  shadow boundary to confirm the target exists.
* `color-contrast` on one visually hidden `<label>`. The text is clipped for
  screen readers only, so contrast does not apply to it.

## Beyond the automated scan

Automated tools catch roughly a third of accessibility problems. These were done
by hand:

**Measured contrast** (`python3 scripts/check_contrast.py`) — 19 widget pairs and
16 page pairs, **0 failing**. Body copy 7.70:1 to 15.85:1, headings 9.11:1, focus
ring 7.14:1 on white and 6.56:1 on cream.

Two greens exist deliberately. `#14532D` pine is the only green used for text, at
9.11:1. `#3F9142` signal green is 3.93:1, **never carries text**, and appears only
as rules, card edges and typing dots where the 3:1 non-text threshold applies. No
red appears in the page components, so green never conveys meaning against red.

**Keyboard, confirmed by hand on the published site** — tab order is correct, and
there is **no keyboard trap**: tabbing past the widget reaches the page and then
the browser address bar.

**Focus visibility** — five `:focus-visible` rules, all adding a 3px ring, none
removing one. The Experience Cloud theme stylesheets contain zero `outline: none`.

**Screen reader** — VoiceOver testing found that agent replies were not being
announced. Cause: `aria-busy` on the live region suppresses announcements, and
`role="log"` on a re-rendered list is unreliable. Fixed with a dedicated always
present `aria-live="polite" aria-atomic="true"` region carrying only the newest
reply, and by removing a competing `aria-label` that was overriding the input's
`<label>`.

**Also honoured**: `prefers-reduced-motion` disables entrance and typing
animations, 44px touch targets on every control, nothing conveys meaning by
colour alone, and every string comes from a custom label.

## Still open

* Reflow at 200% and 400% zoom has not been tested.
* A full screen reader pass beyond the fixes above.

Neither is claimed as done.
