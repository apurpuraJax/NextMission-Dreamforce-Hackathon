# Browser checks

Everything here drives a real browser. That matters more than it sounds: the
resume upload was completely broken for real visitors for hours while every
API-level test passed, because an admin calling Apex directly is not a guest
user in a Lightning Web Security sandbox.

| Script | What it proves |
| --- | --- |
| `scan.js` | axe-core against the live site, landing state and mid-conversation. WCAG 2.0 and 2.1, A and AA. This is the run behind the published accessibility claim. |
| `keyboard_check.js` | The attach control is present, labelled, 44x44, and reachable by keyboard in a sensible tab order. |
| `resume_e2e.js` | Attaches a real PDF and follows it through extraction, the agent's reply, and the download. |

```
cd scripts/a11y-scan && npm install
node scan.js
```
