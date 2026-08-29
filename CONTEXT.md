# Next Mission — Agent Build Context

Read this file before starting any build story. It is the single source of truth for decisions that apply across the entire agent. Do not re-derive, re-propose, or override anything recorded here.

---

## Project Purpose

Next Mission is a Salesforce Agentforce agent deployed on a public LWR site. It helps transitioning and recently-separated veterans understand how their military skills translate to civilian careers, surface relevant job categories, and connect with mentors. Veterans typically have no civilian job market vocabulary — the agent's job is to bridge that gap in plain language.

The agent is anonymous by default. Veterans do not sign in. The only time an email is collected is when a veteran requests a mentor introduction.

---

## Voice and Tone

The agent speaks in **first-person singular**: "I", "my", "me". Never "we", "our", "us", or any phrase that implies a team or organization is speaking.

Tone: warm, plain, respectful. Like a peer who has been through the same transition — not a recruiter, not a chatbot, not a career coach. Short sentences. No jargon. No marketing language.

The agent does not coach, evaluate, or motivate. It informs and connects.

### Off-Limits Words

These words and phrases must never appear in any topic instruction, Prompt Template content, or agent response:

- Hero / heroes
- "Thank you for your service"
- Sacrifice / sacrificed
- Warrior / warriors
- Battle (used metaphorically, e.g. "battle-tested")
- Leverage (as a verb)
- Synergy
- "Best in class"
- Unlock (as in "unlock your potential")

Check every `<instruction>` element and every Prompt Template `<content>` block against this list before marking a story done.

---

## Universal Guardrails

These apply to every topic and every action. Build each one into the relevant topic instruction set.

- **Never score, rank, or reject.** Do not tell a veteran they are qualified, unqualified, a good fit, or a poor fit for anything.
- **Never fabricate.** Do not invent job titles, salary ranges, mentor names, company names, or military codes. Return only what is in the data.
- **Never echo sensitive service details.** If a veteran mentions discharge type, disability rating, VA status, mental health history, or legal history — acknowledge briefly if needed, then move on. Do not repeat it back, store it explicitly, or reference it again in the conversation.
- **No repeated questions.** If a veteran has already provided a piece of information in this session, do not ask for it again.
- **Anonymous by default.** Collect email only when the veteran explicitly requests a mentor introduction, and only for that purpose.
- **Mobile-first responses.** Keep replies short. One idea per sentence. No tables or multi-column layouts in agent responses.

---

## Architecture Decisions

These decisions are locked. A cold build session is most likely to redo these wrong — read carefully before designing any action or topic.

### Custom Metadata is the grounding layer

All domain data — military specialty codes, civilian skill clusters, job category descriptions — lives in Custom Metadata Types:

- `NM_Military_Code__mdt` — maps MOS/AFSC/rate codes to specialty cluster keys
- `NM_Specialty_Cluster__mdt` — maps cluster keys to civilian skill descriptions and job categories

There is no Data Cloud. There is no SOQL against user-generated records at translation time. Apex actions query Custom Metadata. This is intentional: the data is small, static, and must be deterministic. Do not introduce a retriever, a vector index, or a Data Cloud data stream for this use case.

### The Prompt Template is the only place generation happens

The only `GenAiPromptTemplate` in this project is `NM_Translate_Skills_Template`. It lives **inside** the autolaunched Flow `NM_GetCluster_Flow`. The Flow calls the template; the template generates the civilian-language restatement of the veteran's skills.

No other action, topic instruction, or Apex class generates LLM output. Structured data output — job matches, mentor suggestions, conversation logs — comes from Apex, not generation.

**Do not add a second Prompt Template.** Do not add a `GenAiFunction` with `invocationTargetType = generatePromptResponse` for any other purpose. If a new generation requirement arises, revise this file first and get approval before building.

### The planner sees one action per topic

Each `GenAiPlugin` references exactly one `GenAiFunction`. The planner calls that function and synthesizes a response from the return value. Do not add a second action to an existing topic without revising this file.

This is intentional: a single action per topic keeps planner behavior predictable and eliminates the risk of the planner calling actions in the wrong order or calling both when only one is needed.

### Permission set: NM_Agent_Data_Access

There is one permission set for this project: **`NM_Agent_Data_Access`**. Do not create a second one and do not use a shortened name like `NM_Agent_Access`.

Object and field access for all custom objects belong in the story that creates the custom objects (S01 / NMDH-2). Each subsequent story that introduces an Apex class or autolaunched Flow must add that class or Flow to `NM_Agent_Data_Access` in the same commit. A class or Flow deploy and its permission set update always ship together — never split them across separate stories or separate commits.

---

## Accessibility Standards

These apply to every LWC in this project. Run through this list before marking any UI story done.

- All interactive elements (`lightning-button`, `lightning-input`, custom `<button>`, etc.) must have an `aria-label` that describes their purpose to a screen reader. A button labeled "Send" is not sufficient — use `aria-label="Send message"` where context is needed.
- Use semantic HTML. Buttons must be `<button>` or `<lightning-button>`, not `<div>` or `<span>` with click handlers.
- Touch targets must be at least 44×44 CSS pixels. Do not reduce target size for aesthetic reasons.
- Do not convey information by color alone. Any state indicated by color (error, success, active, disabled) must also be indicated by text, an icon with an `aria-label`, or a pattern.
- Do not autoplay audio. If TTS is added in a later story, it must be triggered by a deliberate user action.
- All functionality must be reachable by keyboard. Tab order must follow visual order. There must be no keyboard traps — the user must always be able to tab out of the chat widget.
- Dynamic content updates (new agent messages appearing in the chat window) must be announced to screen readers. Wrap the message list in an element with `aria-live="polite"`.
- Error messages must be programmatically associated with their input via `aria-describedby` or the equivalent `lightning-input` `message-when-*` attribute.
- All user-visible text strings must be custom labels. Do not hardcode English strings in markup or JavaScript.
- Minimum color contrast ratio: 4.5:1 for normal text, 3:1 for large text (WCAG AA).

---

## Target Org and Branch

- **Salesforce org alias:** `dreamforce-hackathon`
- **GitHub repository:** `apurpuraJax/NextMission-Dreamforce-Hackathon`
- **Working branch:** `main`

All `sf` CLI commands must include `--target-org dreamforce-hackathon`. Do not omit the flag; the CLI default may resolve to a different org.

---

## Before Marking Any Story Done

1. Scan all `<instruction>` elements and Prompt Template `<content>` blocks for off-limits words.
2. Confirm voice is first-person singular throughout — no "we", "our", "us".
3. Confirm permission set updates ship in the same commit as any new Apex class or Flow.
4. For UI stories: run through the accessibility checklist above.
5. Validate before deploying: `sf project deploy validate --source-dir force-app --target-org dreamforce-hackathon --test-level RunLocalTests --json`
