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

The only `GenAiPromptTemplate` used by the Agentforce agent itself is `NM_Translate_Skills_Template`. It lives **inside** the autolaunched Flow `NM_GetCluster_Flow`. The Flow calls the template; the template generates the civilian-language restatement of the veteran's skills.

No other action, topic instruction, or Apex class generates LLM output for the agent's conversational surface. Structured data output — job matches, mentor suggestions, conversation logs — comes from Apex, not generation.

**Do not add a second Prompt Template to the agent flow.** Do not add a `GenAiFunction` with `invocationTargetType = generatePromptResponse` for any other purpose. If a new generation requirement arises, revise this file first and get approval before building.

(`NM_QA_Evaluator_Template` is a separate, back-office evaluation template used by the `NM_QAEvaluator` Queueable for quality assurance. It is not part of the agent's conversational flow.)

### Planner action design — avoid ambiguous choices

A topic can have more than one `GenAiFunction`, and some topics genuinely need it. Mentor Connection requires two sequential actions: find a mentor, then request the introduction. Logging (`NM_LogConversation`) is a side-effect action shared across topics.

The design principle is: **the planner must not face two actions that could both plausibly answer the same question.** When two functions could both match the same veteran input (e.g. both "search mentors" and "find mentors" respond to "find me a mentor"), the planner picks unpredictably. Design actions so each one owns a distinct question type — if the planner could reasonably call either one for the same input, redesign the action descriptions or split them into separate topics.

`NM_LogConversation` is not a primary action — it is a side-effect action that records what the veteran entered. It does not answer any question and cannot compete with the primary action for planner selection. Every topic that collects veteran input should reference both its primary action and `NM_LogConversation`. This pattern applies to all four topics (Greeting & Background, Skills Translation, Job Matching, Mentor Connection).

### GenAiFunction format — use masterLabel, not functionName

**Canonical reference: `NM_LookupMilitaryCode`** — this is the deployed working example. Match its structure exactly.

Every `GenAiFunction` metadata file must follow this shape:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<GenAiFunction xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>...</description>
    <invocationTarget>ApexClassName</invocationTarget>
    <invocationTargetType>apex</invocationTargetType>
    <masterLabel>FunctionApiName</masterLabel>
</GenAiFunction>
```

**Two hard rules — both required for a successful deploy:**

1. **`masterLabel`, not `functionName`.** Use `<masterLabel>` for the function's API name. The `<functionName>` element is not valid in this metadata schema. A file with `<functionName>` will fail with: *"Specify a valid invocationTarget and invocationTargetType."* This error looks like an invocationTarget problem but is actually caused by the wrong element name.

2. **Each function in its own subfolder.** File path must be:
   `force-app/main/default/genAiFunctions/FunctionApiName/FunctionApiName.genAiFunction-meta.xml`
   A flat file at `force-app/main/default/genAiFunctions/FunctionApiName.genAiFunction-meta.xml` will not deploy correctly.

Both `NM_LogConversation` and `NM_GetJobMatches` were initially built with `<functionName>` and had to be corrected (NMDH-9). Do not repeat this.

### GenAiPlugin schema — v67 rules

**Canonical reference: `NM_Greeting_And_Background`** — this is the deployed working example for topic plugins. Match its structure when building new topics.

Two schema rules that are not obvious from Salesforce documentation and will produce confusing failures if missed:

1. **Every `<genAiPluginInstructions>` block requires its own `<developerName>` child.** Each element in the plugin's instruction list must include a `<developerName>` that is unique within the plugin. A flat instruction block without `<developerName>` will fail validation. The pattern mirrors what `NM_Job_Matching` uses — inspect that file if unsure.

2. **`<scopeContraIndication>` does not exist in API v67.** Do not add it as a sibling of `<scope>`. If a topic instruction needs to exclude certain inputs or conditions, express the exclusion inside the `<scope>` element's text — for example: *"Do not handle requests about salary negotiation."* The element `<scopeContraIndication>` will cause a deploy error on the current API version.

### GenAiPromptTemplate schema — v67 rules

**Canonical reference: `NM_Translate_Skills_Template`** — this is the deployed working example. Match its structure exactly when building new prompt templates (NMDH-19 and beyond).

Four elements differ from what Salesforce documentation implies. Getting any of them wrong produces a schema rejection on deploy with no useful error message:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<GenAiPromptTemplate xmlns="http://soap.sforce.com/2006/04/metadata">
    <activeVersionIdentifier>MATCHING_VERSION_IDENTIFIER</activeVersionIdentifier>
    <description>...</description>
    <developerName>ApiName</developerName>
    <masterLabel>Human Label</masterLabel>
    <overridable>false</overridable>
    <templateVersions>
        <content>Prompt text. Reference inputs as {!$Input:VariableName}</content>
        <inputs>
            <apiName>VariableName</apiName>
            <definition>primitive://String</definition>
            <masterLabel>Variable Label</masterLabel>
            <referenceName>Input:VariableName</referenceName>
            <required>true</required>
        </inputs>
        <isCitationEnabled>false</isCitationEnabled>
        <primaryModel>sfdc_ai__DefaultOpenAIGPT4OmniMini</primaryModel>
        <status>Published</status>
        <versionIdentifier>MATCHING_VERSION_IDENTIFIER</versionIdentifier>
    </templateVersions>
    <type>einstein_gpt__flex</type>
    <visibility>Global</visibility>
</GenAiPromptTemplate>
```

**Four hard rules:**

1. **`<inputs>` blocks live inside `<templateVersions>`**, not at the top level. Top-level `<inputs>` elements cause a schema error.

2. **`<versionIdentifier>` not `activeVersionNumber`.** The version field inside `<templateVersions>` is `<versionIdentifier>`. The top-level field is `<activeVersionIdentifier>` and must match the `<versionIdentifier>` value. The element `activeVersionNumber` does not exist in this metadata schema.

3. **`<primaryModel>` is required inside `<templateVersions>`.** Without it the template saves but is not callable at runtime. Use `sfdc_ai__DefaultOpenAIGPT4OmniMini` unless a specific model is required.

4. **`<status>Published</status>` inside `<templateVersions>`.** The template must be Published to be invokable from a Flow's `aiGenerateText` element. A `Draft` template saves successfully but returns no output when called.

**Input reference syntax in `<content>`:** use `{!$Input:ApiName}` where `ApiName` matches the `<apiName>` inside the corresponding `<inputs>` block. The `<referenceName>` element in each input block should be `Input:ApiName` (no `{!$...}` wrapper — that wrapper is for content references only).

**Getting the correct `versionIdentifier` value:** Salesforce generates this hash when the template is first created. The safest workflow is: create the template in Prompt Builder UI first (which assigns the hash), then `sf project retrieve start --metadata "GenAiPromptTemplate:ApiName"` to pull the canonical XML into the repo. Subsequent deploys of that XML will be treated as an UPDATE and succeed. Do not fabricate the hash — use the value retrieved from the org.

---

### Permission set: NM_Agent_Data_Access

**`NM_Agent_Data_Access`** is the agent's access boundary — it defines what the Agentforce agent is permitted to read and write. Do not use a shortened name like `NM_Agent_Access`.

This is not the only permission set in the org. `NM_Agent_Data_Access` scopes the agent, not every user. Admins who need to write fields the agent is intentionally excluded from (for example `Contact_Email__c` on `NM_Mentor__c`) must use their admin profile or a separate admin-facing permission set. Do not add those fields to `NM_Agent_Data_Access` — the exclusion is deliberate.

**`NM_Agent_Data_Access` must be assigned to the agent user** once the Agentforce agent exists. Without the assignment the agent silently skips any action that touches these objects — there is no error, the action simply does nothing.

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
6. **Deployed does not mean active.** A successful deploy does not mean the thing is switched on. Confirm the activation state separately before closing the story:
   - **Flows** deploy as Draft — activate each Flow explicitly in Setup → Flows → Activate.
   - **Prompt Templates** deploy in whatever status the XML declares, but must be Published to be callable at runtime — query the org or open Prompt Builder to verify the Published status, not just that the deploy command succeeded.
   - **The Agentforce agent** must be activated in Setup → Agents after its metadata is deployed. A deployed-but-inactive agent answers nothing.
   - **Scheduled Apex** must be explicitly scheduled via `System.schedule()` after the class is deployed — query `CronTrigger` to confirm the job is WAITING, not just that the class compiled.
   Mark a story done only after you have confirmed the active/published/scheduled state in the org directly.
