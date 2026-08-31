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

A topic can have more than one `GenAiFunction`, and some topics genuinely need it. Mentor Connection requires two sequential actions: find a mentor, then request the introduction.

The design principle is: **the planner must not face two actions that could both plausibly answer the same question.** When two functions could both match the same veteran input (e.g. both "search mentors" and "find mentors" respond to "find me a mentor"), the planner picks unpredictably. Design actions so each one owns a distinct question type — if the planner could reasonably call either one for the same input, redesign the action descriptions or split them into separate topics.

`NM_LogConversation` is intentionally unwired from all agent topics. LLM-based planners skip conditional side-effect actions exactly when a turn fails — the turns the QA grader needs most. Conversation persistence is owned by the LWC chat component (`NM_ChatWidget`) on the client side. The LWC upserts to `NM_Conversation__c` unconditionally on every turn, including failed turns, without relying on a planner action. Do not wire `NM_LogConversation` back into any topic.

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

### CRITICAL: GenAiPlugin metadata deploys destroy topic IDs — read before touching topics

Deploying a `GenAiPlugin` metadata file via `sf project deploy` **deletes the existing topic record and creates a brand-new one with a new Salesforce ID.** Every `GenAiPluginFunctionDef` junction record — the wire that connects a topic to its callable actions — is keyed on the topic's record ID. When the ID changes, all junctions cascade-delete silently. One `sf project deploy` with a `GenAiPlugin` file, after junctions exist, destroys all action wiring with no error or warning.

This is what destroyed the action wiring repeatedly during the NMDH-14 build day. Do not repeat it.

**The rules:**

1. **Never redeploy a `GenAiPlugin` metadata file after its topic IDs are established.** The only safe time to deploy a `GenAiPlugin` file is the very first creation of the topic (when no junctions exist yet to lose). After that: prohibited.

2. **Topic instruction changes go through Tooling API PATCH — not a metadata deploy.** To update `<scope>`, `<description>`, or `<genAiPluginInstructions>` content on an existing topic, patch `GenAiPluginDefinition.Metadata` directly. The record ID survives; junctions survive.

   ```bash
   # PATCH a topic's instructions (ID survives, junctions intact)
   curl -s -X PATCH "https://<instance>.my.salesforce.com/services/data/v62.0/tooling/sobjects/GenAiPluginDefinition/<TopicId>" \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"Metadata": {"scope": "Updated scope text...", "description": "Updated description..."}}'
   ```

3. **After any forced GenAiPlugin redeploy** (e.g. adding a brand-new topic for the first time), query `GenAiPluginDefinition` for the NEW IDs, then recreate all `GenAiPluginFunctionDef` junctions. The old IDs are gone — use the IDs from the query, not hardcoded values.

**These IDs belong to V1 (`NM_NextMission_Bot`) only.** V2's topics carry the suffix `_16jaj0000036lDp` and are managed by the Agent Script compiler — do not create junctions for them by hand. As of 2026-08-31 the org holds 8 topics (4 per bot) and 11 junctions (5 V1, 6 V2). Query `GenAiPluginDefinition` for current values rather than trusting this table.

**Current live topic IDs** — update this table after any redeploy:

| Topic | DeveloperName | Live ID |
|---|---|---|
| Greeting & Background | `NM_Greeting_And_Background` | `179aj000004wziNAAQ` |
| Job Matching | `NM_Job_Matching` | `179aj000004wziLAAQ` |
| Mentor Connection | `NM_Mentor_Connection` | `179aj000004wziMAAQ` |
| Skills Translation | `NM_Skills_Translation` | `179aj000004wziOAAQ` |

These IDs are the `PluginId` values in `GenAiPluginFunctionDef` junction records. Never hardcode stale IDs — always query before creating junctions.

**Established junctions** — all 5 verified in org (2026-08-31):

| Junction ID | Topic (PluginId) | Action (Function) |
|---|---|---|
| `17Eaj000004eG3lEAE` | Greeting (`179aj000004wziNAAQ`) | NM_LookupMilitaryCode (`172aj00000qsnVeAAI`) |
| `17Eaj000004eGBpEAM` | Job Matching (`179aj000004wziLAAQ`) | NM_GetJobMatches (`172aj00000qsnVhAAI`) |
| `17Eaj000004eGDREA2` | Mentor Connection (`179aj000004wziMAAQ`) | NM_FindMentor (`172aj00000qsnViAAI`) |
| `17Eaj000004eGF3EAM` | Mentor Connection (`179aj000004wziMAAQ`) | NM_RequestMentorIntro (`172aj00000qsnVjAAI`) |
| `17Eaj000004eGADEA2` | Skills Translation (`179aj000004wziOAAQ`) | NM_GetClusterData (`172aj00000qsnVgAAI`) |

**CRITICAL: `sf data create record --use-tooling-api` is the only working path for junction creation.** Direct REST calls to the Tooling API 401 because `sf org display --json` returns a redacted token. Use the CLI. Field names: `PluginId` (topic ID) and `Function` (action copy ID).

**How to query current IDs and recreate junctions after a forced redeploy:**

```bash
# Query fresh topic IDs
curl -s "https://<instance>/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName+FROM+GenAiPluginDefinition" \
  -H "Authorization: Bearer <token>" | jq '.records[] | {id:.Id, name:.DeveloperName}'

# Query action copy IDs (IsLocal=true = topic-scoped copies)
curl -s "https://<instance>/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName+FROM+GenAiFunctionDefinition+WHERE+IsLocal__c=true" \
  -H "Authorization: Bearer <token>" | jq '.records[] | {id:.Id, name:.DeveloperName}'

# POST one junction per topic→action pair
curl -s -X POST "https://<instance>/services/data/v62.0/tooling/sobjects/GenAiPluginFunctionDef" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"PluginId": "<new-topic-id>", "Function": "<action-copy-id>"}'
```

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

2. **Both `<activeVersionIdentifier>` (root) and `<versionIdentifier>` (inside `<templateVersions>`) are required — and they must be identical.** A template that has `<versionIdentifier>` inside `<templateVersions>` but is missing `<activeVersionIdentifier>` at root will deploy cleanly (status Succeeded), show as Published, and still fail at runtime with "Failed to generate Einstein LLM generations response" — the org cannot determine which version to invoke. The inner field alone is not sufficient; the outer pointer is what the runtime follows. The element name `activeVersionNumber` does not exist in this schema. **Safest workflow:** build the template in Prompt Builder first (which generates and stores the version hash), then retrieve: `sf project retrieve start --metadata "GenAiPromptTemplate:ApiName" --target-org <alias>`. Copy the retrieved XML into the repo. It will contain both fields with the correct org-generated hash. Do not fabricate the hash.

3. **`<primaryModel>` is required inside `<templateVersions>`.** Without it the template saves but is not callable at runtime. Use `sfdc_ai__DefaultOpenAIGPT4OmniMini` unless a specific model is required.

4. **`<templateFormat>FormulaExpression</templateFormat>` is required for the Prompt Builder Preview button to work.** Without this field the Preview button in Prompt Builder is greyed out / unclickable, even though the template itself is valid and Published. Salesforce Prompt Builder only writes this field when you use **Save As** (not a normal Save) in the UI. The safest workflow: after any deploy, open the template in Prompt Builder, do a **Save As** to generate a new version, then retrieve the XML (`sf project retrieve start --metadata "GenAiPromptTemplate:ApiName" --target-org <alias>`) and commit the result. The retrieve will include `<templateFormat>` on the new version.

5. **`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` and the Prompt Builder Preview use different internal pathways.** The Preview button works with Salesforce's own preview infrastructure. The ConnectApi method requires an LLM model provider to be fully wired in the org. If the ConnectApi call throws "Failed to generate Einstein LLM generations response", use the REST API instead: `POST /services/data/v67.0/einstein/prompt-templates/{templateApiName}/generations` with body `{"isPreview":false,"additionalConfig":{"applicationName":"PromptBuilderPreview","numGenerations":1},"inputParams":{"valueMap":{"Input:Transcript":{"value":"..."}}}}`. This REST path works whenever Preview works. See `scripts/apex/run-qa-evaluator.apex` for the full implementation.

4. **`<status>Published</status>` inside `<templateVersions>`.** The template must be Published to be invokable from a Flow's `aiGenerateText` element. A `Draft` template saves successfully but returns no output when called.

**Input reference syntax in `<content>`:** use `{!$Input:ApiName}` where `ApiName` matches the `<apiName>` inside the corresponding `<inputs>` block. The `<referenceName>` element in each input block should be `Input:ApiName` (no `{!$...}` wrapper — that wrapper is for content references only).

**Getting the correct `versionIdentifier` value:** Salesforce generates this hash when the template is first created. The safest workflow is: create the template in Prompt Builder UI first (which assigns the hash), then `sf project retrieve start --metadata "GenAiPromptTemplate:ApiName"` to pull the canonical XML into the repo. Subsequent deploys of that XML will be treated as an UPDATE and succeed. Do not fabricate the hash — use the value retrieved from the org.

---

### Agent Script (V2) — this is the agent going forward

**As of 2026-08-31 the project has two agents in the org.** `NM_NextMission_V2` is the one being developed. `NM_NextMission_Bot` (V1) stays published and active as a fallback and for side-by-side comparison — do not delete or modify it.

| | V1 | V2 |
|---|---|---|
| Planner | `NM_NextMission_Bot_v1` | `NM_NextMission_V2_v1` |
| Built from | hand-authored gen-1 metadata | Agent Script `.agent` file |
| Topic suffix | `_16jaj0000035gRV` | `_16jaj0000036lDp` |
| Junction wiring | manual Tooling API POSTs | created by the compiler on publish |

**Source of truth:** `force-app/main/default/aiAuthoringBundles/NM_NextMission_V2/NM_NextMission_V2.agent`

Edit that file. The GenAiPlugin/GenAiPlanner XML it produces is compiler output — never hand-edit it. The `CRITICAL: GenAiPlugin metadata deploys destroy topic IDs` section above still applies to **V1 only**. For V2 the compiler creates and maintains the junctions itself, which is the main reason the project moved to Agent Script.

#### Publishing — only works from a local machine

`.agent` files are not deployable metadata. Deploying the bundle puts the source in the org but does not create or update the agent. The only thing that compiles it is:

```bash
sf agent publish authoring-bundle --api-name NM_NextMission_V2 --target-org dreamforce-hackathon
```

**Orchestrate cannot run this.** Publish performs a server-side SFAP token exchange that requires the `chatbot_api`, `sfap_api`, and `web` OAuth scopes. The Orchestrate execution environment authenticates via JWT through its own connector app, whose token does not carry them, and it fails with:

```
ApiAccessError: Error obtaining API token: invalid or missing access token.
```

Orchestrate can author the `.agent` file, deploy the bundle, and build every supporting component. A human runs the publish. Two ways to do that:

1. **CLI on a local machine** authenticated through `NM_NextMission_ECA`:
   ```bash
   sf org login web \
     --client-id <NM_NextMission_ECA consumer key> \
     --scopes "api chatbot_api sfap_api web" \
     --instance-url https://orgfarm-3bfff135af.my.salesforce.com \
     --alias dreamforce-hackathon
   ```
   All four scopes are required. Omitting `web` fails at the token exchange; requesting `refresh_token` fails with `invalid_scope` because the ECA does not grant it. The ECA's callback list must include `http://localhost:1717/OauthRedirect` (it does; that lives in `ExtlClntAppGlobalOauthSettings`, not `ExtlClntAppOauthSettings`). The CLI prompts for the consumer secret.

2. **Commit Version button** in Setup → Agentforce Builder. The bundle appears there once deployed as metadata, and this button is the point-and-click equivalent of publish. Requires no CLI or scopes.

#### Agent Script syntax rules learned the hard way

Every one of these cost a failed publish cycle. The compiler reports **one error at a time** and stops.

1. **`system.instructions` must be a plain quoted string.** The `-> |` template form works in `reasoning.instructions` but fails at the system level with *"Expected a string or a template, got identifier."*

2. **Actions need two blocks, not one.** Each subagent declares its actions in an `actions:` block that is a **sibling of `reasoning:`**, then exposes them as tools inside `reasoning.actions`. Declaration:
   ```
   subagent NM_Mentor_Connection:
       actions:
           find_mentor:
               description: "..."
               inputs:
                   clusterKey: string
               outputs:
                   found: boolean
                   mentorName: string
               target: "apex://NM_FindMentorAction"

       reasoning:
           actions:
               find_mentor: @actions.find_mentor
                   with clusterKey=@variables.clusterKey
   ```
   Targets are `apex://ClassName` or `flow://FlowApiName` — the Apex class or Flow, **not** the GenAiFunction name. Bare identifiers (`find_mentor: NM_FindMentor`) fail with *"Bare identifiers are not allowed here."* An `@actions.X` reference with no matching declaration fails with *"X is not defined in actions."*

3. **Session variables need explicit `with` and `set` bindings.** Instructions telling the model to "store the returned clusterKey" do nothing — prose cannot write to a session variable. Use `set @variables.clusterKey=@outputs.clusterKey` to write and `with clusterKey=@variables.clusterKey` to read. Without these, variables stay empty and downstream actions silently receive null. The VS Code extension flags this as *"Variable X is declared but never used"* and *"Input X has no `with` clause and will be filled by the LLM at runtime"* — treat both as errors, not information.

4. **Apex `Id` parameters are not strings.** Declare them as:
   ```
   mentorId: object
       complex_data_type_name: "lightning__recordIdType"
   ```
   A `string` declaration fails validation with an explicit message naming the fix.

5. **`default_agent_user` belongs in an `access:` block**, not `config:`. It is deprecated in `config:`.

6. **The Builder Problems panel undercounts.** It reported 1 error while the subagent views showed several more. Click into every subagent individually before believing the count.

#### Current action targets

| Action | Target |
|---|---|
| `look_up_military_code` | `apex://NM_LookupMilitaryCodeAction` |
| `classify_cluster` | `flow://NM_ClassifyCluster_Flow` |
| `get_cluster_data` | `flow://NM_GetCluster_Flow` |
| `get_job_matches` | `apex://NM_GetJobMatchesAction` |
| `find_mentor` | `apex://NM_FindMentorAction` |
| `request_mentor_intro` | `apex://NM_RequestMentorIntroAction` |

`NM_LogConversation` is intentionally not wired. Conversation persistence is owned by the `nmChatWidget` LWC on the client side.

#### Resolved defect — NM_GetCluster_Flow (NMDH-6, fixed 2026-08-31)

`NM_GetCluster_Flow` used to return `found=false` whenever `userPrompt` was null, empty, or omitted, even when `clusterKey` was a valid match. That broke the primary path, because a military code lookup never produces a free-text description, so `userPrompt` is always empty there. A veteran entering `Army, 68W` was told "I don't have data on that specialty yet" for a cluster holding 1348 characters of content.

Fixed in commit `ac9bc53`. Verified against the org: `userPrompt` null, empty, and omitted all now return `found=true` for a valid `clusterKey`. The deterministic binding has been restored in `NM_NextMission_V2.agent`.

**Lesson for future flow work:** a Flow debug run with all inputs populated will pass and tell you nothing. Test optional inputs explicitly as null, empty, and omitted.

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

0. **If the story touches the agent's behaviour, the change belongs in `NM_NextMission_V2.agent`** — not in GenAiPlugin XML, and not in the Builder UI. Publish it, then verify in Builder Preview by clicking into every subagent, not just reading the Problems count.
1. Scan all `<instruction>` elements and Prompt Template `<content>` blocks for off-limits words.
2. Confirm voice is first-person singular throughout — no "we", "our", "us".
3. Confirm permission set updates ship in the same commit as any new Apex class or Flow.
4. For UI stories: run through the accessibility checklist above.
5. Validate before deploying: `sf project deploy validate --source-dir force-app --target-org dreamforce-hackathon --test-level RunLocalTests --json`
6. **Deployed does not mean active.** A successful deploy does not mean the thing is switched on. Confirm the activation state separately before closing the story:
   - **Flows** deploy as Draft — activate each Flow explicitly in Setup → Flows → Activate.
   - **Prompt Templates** deploy in whatever status the XML declares, but must be Published to be callable at runtime — query the org or open Prompt Builder to verify the Published status, not just that the deploy command succeeded.
   - **The Agentforce agent** must be activated in Setup → Agents after its metadata is deployed. A deployed-but-inactive agent answers nothing.
   - **Agent Script bundles** must be published, not just deployed. Deploying the `AiAuthoringBundle` puts the source in the org and changes nothing about the running agent. Confirm a new `GenAiPlannerDefinition` version exists after publishing.
   - **Scheduled Apex** must be explicitly scheduled via `System.schedule()` after the class is deployed — query `CronTrigger` to confirm the job is WAITING, not just that the class compiled.
   Mark a story done only after you have confirmed the active/published/scheduled state in the org directly.
