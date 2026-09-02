# Prompt template and model review

All four templates currently run **`sfdc_ai__DefaultOpenAIGPT4OmniMini`**.
Measured against what each one is actually handed.

| Template | Input handed to it | Task type | Verdict |
| --- | --- | --- | --- |
| `NM_Classify_Cluster_Template` | ~40 tokens | pick 1 of 9 | **Keep mini** |
| `NM_Translate_Skills_Template` | ~700–1,000 tokens | short generation | **Keep mini** |
| `NM_QA_Evaluator_Template` | median 232, max 1,341 tokens | judge + structured JSON | **Upgrade** |
| `NM_Find_Mentor_Template` | **2,064 today → 6,062 after the mentor load** | pick 1 of 75, with judgment | **Fix the input first, then upgrade** |

---

## The one that matters: find_mentor

`NM_FindMentor_Flow` passes the **entire active roster** into the prompt. Loading
the 56 staged mentors takes that from 2,064 to **6,062 tokens**, and turns the
task from "choose among 19" into "choose among 75".

That is the shape of task small models are worst at. Not reasoning, but
**selection across a long list**, where they skew toward items near the start and
end and lose the middle.

### What it does today, measured

Six real descriptions run through the live flow:

| Description | Match returned | Read |
| --- | --- | --- |
| Army 68W combat medic | Cameron J., Physician Assistant | good |
| Navy IT, shipboard networks | Jordan M., Network Security Engineer | good |
| Army 88M truck driver | Reese H., Operations Director | acceptable |
| Coast Guard Boatswain's Mate | Alex R., Supply Chain Manager | acceptable, no CG mentor exists |
| Air Force avionics, **never a pilot** | **no match, three times running** | **correct** |
| Military spouse, portable admin work | Cameron J., Physician Assistant | **wrong** |

**Credit where it is due:** the avionics case returned nothing on three
consecutive runs, and that is the right answer. The only two Aviation mentors are
both **pilots**, and the veteran said they never flew. The model declined rather
than forcing a bad match, which is exactly what we want.

**The real failure is the spouse case.** With no suitable mentor on the roster it
picked a Physician Assistant rather than declining. So its judgment about *when
to decline* is inconsistent: right in one case, wrong in another.

### So most of what looks like a model problem is a data problem

Four of the six weak results trace to the roster having nobody suitable: no
aviation maintenance mentor, no Coast Guard mentor, no spouse mentor. The 56
staged mentors add all three. **Load the mentors before judging the model.**

### Recommendations, in order of leverage

**1. Cap what the prompt sees. Do this first, it is not a model question.**
Sending 75 candidates to pick one is the problem. Filter to the veteran's career
area first, then add a capped sample from other areas so cross-area matches stay
possible, which was the point of NMDH-24. Roughly 15 candidates instead of 75.
Cuts the prompt about 80%, cuts cost on every match, and makes the choice
tractable for any model. Change is in `NM_FindMentor_Flow`, at `Get_All_Mentors`.

**2. Then re-measure before spending on a bigger model.** Re-run
`scripts/data/mentor_match_test.apex` after the mentors load. If the spouse case
and the decline behaviour come good with a filtered corpus, mini is fine here and
an upgrade buys little.

**3. If it is still weak after 1 and 2, upgrade this template only.** It is the
one selection-under-length task in the product. The others do not need it.

---

## QA evaluator: upgrade this one

It assigns a 1–10 score, a sentiment, and issue categories that we then quote as
evidence of quality. Small models are known to be poorly calibrated as judges,
and ours cluster hard at 9 with a long tail to 3, average 7.57, which is the
shape of a lenient grader.

Inputs are small, a median of 232 tokens, and it runs hourly over a handful of
records, so **a stronger model here costs almost nothing**. This is the cheapest
quality win available.

## Classify cluster and Translate skills: leave them

Classification into 9 buckets from a short description is well within mini, and
it was measured correct on helicopters, ship engines and avionics. Skills
translation output has read well throughout testing. Neither is input-heavy and
neither is a judgment task. Changing them adds cost and risk for no observed
gain.

---

## One caution about changing models

`DefaultGPT5Mini` was the QA template's active model and the template was
failing. That turned out **not** to be the model, it was the ConnectApi path
failing for every template including a known-good one. Do not read that history
as evidence a model is broken. Any model change should be verified through the
Flow path and re-measured with `scripts/data/mentor_match_test.apex` and
`scripts/broad_run.py`.

Nothing here is deployed. Model changes alter agent behaviour and the Orchestrate
evaluation is still running.
