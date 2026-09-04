# Next Mission

An Agentforce agent that translates military experience into civilian careers, for
veterans and military spouses.

**Live:** https://orgfarm-3bfff135af.my.site.com/nextmission/

Give it a specialty code, describe what you did in your own words, or upload a
resume. It maps that to real civilian occupations, tells you what they pay
nationally, rewrites a military resume into civilian language, and introduces you
to a mentor who made the same move.

Built for the **DF26 Agentforce for Good Hackathon**, Builder Track, Vetforce prompt.

---

## Try these

| Type this | What it shows |
| --- | --- |
| `Army 68W` then `the roles it matches` | A code with a clean civilian mapping |
| `Navy V25C` | A code with **no** civilian equivalent. It says so instead of inventing one |
| `Army 92Y` then `what do those pay?` | Real BLS figures, sourced in the same reply |
| `I fixed helicopters in the Marines` | No code at all, classified from the description |
| Attach `test-files/full_resume_navy_hm.pdf` | Resume read in the browser, never uploaded |

---

## How it is built

Seven subagents carry the conversation: greeting and background, describing service
in plain words, skills translation, job matching, resume rewriting, mentor
connection, and the introduction. Four prompt templates sit behind them.

The agent runs **headless behind the Agentforce API**. The Lightning web component
on the Experience Cloud site is one client, not the product.

**Grounding.** 8,179 military specialty codes across all six branches map to 1,016
civilian occupations via the O*NET military crosswalk. Pay comes from BLS
Occupational Employment and Wage Statistics, **May 2025**, 992 occupations priced.
Nothing comes from the model's memory.

| Path | What lives there |
| --- | --- |
| `force-app/main/default/aiAuthoringBundles/` | The agent itself, Agent Script |
| `force-app/main/default/classes/` | Apex actions and the output verification |
| `force-app/main/default/lwc/` | Site components: hero, chat widget, about panel |
| `force-app/main/default/genAiPromptTemplates/` | The four prompt templates |
| `scripts/` | Every regression suite below |

---

## Verify the claims yourself

Nothing here is asserted without a command that produces it.

```bash
# Conversation quality, graded on OUTCOME by a second agent, not keyword-matched
python3 scripts/sim_eval.py

# 47 scripted conversations across branches, codes, free text and edge cases
python3 scripts/broad_run.py

# Every dollar figure the agent prints must exist in NM_Wage__c
python3 scripts/wage_truth.py

# Every mentor named must be real, and described with their actual job
python3 scripts/mentor_truth.py

# Accessibility: axe-core against the LIVE site, two states, WCAG 2.0/2.1 A+AA
cd scripts/a11y-scan && npm install && node scan.js

# Contrast: every colour pair measured, not eyeballed
python3 scripts/check_contrast.py

# 162 Apex tests
sf apex run test --test-level RunLocalTests
```

Latest results: **162/162** Apex tests, **47/47** conversations clean, 11 journeys
at **mean 8.4** with none below 7, every wage figure and mentor name verified,
**0 WCAG violations**, 39 contrast pairs with none failing.

---

## How it stays honest

Every pay figure is verified against stored BLS data before the veteran sees it.
The check is arithmetic, not a second model call, and each activation is logged to
`NM_Guardrail_Event__c` so the failure rate is visible rather than assumed.

**A second agent watches the first.** An LLM evaluator reads real logged
conversations and scores each 1 to 10 with issue tags. Quality is measured, not
claimed.

The agent explains and recommends; the human decides. It never scores a veteran,
never ranks them, never tells them what they are qualified for, and never filters
anyone out.

---

## Privacy

No login and no account. A resume is read in the browser and only its text is sent;
the file is never uploaded. Transcripts are scrubbed after 90 days, keeping the
anonymous aggregates and dropping the narrative.

---

## More

| Document | What is in it |
| --- | --- |
| [ACCESSIBILITY.md](ACCESSIBILITY.md) | The scan, the ruleset, the numbers, and how to reproduce them |
| [CONTEXT.md](CONTEXT.md) | Full engineering context: architecture, every decision, and every failure with what it cost |
| [MODEL-REVIEW-2026-09-01.md](MODEL-REVIEW-2026-09-01.md) | Which model each prompt template uses, and why |
| [FINDINGS-2026-09-01.md](FINDINGS-2026-09-01.md) | Agent quality findings |
| [TRIAGE-2026-09-01.md](TRIAGE-2026-09-01.md) | Defect triage |

`CONTEXT.md` is written for whoever picks this up next and does not flatter the
build. If you want to know what actually went wrong and how it was fixed, read that
one.
