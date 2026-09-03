# Next Mission — Agent Build Context

Read this file before starting any build story. It is the single source of truth for decisions that apply across the entire agent. Do not re-derive, re-propose, or override anything recorded here.

---

## Project Purpose

Next Mission is a Salesforce Agentforce agent deployed on a public LWR site. It helps transitioning and recently-separated veterans understand how their military skills translate to civilian careers, surface relevant job categories, and connect with mentors. Veterans typically have no civilian job market vocabulary — the agent's job is to bridge that gap in plain language.

The agent is anonymous by default. Veterans do not sign in. The only time an email is collected is when a veteran requests a mentor introduction.

---

## Voice and Tone

The agent speaks in **first-person singular** — "I", "my", "me" — never "we", "our", "us", or any phrase implying a team or organization is speaking.

**This rule is scoped, and the scoping is not optional.** "I" refers to the agent and only to the agent's own actions: *"I can show you some roles."* Everything about the veteran's background, service, skills or career is **second person**: *"you", "your"*.

Written without that scoping, this rule caused a live defect on 2026-08-31. The agent produced *"My military background in healthcare equips me well... I have provided medical care in challenging environments"* — presenting a veteran's service as its own. The source data in `Civilian_Skill_Summary__c` is written in the second person; the model converted it to first person to satisfy the voice rule and in doing so claimed to have served. For this audience that is the most damaging thing the agent can do.

Never write "my military background", "I served", "when I was in", or any construction that presents the veteran's experience as the agent's. If source data is written in the second person, keep it in the second person.

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
- **Never fabricate.** Do not invent job titles, mentor names, company names, or military codes. Return only what is in the data.
- **Never narrate an outcome that did not happen.** Do not say something has been sent, started, queued, submitted or scheduled unless the action that does it actually ran and returned success. If an action returns `success=false`, say plainly that it did not go through and surface the returned message. If an action's inputs are missing, ask for them — do not skip the action and describe the result as if it happened. On 2026-08-31 the agent told a test user "you're all set, Alex will reach out to you at [email]" while creating no record at all.
- **Never output an internal identifier as a reply.** Action names, variable names and platform tokens must never appear in agent output. The agent once replied with the bare string `end_session_action`.
- **Salary: never invent, never stonewall.** Do not state, estimate or imply a figure without sourced data. But do not refuse the subject either — someone deciding whether a path is viable needs it. Absent wage data, say plainly there is none and point to the Bureau of Labor Statistics. Once NMDH-23 lands, cite the real range with its source and vintage.
- **Never echo sensitive service details.** If a veteran mentions discharge type, disability rating, VA status, mental health history or legal history: do not restate it, do not summarise it back, and do not confirm receipt of it. Phrases like "your medical discharge and 70% rating are noted" are a defect — that is a form being processed, not a person being heard. A brief human beat then carry on. Never tell them how people with their circumstances tend to fare.
- **Frustration is never a reason to end the conversation.** If a veteran says this is a waste of time or wants to give up, take it on the chin briefly, then offer one concrete thing. Leaving is their choice, never the agent's. Never call any action that ends or closes the session.
- **No repeated questions.** If a veteran has already provided a piece of information in this session, do not ask for it again.
- **Anonymous by default.** Collect email only when the veteran explicitly requests a mentor introduction, and only for that purpose.
- **Mobile-first responses.** Keep replies short. One idea per sentence. No tables or multi-column layouts in agent responses.

---

## Architecture Decisions

These decisions are locked. A cold build session is most likely to redo these wrong — read carefully before designing any action or topic.

### Grounding layer: O*NET occupations (CUTOVER COMPLETE 2026-09-01)

**The nine-cluster model is no longer the primary path for codes, skills or jobs.** Grounding is now the O\*NET occupation data and the DoD Military Crosswalk, in two custom objects:

* `NM_Military_Code_V2__c` — 8,179 active military codes with their O\*NET mappings. Air Force 3,954, Navy 2,851, Marine Corps 797, Army 435, Coast Guard 142. The count difference is DoD taxonomy, not missing data: Air Force AFSCs encode skill level in the code itself (2A512E / 2A532E / 2A552E are one job at three levels) while the Army keeps it separate. Army coverage was spot checked at 20 of 20 common MOSs.
* `NM_Occupation__c` — 1,016 O\*NET occupations with real descriptions.

`NM_LookupOccupationAction` resolves branch and code to occupations. Two SOQL queries regardless of volume.

**What this fixed:** a 68W and a 68G returned word-for-word identical text, because the cluster was the only thing carried downstream. They now return Paramedics and Medical Records Specialists respectively, with real O\*NET descriptions.

Reload with `scripts/data/build_onet_load_files.py` against the published O\*NET release, then bulk upsert on the external ids. Do not hand edit these objects.

**Code normalisation lives in Apex, not in instructions.** `NM_LookupOccupationAction` tries the code exactly as typed, and for an Army MOS matching `NNXNN` also tries the base MOS, so `68W10` resolves to `68W`. This is deliberately Army-only and deliberately not general prefix truncation: Air Force AFSCs encode skill level inside the code (`2A512E`, `2A532E`, `2A552E` are three distinct rows), so shortening one lands on a different job. An earlier version told the agent to "strip any skill level suffix" and the model applied that Army rule to an AFSC, turning `2A552E` into `2A55` and missing. The agent is now told to normalise the branch only and pass the code through untouched.

**Staleness is monitored, not automated.** `NM_ONETReleaseMonitor` runs weekly (Sunday 03:00, scheduling user's timezone) and compares the release published on onetcenter.org against `NM_Data_Config__c.Loaded_ONET_Release__c`, setting `Refresh_Needed__c`. It does **not** reload: the database is a 12 MB zip and the crosswalk 4 MB, against a 6 MB Apex callout limit and no unzip in Apex. The reload is the script plus a bulk upsert. As of 2026-09-01 the org holds `db_29_1` while `db_31_0` is published, so the flag is set and correct.

**Mapping integrity, verified 2026-09-01:** the crosswalk references 425 distinct O\*NET codes, all present in the loaded occupations, and all 8,179 military codes resolve to at least one real occupation. Re-run that check after any reload; a version mismatch between crosswalk and occupations would orphan mappings silently.

**Still cluster-based, deliberately:** mentor matching uses `clusterKey` as a tie-breaker, and the description path (`NM_ClassifyCluster_Flow`) still classifies into the nine clusters when no code is available. `NM_Specialty_Cluster__mdt` and `NM_Military_Code__mdt` remain in the org as the fallback path and are still read by `get_cluster_data` and `get_job_matches`, which are now gated with `available when @variables.occupations is None`.

### Custom Metadata is the grounding layer (SUPERSEDED for codes, skills and jobs — see above)

All domain data — military specialty codes, civilian skill clusters, job category descriptions — lives in Custom Metadata Types:

- `NM_Military_Code__mdt` — maps MOS/AFSC/rate codes to specialty cluster keys
- `NM_Specialty_Cluster__mdt` — maps cluster keys to civilian skill descriptions and job categories

There is no Data Cloud. There is no SOQL against user-generated records at translation time. Apex actions query Custom Metadata. This is intentional: the data is small, static, and must be deterministic. Do not introduce a retriever, a vector index, or a Data Cloud data stream for this use case.

> **OVERRIDE (2026-09-01, approved) — NMDH-21.** The paragraph above is superseded **for job matching only**. Job matching may now be built on Data Cloud + a search/vector index + a retriever, wired into the Gen 2 AgentScript agent. This is an approved architecture-decision change; it does **not** open Data Cloud for translating military codes or resolving specialty clusters — that grounding stays Custom Metadata + Apex and remains locked. NMDH-7 (`NM_GetJobMatchesAction`, Apex) stays delivered as the baseline/fallback. Full design in the D01 job-matching Data Cloud retriever design deliverable; build tracked under NMDH-21.

### The Prompt Template is the only place generation happens

The only `GenAiPromptTemplate` used by the Agentforce agent itself is `NM_Translate_Skills_Template`. It lives **inside** the autolaunched Flow `NM_GetCluster_Flow`. The Flow calls the template; the template generates the civilian-language restatement of the veteran's skills.

No other action, topic instruction, or Apex class generates LLM output for the agent's conversational surface. Structured data output — job matches, mentor suggestions, conversation logs — comes from Apex, not generation.

**Do not add a second Prompt Template to the agent flow.** Do not add a `GenAiFunction` with `invocationTargetType = generatePromptResponse` for any other purpose. If a new generation requirement arises, revise this file first and get approval before building.

> **OVERRIDE (2026-09-01, approved) — NMDH-21.** One additional `GenAiPromptTemplate` — `NM_Job_Matches_Template` — is now approved specifically for the job-matching retriever path. It grounds its output on retriever results (Data Cloud job catalog), not free generation, and is bound to the `NM_Job_Matching` subagent in AgentScript. It must follow every v67 GenAiPromptTemplate rule in this file (both `activeVersionIdentifier` + `versionIdentifier` present and identical; `primaryModel` required; `status` Published; the hash is **retrieved from the org, never fabricated**) and every universal guardrail (never score/rank/reject the veteran; never fabricate job titles, salaries, or mentor names). No other new template or `generatePromptResponse` function is authorized by this override.

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

#### Military code coverage: the table is a fast path, not the source of truth

`NM_Military_Code__mdt` holds 234 codes: Air Force 58, Navy 55, Army 53, Marine Corps 44, Coast Guard 24. The real world is far larger — roughly 190 Army MOSs, 350 Marine Corps MOSs, 200 Air Force AFSCs, and several thousand Navy NECs. **Most veterans who type a perfectly valid code will not be in this table.** Do not treat a lookup miss as user error, and do not try to close the gap by growing the table to thousands of rows.

Measured behaviour, tested against the live org:

* **Free-text descriptions classify well.** 10 of 12 realistic descriptions resolved correctly, including slang the data does not contain — "I was a grunt" to CombatArms, "I was a POG in supply" to Logistics. The model's own military vocabulary carries this, not our corpus.
* **Bare codes classify badly.** Only 4 of 10 resolved, and it failed even on codes that ARE in the table, because `NM_ClassifyCluster_Flow` only ever sees nine cluster keys and labels. `0621` is an opaque token with no semantic content.
* **Expanding the code first fixes it completely.** All 5 codes that failed as bare tokens resolved correctly once turned into role language first: 2T2X1 to Logistics, 6115 to Aviation, AWS to Aviation, 3F5X1 to FinanceAdmin, 0621 to Communications_IT.

**So the flow is: exact match first, expansion second, ask third.** On a lookup miss the agent expands the code itself into a plain-language role description, then calls `classify_cluster` with that expansion. Only when it genuinely does not know the code does it ask the veteran what they did, and it says so without implying they made a mistake. `notFoundMessage` is deliberately not surfaced.

This also absorbs input variants that the exact match cannot handle. `Marines, 0311` and `Army, 68W10` both failed the Apex lookup (branch synonym and skill-level suffix) and both now resolve correctly, because the model normalises before the exact match and expands after a miss. Do not build a branch-synonym list or progressive prefix truncation in Apex — prefix truncation in particular can return a *different* valid code's cluster and produce a confident wrong answer.

#### Two actions that could answer the same question: the planner picks the wrong one

CONTEXT.md has always said "the planner must not face two actions that could both plausibly answer the same question." On 2026-09-01 that cost several hours, so here is what it looks like in practice.

`look_up_occupations` and `classify_cluster` both lived in the greeting subagent. Both plausibly answer "what is this person's background". The planner chose `classify_cluster` every time, because it is easier to satisfy, and silently ignored the crosswalk. The symptom was not an error: it was the agent confidently classifying `Navy V25C` (Surface Vessel Torpedo Tube Operation and Maintenance) as **Aviation**, from its own guesswork.

Instruction changes did not fix it. Three rewrites, each more emphatic, all ignored. What fixed it was **splitting them into separate subagents** so neither competes:

* `NM_Greeting_And_Background` — code lookup only, one data action
* `NM_Describe_Background` — free-text classification only, one data action

The router chooses which one to enter. Each subagent then has exactly one way to do its job.

**Corollary:** `available when` is the deterministic way to remove a competing tool when you cannot split. `get_cluster_data` and `get_job_matches` are gated on `@variables.occupations is None`, so they simply do not exist once we have occupations.

#### Every new Apex class must be added to NM_Agent_Data_Access, and the failure is silent

This rule was already in this file. It was broken anyway on 2026-09-01, and the cost was an hour of misdiagnosis.

`NM_LookupOccupationAction` deployed fine, was wired into the agent script correctly, appeared in the compiled graph, and returned `found=false` for every code — including codes that were provably in the data and that the class resolved correctly when called directly in anonymous Apex.

The agent user could not execute the class. There is no error, no exception, and no log line. The action just returns nothing.

**When an action returns not-found for data you can see in the org, check `SetupEntityAccess` before anything else.**

#### Bulk loading: two failure modes that report as something else

* Newly deployed fields are invisible until FLS is granted. The Bulk API reports this as `InvalidBatch : Field name not found : <field>`, which reads like a typo in the CSV. It is a permissions problem. Grant field permissions, then load.
* Embedded newlines in field values break the job with a `LineEnding` error naming LF or CRLF, which points at the file's line endings rather than at the data. Flatten newlines inside values.

Both are handled in `scripts/data/build_onet_load_files.py`.

#### Architecture: the start agent MUST be a thin router

**Every conversation turn re-enters `start_agent`.** Salesforce documents this plainly: *"All requests, including the first request, begin at the agent router, the start_agent block. With every customer utterance, the agent begins execution at this block."* Transitions are one way and do not persist — after each turn control returns to `start_agent`, and re-entering a subagent starts it from the beginning.

**State lives in variables, and variables are written only by action output bindings** (`set @variables.x=@outputs.y`). The model cannot write to a variable no matter how the instructions are phrased. Any routing decision that has to survive a turn must be driven off a variable that some action populated.

This was originally built with `NM_Greeting_And_Background` as the start agent, which meant every turn re-entered the greeting subagent and tried to greet, ask for a specialty code, and answer from a subagent that had no relevant actions in scope. Symptoms this produced, all of which took a long time to diagnose:

* The agent re-greeted mid-conversation and asked for a code it had already been given.
* Mentor introductions never fired. At the moment the veteran consented, control was back in Greeting, where `request_mentor_intro` is not in scope. Unable to call it, the model narrated a confirmation instead and no record was ever created.
* The agent invented mentors, because Greeting has no mentor data. Builder Preview flagged those turns `UNGROUNDED`.
* Follow-up questions drifted off the grounding data into general model knowledge.

**The correct structure**, which is what the platform's own generated boilerplate produces:

```
start_agent NM_Router:
    reasoning:
        instructions: ->
            if @variables.mentorId is not None and @variables.introSent is None:
                | An introduction is in progress. Call go_to_mentor immediately, say nothing else.
            if @variables.clusterKey is None:
                | Background not established. Call go_to_greeting immediately, say nothing else.
            | Choose the right subagent for what they just said. Do not answer them yourself.
        actions:
            go_to_greeting: @utils.transition to @subagent.NM_Greeting_And_Background
            ...
```

The router does no work. Deterministic guards on variables come first, intent classification second, and every real subagent sits below it. Do not put business logic, greetings, or data actions in the start agent.

**Diagnosing this class of bug:** the Agent API returns `result: []` and exposes no action invocations. Only **Agentforce Builder Preview** shows the trace — `Reasoning: <subagent>`, `Transition to Subagent`, `Action: <name>`, and a GROUNDED/UNGROUNDED verdict per turn. If an action is not firing, get a Preview trace before changing anything; it tells you which subagent the agent was actually standing in.

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

### Guest users, Named Credentials, and the site

A guest user calling out through a Named Credential backed by an external
credential principal needs **two** distinct grants, and having one without the
other fails in a way that looks like a broken site rather than a permission
problem:

1. `externalCredentialPrincipalAccesses` for the principal, and
2. **read on the standard `UserExternalCredential` object.**

Both go in `NM_Guest_Site_Access`. Granting only the first still fails.

**When the widget errors on the public site, hit the endpoint anonymously
before reading logs.** One unauthenticated POST to the site's own Apex
endpoint returns the actual error:

```
curl -X POST "https://<site>/<path>/webruntime/api/apex/execute" \
  -H "Content-Type: application/json" \
  -d '{"namespace":"","classname":"NM_AgentController","method":"startSession",
       "params":{"sourceUrl":"https://test"},"cacheable":false,
       "isContinuation":false}'
```

This cost hours once. A debugging pass concluded the guest never reached Apex,
reasoning from an absence of ApexLogs for the guest user, and went looking at
client-to-Apex transport and site publish state. The guest was reaching Apex
the whole time; the logs were not being captured for that user. **Absence of
logs is not evidence the code did not run.**

A related red herring: the live LWR home page HTML contains no component
references. LWR is a single page app and renders client side, so component
markup never appears in the initial HTML. Its absence proves nothing.

### Publishing an agent does NOT activate it

`sf agent publish authoring-bundle` creates a **new version** and leaves the
previously activated version serving traffic. Publish reports
`published successfully` either way, so nothing in its output tells you the
org is still running old instructions.

**Every publish must be followed by an activate:**

```
sf agent publish authoring-bundle --api-name NM_NextMission_V2 --target-org <org>
V=$(ls force-app/main/default/bots/NM_NextMission_V2/ \
     | grep -o 'v[0-9]*' | sort -t v -k2 -n | tail -1 | tr -d 'v')
sf agent activate --api-name NM_NextMission_V2 --version $V --target-org <org>
```

Activate prints `NM_NextMission_V2 v43 activated.` That line, and only that
line, means your edits are live. `sf agent activate` without `--version`
prompts interactively for a choice and will hang in a non-interactive shell,
producing an empty log that looks like a timeout.

Publish also writes the new `vNN.botVersion-meta.xml` into
`force-app/main/default/bots/`, which is how you read the version number back.

**This cost most of a day.** Six consecutive edits were published, tested, and
judged to have "no effect", producing a series of wrong conclusions about
variable persistence, conditional evaluation and same-turn transitions. All of
them were wrong. The org was serving v35 throughout while v36 to v41 sat
published and inactive.

**Verify with a marker, not by reading the reply.** Put a nonsense token in
the instruction under test (`Begin your reply with the exact word ZULU`),
publish, activate, and check whether the token comes back. A behavioural read
of a reply cannot distinguish "the model ignored my instruction" from "the
model never received my instruction". A marker can, in one turn. Both failure
modes look identical otherwise, and they have opposite fixes.

### Every variable a router branches on must be set on EVERY path

`clusterKey` was written only by `classify_cluster`, on the free-text describe
path. The code path writes `occupations` and `roleTitle` and never touches it.
The router's entire routing block sat behind `if @variables.clusterKey is not
None:`, so for any veteran who typed a specialty code that block never
executed. `go_to_jobs` and `go_to_mentor` were unreachable, and the agent
could only ever re-ask about their background. It looped for four turns.

The router now tests `clusterKey is not None or roleTitle is not None`, which
covers both paths. `or` and `and` both compile in Agent Script conditionals.

**When adding a second path that establishes the same state, re-check every
condition that tests for that state.** A new path that sets different
variables silently disables every branch keyed on the old ones.

### One payload, one presenter

After the O*NET cutover both `NM_Skills_Translation` and `NM_Job_Matching`
rendered `{!@variables.occupations}`, so consecutive turns said the same
thing. Skills now presents transferable skills and is explicitly forbidden
from naming a civilian job title; Job Matching names the roles. Two subagents
rendering one variable is a design smell, not a prompt problem.

### The Experience site: retrieve before you edit, never deploy stale

The standing rule is that the DigitalExperienceBundle is not deployed to a
live LWR site. The reason is concrete: on 2026-09-01 a retrieve immediately
before editing came back with **10 files differing from the repo**. Deploying
the checked-in bundle as it stood would have reverted real Builder changes.

If a component must be placed programmatically, the only safe sequence is:

1. `cp -r force-app/main/default/digitalExperiences /tmp/backup` (rollback)
2. `sf project retrieve start --metadata DigitalExperienceBundle:site/Next_Mission1`
3. Edit `sfdc_cms__view/home/content.json` — components live in the region
   whose `children` array holds the existing component, each entry being
   `{"attributes":{"dxpStyle":{}},"definition":"c:name","id":"<uuid>","type":"component"}`
4. `sf project deploy start --metadata DigitalExperienceBundle:site/Next_Mission1`
5. `sf community publish --name "Next Mission"`
6. Verify: the home page returns 200 **and** a guest conversation still
   completes. A successful deploy is not evidence the site still works.

Prefer Builder for anything more than adding a component to a region.

### Widget design system

`nmChatWidget` uses the "Forward" palette (pine `#14532D`, sand `#EFE7D8`,
cream `#F8F5EE`, ink `#1B1B18`, clay `#8A4513`). `nmHero` and `nmAbout` repeat
the same tokens locally because LWC style scoping does not cross components.

**Run `python3 scripts/check_contrast.py` after any colour change.** It checks
19 pairs against WCAG AA and must report 0 failing. Do not claim a palette is
accessible without the numbers; "verified AA" is not checkable, a ratio is.

Agent replies are parsed into blocks in `_parseBlocks`: `Title :: Description`
or `Title: <40+ chars>` becomes an occupation card, a paragraph opening
"I found a mentor" becomes a person card, `- ` lines become a list, `**x**`
becomes bold. **Every branch must fall back to a plain paragraph** so an
unexpected reply shape still reads correctly. Never make the widget depend on
the agent emitting a delimiter.

CSP blocks external assets on the site. All graphics are inline SVG. Do not
add image files, CDN links or web fonts beyond what LWR already loads.

### Resume upload (NMDH-31), what the next session needs

Stubbed at `handleUpload()` in `nmChatWidget.js`, gated by the `@api
enableResumeUpload` property, default **false**, so no dead button ships.

Known before starting:

- **Guest file upload will fail like a permission problem disguised as a UI
  bug.** The guest user needs create on `ContentVersion` and
  `ContentDocumentLink` in `NM_Guest_Site_Access`. Reproduce with an anonymous
  POST to the site's `webruntime/api/apex/execute` before reading logs, for the
  reasons in the guest-credential section above.
- **Apex cannot parse PDF.** Either reuse the OCR chain from the Maya build or
  restrict the demo to DOCX/TXT and treat PDF as best effort.
- **Resumes only, never a DD-214.** It carries discharge characterization and
  an SSN, and the system instructions already forbid restating discharge type,
  VA status or disability rating. Soliciting the document containing all of it
  contradicts our own guardrail. The control must say "resume" and nothing
  broader. Extracted text falls under the existing sensitive-details rule.
- Extracted text feeds the **existing** background path: either a code is
  picked out of it and sent to `look_up_occupations`, or the text becomes the
  description passed to `classify_cluster`. Do not add a third path.
- On extraction failure the agent says so and asks them to describe the role.
  It must never invent a background it did not extract.

### Guest users cannot read or update records. Not even without sharing.

This broke conversation logging for weeks and nobody noticed, because the
failure returned HTTP 200.

`logTurn` did `Database.upsert(conv, External_Session_Key__c, false)`. Upsert
by external id runs an implicit match query. A guest user cannot see the
record, so **every turn after the first was treated as an insert** and failed
with `DUPLICATE_VALUE`. `allOrNone=false` swallowed it, the LWC had
`.catch(() => {})`, and the call still returned success.

**Proven at runtime, not inferred:** an explicit `SELECT Id ... WHERE
External_Session_Key__c = :key` from a `without sharing` inner class returned
**nothing**, while the DUPLICATE_VALUE error named the exact record id it could
not see. `without sharing` does not lift guest record visibility.

So in guest context there is no read-modify-write at all. Logging is now
**insert-only, one row per turn**, with the key suffixed `-t<n>`. The widget
sends the cumulative transcript every turn, so the row with the highest
`Message_Count__c` for a session holds the complete conversation. That is the
contract `NM_QAEvaluator` reads. NMDH-32 collapses the rows from an admin
context.

Also fixed at the same time:

- **A complex Apex parameter cannot be called from a guest LWC.** `logTurn`
  took a `LogTurnRequest`, and the Experience Cloud webruntime endpoint
  rejected it with "The Apex request is invalid" before any Apex ran. That is
  why zero widget-written transcripts existed. The widget now calls
  `logTurnFlat`, which takes primitives. **Never give a method the guest widget
  calls a custom-type parameter.**
- The LWC no longer swallows logging errors. It logs to console rather than the
  error banner, because a logging failure is ours and must not interrupt the
  veteran.

**Parked:** `NM_Conversation_Turn__e` and `NM_ConversationTurnTrigger` were
built as the elevated-writer path. Events published successfully
(`sr.isSuccess()==true`) but the trigger never produced a record and never
produced an Automated Process log, so delivery was never confirmed in this org.
Do not assume that path works without re-testing it.

**Two writers exist for `NM_Conversation__c`.** The widget writes keyed rows;
something running as NM Agent Bot writes rows with a null key and no
transcript, which the QA grader then scores 0 and marks "Skipped: no transcript
available". The V2 agent script has no logging action, so that writer is a
leftover. Track it down before trusting QA numbers.

### Prompt templates: invoke from Flow, never ConnectApi

`ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate` throws
`Failed to generate Einstein LLM generations response` in this org for **every**
prompt template. It is not a template problem.

**Proven, not assumed:** the same ConnectApi call was pointed at
`NM_Find_Mentor_Template`, which the agent uses successfully on every mentor
match, and it failed identically. Two templates, same error, one of them
known-good. That isolates the failure to the ConnectApi path itself.

Working pattern, used by `NM_FindMentor_Flow` and now `NM_QAGrade_Flow`:

```
actionType: generatePromptResponse
actionName: <TemplateApiName>
inputParameters:  name = "Input:<ParamApiName>"
outputParameters: name = "promptResponse"
```

then from Apex:

```apex
Flow.Interview f = Flow.Interview.createInterview('NM_QAGrade_Flow', inputs);
f.start();
String out = (String) f.getVariableValue('responseText');
```

The calling class must implement `Database.AllowsCallouts` if it is Queueable.
Always give the action a `faultConnector` so a model failure returns blank
rather than blowing up the interview.

**Do not "simplify" a template call back to ConnectApi.** It will compile,
deploy, and fail at runtime with a message that sounds like a model problem.

### The QA grader chain, and how it was broken end to end

Three independent silent failures stacked, each hiding the next:

1. The widget could not call `logTurn` at all (custom Apex type parameter,
   rejected by the webruntime endpoint for guest callers).
2. Guest users cannot read or update records, so upsert-by-external-id failed
   with `DUPLICATE_VALUE` from turn two onward, swallowed by
   `allOrNone=false` and a `.catch(() => {})`.
3. The grader's ConnectApi call failed for every record that did have a
   transcript, and wrote `QA_Score__c = 0` on its own failure.

The third one is the important lesson: **never write a score on your own
failure.** A broken grader looked exactly like an agent performing terribly.
Both the empty-transcript path and the grader-error path now leave
`QA_Score__c` NULL and record why. A conversation with no transcript is
unscored, not bad.

After the fix: 21 conversations graded, average 7.57, min 3, with real issue
categories (`MadeUpContent`, `WrongTone`, `NoHelpDelivered`). Those numbers
mean something now; every number before this was an artefact.

### Deploying Apex that a Schedulable depends on

`sf project deploy start` fails with "This schedulable class has jobs pending
or in progress" when the QA grader is scheduled. Abort, deploy, reschedule:

```apex
for (CronTrigger ct : [SELECT Id FROM CronTrigger
                       WHERE CronJobDetail.Name = 'NM Daily QA Grader']) {
    System.abortJob(ct.Id);
}
```
then redeploy, then `System.schedule('NM Daily QA Grader', '0 0 * * * ?', new NM_QAScheduler());`

**Capture the live cron expression before aborting and restore it exactly.**
The live job runs hourly (`0 0 * * * ?`) while the class header documents daily
(`0 0 6 * * ?`). That drift is deliberate for now; do not silently "correct" it.

Note also that `QA_Issues__c` and `Transcript__c` are long text areas and
**cannot be filtered in SOQL**. Select on something else and filter in Apex.

### What the QA grader will and will not score

Conversation logging writes **one row per turn** (a guest cannot update a
record), so one conversation appears as `<session>-t1`, `-t2`, `-t3`, each
holding the cumulative transcript up to that point.

The grader therefore:

1. **Groups rows by base session key** and keeps only the highest turn. The
   earlier rows are marked `Not scored: superseded by a later turn`. Grading
   every row would score a one-line fragment as if it were a finished
   conversation and burn one Einstein call per turn instead of one per
   conversation.
2. **Waits `SETTLE_MINUTES` (30) of silence** before scoring. There is no
   end-of-conversation signal, so this is the closest honest approximation.
   An unsettled row is left for the next run, not graded half-finished.
3. **Does NOT skip short conversations.** Someone who asks one question, gets
   a good answer and leaves has had a COMPLETE conversation, and turn count
   cannot distinguish that from giving up. A length threshold was tried and
   removed for exactly this reason.

**Never write a score you did not earn.** `QA_Score__c` stays NULL for an
empty transcript, a superseded row, and a grader failure, each with the reason
in `QA_Issues__c`. Writing 0 made a broken Einstein call look identical to an
agent performing terribly and dragged every average to the floor.

**A visitor leaving is not the agent's failure.** If the metric starts showing
`NoHelpDelivered` on conversations that simply stopped, fix the template
guidance rather than the score.

**Self-chaining:** the Queueable re-enqueues ONLY when it filled a full batch.
Chaining on "any unreviewed record remains" recursed to
`System.AsyncException: Maximum stack depth has been reached`, because rows
inside the settle window are deliberately left unreviewed and never clear.

### Subagent conditionals are evaluated AFTER the turn's action runs

This one produced a genuinely harmful bug and is not obvious.

`if @variables.mentorId is not None:` inside `NM_Mentor_Connection` fires on the
**same turn `find_mentor` runs**, because the action executes first and its
output binding sets the variable before the instructions are assembled. It is
not evaluated against the state at the start of the turn.

The effect: the "a mentor has already been shown, do not describe them again"
branch fired the very first time a mentor was found, so the agent **never named
the mentor** and jumped straight to "what is your email address?" Asking a
veteran to hand over an address for an unnamed stranger is not consent.

**Proven with markers, not reasoning.** Three instruction blocks were tagged
ALPHA / BRAVO / CHARLIE. On a fresh session where `find_mentor` had never run,
BRAVO came back. That is only possible if the variable was already set.

**Rule:** a variable written by an action in a subagent cannot distinguish
"just happened this turn" from "happened earlier". For that distinction the
instruction must tell the model to read the conversation history. Use the
variable for deterministic ACTION GATING (`available when ... is None`, so it
runs once), and history for deciding what to SAY.

### Codes carry a paygrade or skill level. Normalise in Apex, never in prompts

`NM_LookupOccupationAction` handles two forms, and both are deliberately narrow:

* **Army MOS** `NNXNN` (68W10) drops the two-digit skill level to 68W.
* **Navy rating** two or three LETTERS plus ONE digit (IT2, BM1) drops the
  paygrade to the rating (IT, BM). IT2 is an Information Systems Technician at
  E-5; the crosswalk holds only "IT", so IT2 missed entirely and dumped the
  veteran into the describe path, where they were then classified into a
  completely wrong career cluster.

**Never generalise this to prefix truncation.** Navy NECs are alphanumeric
(V25C, 841A, 4599) and Air Force AFSCs encode skill level inside the code
(2A512E / 2A532E / 2A552E are three distinct rows). Trimming 4599 to 459 lands
on a different real code and returns a confident wrong answer. All of these are
covered in `scripts/scenarios.py`.

### Run scripts/scenarios.py before claiming a conversation works

`python3 scripts/scenarios.py` drives the LIVE public site as an anonymous guest
and **asserts** rather than printing for a human to eyeball. It covers the code
path, the describe path, repeated consent, and a full introduction.

Its most valuable check is `no_repeats`: no two substantive replies may be more
than 75% identical. Short replies are excluded on purpose, because re-asking for
an email the veteran has not given is correct, not repetition.

**This suite exists because ad-hoc happy-path testing repeatedly missed real
defects** that a user hit within one conversation: a mentor re-described three
times, the same skills framing restated four times, and a valid Navy rating
rejected. Add a scenario for every reported defect. A defect that is not in this
file will come back.

### Three separate "deployed is not live" traps. All bit us in one day.

Each of these reports success while the thing you changed is still not what
users get. Assume nothing is live until the specific second step has run.

| Change | Deploy step | The step that actually makes it live |
| --- | --- | --- |
| Agent Script | `sf agent publish authoring-bundle` | `sf agent activate --api-name <n> --version <N>` |
| LWC on the site | `sf project deploy start` | `sf community publish --name "Next Mission"` |
| Site pages | `sf project deploy start` (bundle) | `sf community publish --name "Next Mission"` |

**Deploying an LWC does not update the site.** The component is updated in the
org, but the Experience site keeps serving its last published build. A user
hard-refreshing will still see the old component and will reasonably conclude
you never made the change. This wasted a round trip: the restart button was
correctly deployed and confirmed present in the org's own copy of the bundle,
and still was not on the page, because the site had not been republished.

**After ANY widget change:**

```
sf project deploy start --metadata LightningComponentBundle:nmChatWidget --target-org <org>
sf community publish --name "Next Mission" --target-org <org>
```

Publishing is asynchronous. Give it a minute, then verify the home page returns
200 **and** a guest conversation still completes. A successful publish call is
not evidence the site works.

### Instructions are not a mechanism. Split the subagent instead.

The mentor was described twice in a row: presented, the veteran said "Yes,
connect me", and the same paragraph came back verbatim.

The first attempt fixed it with wording, a block saying "if you already named
this mentor, never describe them again, read the history to tell which
situation you are in". It passed the suite and then failed in real use, because
that asks the model to make a judgement call every turn and it will not make it
reliably. **An instruction is a preference. A subagent boundary is a
guarantee.**

The structural fix, which is also why it works:

* `NM_Mentor_Connection` finds and presents. It owns `find_mentor` and does NOT
  own `request_mentor_intro`.
* `NM_Mentor_Intro` handles consent and sending. It owns `request_mentor_intro`
  and has **no access to mentor data at all**, so it physically cannot
  re-describe anyone.
* The router picks between them on `@variables.mentorId`.

This works where a subagent conditional could not, because **the router's
conditionals are evaluated at the start of the turn**, before any action runs.
A conditional inside a subagent is evaluated after that turn's action, so
`mentorId` is already set on the very turn `find_mentor` runs and cannot
distinguish "just now" from "earlier". The router can.

The same shape solved the earlier planner problem, where `look_up_occupations`
and `classify_cluster` competed inside one subagent until they were separated.
**When two behaviours compete inside one subagent, separate the subagents.**

### Run flaky scenarios more than once

Conversation defects are frequently flaky. The mentor repetition passed a single
run of the suite and was then reported from real use within the hour.
`scripts/scenarios.py` takes `repeat=N`; use it for anything the model could get
right by luck. A single green run proves very little.

### Test whether the answer is RIGHT, not whether it is well formed

Every sweep before this one passed while a helicopter mechanic was offered
Construction Project Manager, Heavy Equipment Operator and Estimator. The
checks were all about mechanics: no repetition, no banned words, no API errors.
Nothing verified the answer was correct, so a confident wrong answer sailed
through, and that is the one a veteran would actually act on.

`scripts/broad_run.py` now carries relevance assertions per scenario:
`relevant(...)` requires the right vocabulary to appear, `never(...)` fails the
whole conversation if a wrong career field appears at all.

**Prove a new assertion can fail.** Feed it the real bad transcript and confirm
it returns False, then feed it a correct one. An assertion that passes on both
is decoration.

### Two describe-path bugs worth remembering

* **Re-classification overwrites a correct cluster.** "I fixed helicopters"
  classifies as Aviation, then "i was a master sergeant" on the next turn could
  reclassify to Engineering and silently move the veteran into the wrong career
  field. `classify_cluster` is now `available when @variables.clusterKey is
  None`, so a follow-up detail cannot change what they are.
* **`userDescription` was never set by any action** yet was bound as
  `with userPrompt=@variables.userDescription`, so the skills translation
  received NULL and lost the veteran's own words. Binding an input to a
  variable nothing writes is a recurring failure in this file. Before adding
  `with x=@variables.y`, confirm something actually sets `y`.

### Read the conversation as a person. Assertions inherit your blind spots.

The scenario and the assertion get written from the same mental model, so when
that model is wrong the test passes anyway. Every sweep was green while an
avionics technician was offered Commercial Airline Pilot, because the checks
asked "is this well formed" and never "is this right".

`scripts/live.py` keeps ONE session open across invocations so a conversation
can be driven turn by turn, reading each reply before choosing the next
message. Use it. Talking to the agent for five minutes found four defects that
29 scripted conversations did not:

* **It ignored disqualifying information.** Told twice "I'm not a pilot" and
  "I'm 41, you said the cutoff is 35", it re-printed the identical five roles
  including both. It only adapted on the third try.
* **It would not answer "which one should I go for".** An old instruction said
  never rank or editorialise, which was meant to prevent fabrication and
  instead made it useless at the one question a career coach exists to answer.
  It may now recommend, grounded in what the veteran said and what the role
  involves, while still never inventing a fact, promising a hire, or comparing
  on pay.
* **"Which one should I go for" routed to the MENTOR subagent**, which then
  offered a pilot mentor to someone who had just said they never flew. A
  question about the roles is not a request for a mentor.
* **Fixing the first one caused a guardrail regression.** "Act on what they
  tell you" collided with the sensitive-details rule and it replied "your 70%
  disability rating does not change which roles match", restating the number.
  The carve-out is now explicit and overrides the listening instruction.

Two lessons worth keeping. **A green suite means the checks passed, not that
the agent is good.** And **when an assertion fails, decide whether the agent or
the check is wrong** before changing anything: two of these failures were bad
assertions, including one that failed the agent for correctly saying "I have
taken Commercial Airline Pilot off the list".

### Accessibility: what is measured, what a human confirmed, what is open

**Measured** (`python3 scripts/check_contrast.py`, plus the page pairs):
19 widget pairs and 16 hero/about pairs, **0 failing**. Body copy 7.70:1 to
15.85:1, headings 9.11:1, focus ring 7.14:1 on white and 6.56:1 on cream.

Two greens exist on purpose. `#14532D` pine is the only green used for text,
at 9.11:1. `#3F9142` signal green is **3.93:1 and must never carry text** — it
is for rules, card edges and typing dots, where 3:1 for non-text applies.
No red appears in the page components, so green never conveys meaning against
red for the ~8% of men with red/green colour blindness.

**Confirmed by hand on the published site (2026-09-01):**
* Tab moves through the controls in order.
* **No keyboard trap.** Tabbing past the widget reaches the page and then the
  browser address bar. This is the failure that actually strands people.

**Confirmed by hand with VoiceOver (2026-09-02, and again 2026-09-03):**
The first pass is how the `aria-busy` bug was found: it was set during loading
and silently suppressed the announcement of the reply that followed. **axe-core
passed that page clean.** An automated scan cannot hear what is not spoken, so
treat 0 violations as the floor and never as the evidence.

The second pass covers the markup that shipped after the reflection session and
therefore was not in the first: the roles `<ul>`/`<li>`, the sr-only
"Role N of M" span, the "Show the other N roles" collapse button, and the
reachable step buttons announcing as "Skills, done, go back to this".

**Accessibility Reflection Coach (2026-09-03): all five items ADDRESSED.**
Pace (card collapse), screen-reader list semantics, recap discoverability,
non-destructive backtracking, and the live AT pass on the new markup.

**Verified in code:** the LWR theme stylesheets, branding set and both theme
layouts contain **zero** `outline: none`, so theme controls keep the browser
default ring. Our five focus rules all ADD a 3px ring, none remove one, and
they use `:focus-visible` so the ring appears on keyboard focus but not on
mouse click.

**Still open, and should not be claimed as done:**
* Reflow at 200% and 400% zoom.
* **Whether three is the right number of cards before collapsing.** It is
  reasoned, not validated. One card was rejected because it strips away the
  comparison the veteran is actually making, and because it reads as the agent
  deciding what they can handle. The right threshold for working memory after
  TBI is a clinical judgement, and settling it needs a usability check with
  veterans or spouses who self-identify with attention or memory impact.
  Do not quietly change this number without that check; it would be swapping
  one unvalidated guess for another.

### Current live state — DO NOT TRUST THIS SECTION, QUERY THE ORG

This section said "Agent: v58" for two days while the live agent was at v106.
That is the point: **anything that changes on every deploy will be stale here,
and a stale fact is worse than no fact** because it reads as authoritative.

Query it instead, every time:

```
sf data query --target-org dreamforce-hackathon \
  -q "SELECT VersionNumber, Status FROM BotVersion \
      WHERE BotDefinition.DeveloperName='NM_NextMission_V2' AND Status='Active'"
```

Publishing does not activate. Check what is actually live before testing, and
put the version in anything you report.

What follows is durable enough to write down, because it is a decision rather
than a number:
* **Mentors: 70 active**, including Coast Guard (6) and Military Spouse (5),
  both of which were zero before 2026-09-01.
* **Prompt templates:** `NM_QA_Evaluator_Template` runs `DefaultOpenAIGPT4Omni`;
  the other three run `DefaultOpenAIGPT4OmniMini`. See
  `MODEL-REVIEW-2026-09-01.md`.
* **The platform-event logging path is DELETED, not parked.**
  `NM_ConversationTurnTrigger` and `NM_Conversation_Turn__e` are gone. Do not
  revive them expecting delivery to work; it was never confirmed, and the
  trigger sat at 0% coverage blocking every validation deploy.

### The mentor shortlist is capped. Do not undo it.

`NM_FindMentor_Flow` used to pass the ENTIRE active roster into the prompt. At
70 mentors that is ~6,000 tokens and turns the task into "pick one of 70",
which is what small models handle worst.

`NM_MentorCorpusAction` now returns at most 15: up to 10 from the veteran's
career area, then the rest ranked by **word overlap with what the veteran
actually said**. Cluster stays a tie-breaker, never a hard filter, so a match
outside their field is still reachable. That was the point of NMDH-24.

**The ranking is not optional.** Without it the "others" pool filled in Name
order, and because `clusterKey` is blank on the coded path, the shortlist became
the first 15 alphabetically. A combat medic matched a supply chain manager
because Alex sorts before Cameron, and Navy IT matched nothing. Two cases that
worked before the cap were worse after it. `NM_MentorCorpusActionTest` has a
test that fails if the shortlist reverts to alphabetical order.

Measured after the fix, 6 of 6 exact: avionics to Avionics Technician, medic to
Paramedic, Navy IT to Cybersecurity Analyst, truck driver to Heavy Truck Driver,
spouse to Medical Biller, boatswain to Port Operations Supervisor.

Re-run `scripts/data/mentor_match_test.apex` after any change to the roster,
the flow, or that action.

### The screen and the agent session must be the same conversation

`nmChatWidget` renders the greeting locally on every load. It used to also
RESTORE a stored agent session, which put the two out of step: the visitor saw a
blank conversation while the agent still held everything from the previous one.

Caught live during a demo. Someone had been looking at construction roles,
reloaded, saw a fresh greeting, typed **Army 88M**, and got construction jobs
back. The router still saw an established cluster, skipped the code lookup
entirely, and answered confidently with the wrong career field. Nothing in the
UI hinted that the agent remembered anything.

The widget now **always starts a new session on load** and clears any stored
one. A reload starts over, which is what showing a greeting already implies.

**Rule: never render conversation state the agent session does not share.** If
the transcript is ever persisted across reloads, the agent session has to be
restored with it, or neither should be.

This class of bug is invisible to `broad_run.py` and `triage_reports.py`, since
both open a fresh session per conversation. It only appears to someone using the
widget across page loads.

### O*NET releases: the monitor compares LABELS, not content

`NM_ONETReleaseMonitor` flagged the data as stale at `db_29_1` against a
published `db_31_0`. Checked properly on 2026-09-01, the data was **already
current**:

* All **1,016 occupations hash identical** between the org and a fresh
  `db_31_0` download. 263,541 characters, same hash, zero differing titles or
  descriptions.
* We only load `Occupation Data.txt`, which did not change between those
  releases. O*NET releases mostly revise the ratings and skills files we do not
  use.

So the reload was a **label correction, not a data refresh**.
`Loaded_ONET_Release__c` is now `db_31_0` and `Refresh_Needed__c` is false.

**Two things worth knowing before acting on that alert again:**

1. The monitor comparing release labels will keep raising alerts that have no
   practical effect on us, because our subset of the database is far more stable
   than the release cadence. **Verify content before reloading.** The hash
   comparison above is the cheap way to do it.
2. **The military crosswalk is not versioned with the database at all.** It comes
   from a fixed URL (`military_crosswalk.zip`, currently `milx0724.csv`, July
   2024) and the monitor does not track it. Our 8,179 military codes could go
   stale with no alert whatsoever. That gap belongs in NMDH-32.

**Always re-run mapping integrity after any real reload.** A version mismatch
between the crosswalk and the occupation set orphans mappings silently. Current:
425 distinct O*NET codes referenced, **0 missing**, against 1,016 occupations.

### The cluster DATA was wrong, not the classifier

The single most useful thing learned fixing NMDH-34. Every reported "classifier
mis-routes" finding traced to what the clusters CONTAINED, not to the
classification:

* **Engineering** held five construction roles and nothing mechanical, so a
  nuclear reactor operator and a diesel mechanic both got construction.
* **Aviation** listed Commercial Airline Pilot FIRST, so an avionics technician
  was offered a pilot seat.
* **Intelligence** had no geospatial roles, so an imagery analyst could not
  reach Remote Sensing Scientists even though the rows existed.

Avionics classified to Aviation and imagery to Intelligence perfectly well. The
answers were wrong because the buckets were wrong.

**Before changing a classifier prompt, print what the cluster actually
contains.** Clusters now number 13: the original nine minus the Aviation split,
plus Mechanical_Maintenance, Power_Systems, Food_Service, Emergency_Services and
Aviation_Maintenance.

The classifier reads its cluster list as a **dynamic input**, so a new CMDT
record becomes selectable with no prompt edit at all.

### When an instruction will not hold, use a mechanism

Told plainly that nuclear outranks the job title, **both GPT-4o-mini and GPT-4o**
classified "machinist mate on a nuclear submarine who ran the reactor plant" as
mechanical maintenance. Upgrading the model changed nothing.

`NM_ClassifyCluster_Flow` now has a deterministic decision after classification:
if the description mentions a reactor or nuclear, force `Power_Systems`. Non
nuclear machinists are untouched. That worked immediately where two rounds of
prompt wording had not.

Same lesson as the mentor subagent split. **An instruction is a preference; a
subagent boundary, an action gate or a flow decision is a guarantee.**

### Test suites, and the checks that were wrong

* `scripts/broad_run.py` — 39 scenarios, every root cause covered
* `scripts/triage_reports.py` — re-runs the reported repros, 12 of 12 fixed
* `scripts/rc2_misroutes.py`, `rc4_fabrication.py`, `rc6_anaphora.py` — targeted

**Six of my own checks were wrong before the agent was.** They flagged the
refusal "I cannot say which role pays more" as a pay ranking, the reassurance
"not a mistake on yours" as blame, the role title "Infantryman" as an offered
civilian occupation, short "what is your email" re-prompts as repetition, and
"Aviation Maintenance Technician" as fabricated when it is our own cluster data.

**When a check fails, establish whether the agent or the check is wrong before
changing anything.** Measure the actual value: a repetition flag was traced to
0.01 to 0.12 similarity, proving the threshold was fine and the one failing run
was a genuine outlier. Loosening the check would have hidden a real defect.

### Fabrication: what counts as invented

The legitimate set is **1,060 titles**: every `NM_Occupation__c` row plus every
hand-authored cluster role. **44 of 68 cluster titles are not O*NET rows** and
that is a deliberate design choice, so "Aviation Maintenance Technician" and
"Flight Operations Coordinator" are OURS. The reports called them fabrications;
they are not. Only a title in neither source is invented.

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

## Production Roadmap and Open Architecture Questions

Recorded 2026-09-01 after an end-to-end test and repair session. These are decisions and open tensions a future session must not re-derive from scratch.

### The nine clusters are scaffolding

`234 codes -> 9 clusters -> 45 jobs` compresses away most of what makes advice useful, which is why a 68W and a 68G received identical translations until `roleTitle` was carried through. Production replaces cluster matching with **O\*NET occupations via the DoD military crosswalk** (NMDH-22), joined to **BLS wage data** (NMDH-23). Clusters survive as a browse facet, not as the matching key.

That also means Custom Metadata stops being the right home. CMDT is correct for 234 static rows under our control; it is wrong for thousands of records on a refresh cycle.

### Semantic matching does not require a retriever

`NM_ClassifyCluster_Flow` is already semantic — it shows the model all nine clusters and asks which fits. That is exhaustive semantic search, and it is why "I was a grunt" resolves to CombatArms when the word appears nowhere in the data.

A **retriever's job is narrowing a corpus too large to show the model at once.** With nine clusters or nineteen mentors there is nothing to narrow, and a retriever adds infrastructure, cost and non-determinism for no gain. The crossover is somewhere in the low hundreds of records.

This interacts with the NMDH-21 override above. A Data Cloud retriever for job matching is **justified once the catalog grows to O\*NET scale (~900 occupations)** and is over-engineering against today's 45 jobs. Sequence matters: grow the catalog first, then the retriever earns its place.

Keep action contracts stable so the implementation can change underneath: `find_mentor(clusterKey, description) -> mentor record` works whether the inside is SOQL, a prompt over the whole table, or a retriever. None of those should require an agent script change.

### Put logic in code and data, never in instructions

The single most expensive lesson of 2026-08-31. Ten diagnostic cycles were spent trying to make the model call an action by explaining harder. It never worked, because the action was out of scope. What fixed it was making the action reachable.

* Anything that must always happen is deterministic, not a tool the planner may choose.
* Session state is written **only** by action output bindings. The model cannot write to a variable no matter how the instruction is phrased.
* The start agent is a thin router with no business logic.
* Actions have narrow contracts and do one thing.

### Open items not yet built

* **NMDH-25 observability.** There is no per-turn trace outside the Builder UI. The Agent API returns `result: []`. This is the highest-value production item — every defect found on 2026-08-31 would have taken minutes rather than hours.
* **Evaluation harness in CI.** A golden set of conversations asserting against the org, not the transcript. Transcripts read as success for hours while the mentor flow created nothing.
* **Mentor capacity and consent.** Nineteen volunteers with unlimited introductions is a burnout risk. Needs per-mentor limits, cooldowns, opt-out, and confirmation that mentors agreed to receive introductions from this system at all. The agent currently emails them because an address exists in a field.
* **Designed crisis response.** Salesforce's platform guardrail fires on words like PTSD and overrides all instructions, derailing the conversation. For this audience that will happen regularly. Design a deliberate response naming the Veterans Crisis Line rather than inheriting a generic one.
* **Data retention.** Anonymous by default is good. Collected emails need a retention policy and a deletion path.

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

### A rejected match is a dead end you have to build a way out of

Agent v71. A Coast Guard Boatswain's Mate maps to exactly one civilian
occupation, and it needs a licence. When the veteran said they had no licence
and did not want to be on the water, the agent restated the same role, the same
licence and the same problem, twice. There was already an instruction forbidding
exactly that, in capitals.

The instruction could not be obeyed. `get_job_matches` was gated
`available when @variables.occupations is None`, so once a code had been looked
up the turn had no content available except the coded list. The agent repeated
itself because repeating itself was the only thing it could do.

The fix was to gate on `@variables.clusterKey is not None` instead and add a
`broaden_beyond_code` binding, so a coded veteran who rules out their match gets
placed into a career area from what they actually did and sees a real, different
set of roles. The instruction stayed, but it stopped being the load-bearing part.

Worth generalising: when an instruction forbids a behaviour and the behaviour
keeps happening, check whether the model has any other option available to it.
Often the instruction is not being ignored, it is being made impossible.

Note that action definitions are scoped to the subagent that declares them.
`@actions.classify_cluster` exists in NM_Describe_Background and is invisible in
NM_Job_Matching; the compiler says `'classify_cluster' is not defined in actions`.
Declare it again in the subagent that needs it.

### Thin crosswalk rows: supplement, never overwrite (NMDH-37)

Measured first, which changed the fix. 94% of the 8,179 crosswalk rows map to a
single SOC code, so "single SOC" is not the defect. The real defect is narrower
and countable: **934 codes (11.4%) map only to an "All Other" residual bucket**,
and 139 of those are 55-xx already handled by the military-only guard. That
leaves **795 codes across 37 distinct buckets**, which is what made this a
general fix rather than whack-a-mole.

`NM_Occupation_Supplement__mdt` keys either on a SOC code (covering every
military code whose sole match is that bucket) or on `BRANCH:CODE` for one code.
Code-specific wins. The O*NET row stays the authoritative *direct* match and the
supplement is only ever offered as *adjacent*, so we keep being able to say
every match comes straight from the federal crosswalk.

30 of the 37 buckets were derived from the SOC **broad** group (`XX-YYY`). The
first attempt used the **minor** group (`XX-Y`) and produced nonsense:
"Education Administrators, All Other" pulled in Farmers and Construction
Managers. That is the same failure as the mentor-corpus alphabetical fill, and
the lesson repeats: an ordering that looks principled is not the same as one
that is relevant.

The remaining 7 were hand-curated because the group itself is a grab bag.
`49-9099` offered Coin and Vending Machine Servicers, Commercial Divers and
Locksmiths to people who maintained torpedo and weapons systems. No rule
rescues that; it needed judgement, and `Basis__c` records which records were
rule-derived and which were curated so a later maintainer can tell them apart.

Guardrail worth keeping: `NM_OccupationSupplementDataTest` asserts every
adjacent SOC resolves to a real `NM_Occupation__c` row, and that none is 55-xx.
A typo in the metadata would not throw. It would silently drop a role and show a
shorter list, which reads as a thin mapping rather than as a bug.

### Resume upload, and three things that cost real time (NMDH-31)

The file is read in the BROWSER and only its text is sent. Someone asking a
question about their resume should not have to hand us the document to get an
answer. pdf.js ships as the `NM_PdfJs` static resource because Experience Cloud
CSP blocks third-party script hosts.

`sendResume` takes flat String parameters for the same reason `logTurnFlat`
does: the webruntime endpoint rejects complex Apex parameter types.

**getAll() vs SOQL on custom metadata is a guest-user trap.** Switching
`NM_LookupOccupationAction` from `getAll()` to SOQL took the suite from 47/47 to
37/47 with *every code lookup* failing, while the same Apex run as an admin was
perfect. SOQL on a custom metadata type is subject to the running user's access
and the Experience Cloud guest user has none on `NM_Occupation_Supplement__mdt`.
`getAll()` bypasses that. The opposite is also true and equally sharp:
`getAll()` does NOT populate Long Text Area fields on every type, which is why
`NM_GetWagesAction` genuinely needs SOQL for `Job_Descriptions__c`. Verify the
field actually arrives rather than assuming either way, and test as the guest.

**An instruction the model can reach without the action is not a guardrail.**
Navy NEC V25C failed 3 times in 5 while the Apex resolved it every time. The
agent was skipping the lookup and writing the not-found line from its own
judgement, because it did not recognise the code. Gating that script on a real
`found=false` from the action took it to 0 failures in 6.

**Anchor an edit on text unique to its target.** A consolidation pass matched
`NM_Skills_Translation` instead of `NM_Job_Matching` because their opening lines
are nearly identical, and deleted a subagent boundary. Check the subagent count
before publishing.

### Residual non-determinism, stated honestly

As of agent v96 the suites run **44 to 47 clean out of 47**, not a reliable 47.
The residual is almost entirely one failure mode, repetition, and it is worth
recording what did and did not move it.

Measured on the Marine 0311 military-only path, "does turn 2 repeat turn 1":

| change | rate |
| --- | --- |
| before any fix | frequent |
| instruction: check your own history | 1 in 6 |
| instruction: narrow the route back to the greeting | 2 in 8 |
| **mechanism: gate look_up_occupations on roleTitle being empty** | **1 in 8** |

Instructions moved it barely at all. The action gate helped most, which is the
same lesson as everywhere else in this file, but none of it reached zero.

Two things a later session should try before adding more prose:
1. The global instruction block is ~8.4k characters and NM_Job_Matching is
   ~14.7k. Every fix today added text and nothing removed any. Consolidating is
   the most likely remaining lever, but it must be done with edits anchored on
   text unique to the target subagent.
2. `Resume then pay, end to end` fails intermittently with an API error rather
   than a wrong answer. A 12k-character resume plus a wage lookup is the longest
   request we make, and it looks like a timeout rather than a defect.

Do not report a single clean run as proof. Run the suite three times.

### Outcome evaluation, and the two things it caught that nothing else did

`scripts/sim_eval.py` runs ten realistic veteran journeys end to end and hands
each transcript to `NM_QA_Evaluator_Template`, the same LLM grader that reviews
real logged conversations. It scores 1-10 on whether the person left knowing
more about what they can actually do next. Run it alongside `broad_run.py`, not
instead of it: substring checks catch plumbing, this catches usefulness.

It found two things immediately that every substring check had passed:

**1. The platform refuses a veteran in distress, and no instruction fixes it.**
"I have been out two years and I can't hold a job, I'm drinking too much"
returned *"Sorry, I can't assist with that."* That is Agentforce's own refusal,
fired before our instructions are consulted. Measured 5 times in 5 with an
explicit instruction forbidding exactly that reply. The same person phrased as
"I feel hopeless" got the crisis line correctly, so it is the substance-use
wording specifically.

The guarantee now lives in `NM_AgentController.applyDistressNet`, not in a
prompt, because a prompt can be talked out of and this cannot be allowed to
fail. It replaces a refusal with the Veterans Crisis Line, or prepends it when
the agent answered about careers as though the person had not spoken. It fires
only on phrases someone uses about THEMSELVES, so ordinary career talk is
untouched. That journey went 6/10 "NoHelpDelivered" to 8/10.

**2. Deflection reads as stonewalling.** Answering a repeated pay question with
"I already gave you those figures" plus a menu made a frustrated veteran ask a
fourth time. The rule is now: answer again in a few words, then volunteer
something they do not have yet. This CHANGED the intended behaviour, so the
D01-B check was rewritten a second time; a figure reappearing is no longer the
defect, a reply that adds nothing is.

The grader itself needed fixing twice, which is worth remembering before
trusting a score: it treated any stated salary as a serious failure, left over
from when we had no wage data, and it tagged RepeatedQuestion against the AGENT
when the VETERAN was the one repeating.

**Known limit, deliberately left failing.** "asks the same pay question three
times" scores 5-6. Read the transcript: the agent answers each time and adds
certifications, timelines and comparisons. The grader marks the conversation
down because the simulated veteran is frustrated by construction. Left visible
rather than tuning the bar to hide it.

## Pay, resumes, and the evaluation that actually catches things (2026-09-02)

### Substring checks are not evaluation

`broad_run.py` asserts that a reply contains the word "diesel". That tells you
the plumbing works and nothing about whether a veteran was helped. Every
regression that mattered this month passed a substring check first.

`scripts/sim_eval.py` is the answer to that. It runs whole veteran journeys and
hands each transcript to `NM_QA_Evaluator_Template`, the same LLM grader used on
real logged conversations, which scores 1-10 and tags what went wrong. Run it
before believing the agent is in good shape.

**On its first run it found something no substring check would have.** A veteran
saying *"I've been out two years and I can't hold a job, I'm drinking too much"*
received **"Sorry, I can't assist with that."** That is Agentforce's own
platform refusal, fired before our instructions are consulted. An explicit
instruction forbidding exactly that reply changed nothing: measured 5 times out
of 5. It is the worst answer this product can give and it was invisible to 47
passing conversation tests.

The guarantee now lives in `NM_AgentController.applyDistressNet`, where it
cannot be talked out of. Detect distress in the veteran's own words, and if the
reply is a refusal or ignores them, lead with the Veterans Crisis Line. Narrow
markers on purpose; firing on "that job sounds stressful" would bury a real
disclosure in noise.

**Generalise this:** when a guardrail matters, ask whether the platform can
override you. If it can, the guardrail does not belong in a prompt.

### Pay (NMDH-23)

BLS OEWS May 2024, 968 records, 95.3% coverage, in its own `NM_Wage__c` object so
an O*NET reload cannot wipe it. Median leads, range always accompanies it,
broad-group figures are disclosed. Ranking by pay is allowed now **because** the
figures can be shown.

BLS returns **403 to a default User-Agent**; it needs contact details. Bulk
upsert needs **LF** line endings on macOS.

### Resumes (NMDH-31)

Read in the browser with pdf.js from a static resource, so the file never
reaches Salesforce and only text is sent. The agent both **uses** the resume as
the background description and **rewrites** it: NCOIC becomes "supervised a
12-person maintenance team", PMCS becomes "preventive maintenance and
inspection", battalion becomes "a 500 to 1,000 person organisation". It may
never add a number, tool or credential the veteran did not state; an invented
figure on a resume gets asked about in an interview.

### Two traps worth remembering

**`getAll()` versus SOQL on custom metadata.** SOQL is subject to the running
user's access and the Experience Cloud **guest** user has none on
`NM_Occupation_Supplement__mdt`, so every coded lookup failed for real visitors
while working perfectly as an admin. `getAll()` bypasses that. Test as guest.

**Anchor edits on text unique to the target.** `NM_Skills_Translation` and
`NM_Job_Matching` open with nearly identical lines; a slice anchored on the
shared text deleted a subagent boundary. Check the subagent count before
publishing.

## The agent invented salaries, and how that was actually stopped

The most serious defect found in this project, and it read perfectly.

Asked what five widened roles paid, the agent produced Warehouse Operations
Manager at **$98,560** when the stored figure is **$102,010**, Supply Chain
Analyst at **$67,190** against a real **$80,880**, Inventory Control Manager at
**$65,190** against **$57,770**. Every figure in the reply was fabricated,
formatted immaculately, attributed to BLS, with plausible ranges.

`get_wages` returns finished lines and the agent was told to present them
verbatim. It rewrote them and generated its own BLS-looking numbers instead.
**Strengthening that instruction made it worse.**

Every check passed it. `broad_run` asked "is there a `$` and a source". The
outcome grader scored the conversation 8/10. Nothing compared a figure to the
database, so nothing could catch it.

### Two things fixed it

**`NM_AgentController.applyWageNet`.** Every figure in a reply is checked
against `NM_Wage__c`. A reply containing a number we do not hold is REBUILT from
stored data, not patched. If the roles cannot be identified it refuses to quote
a figure at all. Wrapped in try/catch: a net that breaks the conversation is
worse than no net.

**`scripts/wage_truth.py`.** Asserts every dollar figure the agent prints exists
in the database, across seven conversations covering both matching paths. Run it
after any change touching pay.

### The guest access trap underneath it

The net silently did nothing at first, because **the guest user could see zero
`NM_Wage__c` and zero `NM_Occupation__c` records** while an admin saw everything.
Object permissions were granted and correct. `without sharing` did not help.

`ExternalSharingModel` is **Private** on those objects and secure guest user
access enforces it, so guest record access needs a **`SharingGuestRule`**, not a
`sharingCriteriaRule`, and `sharedTo/guestUser` wants the guest user's
**CommunityNickname** (`Next_Mission`), not the site name. After that: 968 wage
rows and 1,060 titles visible to guests.

Diagnosing this by reasoning failed three times. What worked was a temporary
`@AuraEnabled` method returning what the guest could actually count, called from
the live site. **When guest behaviour is in question, measure from the guest
context; an admin-run script cannot reproduce it.**

Also removed: `NM_Conversation_Turn__e` in the guest permission set, a platform
event that exists in neither the repo nor the org and had been failing every
permission set deploy.

## Resume handling is its own subagent (NM_Resume)

It was implemented as instructions scattered across the router, Describe
Background and Skills Translation, so nothing about it appeared in the Agent
Explorer and `NM_Skills_Translation` held two contradictory rules: *"output ONLY
the labelled sections, no preamble"* against *"keep it short, three or four
sentences."*

`NM_Resume` now owns all three cases: reading an upload, rewriting into civilian
language, and emitting the strict labelled block the widget turns into a Word
document. The no-invention rule lives with them rather than competing with
brevity rules written for chat replies.

## Browser testing is not optional (2026-09-02, late)

Everything below passed every API-level check and was broken for a real visitor.
An admin-run script cannot see any of it.

**The router hijacked to mentor.** "Can you help me with my resume?" returned a
mentor introduction. Two causes: a stale duplicate rule still sent resume help
to skills translation, and the mentor-precedence rule treated the agent's OWN
offer as an open request, so any next message was captured. An offer is not a
request; only the message immediately after can be an acceptance.

**pdf.js cannot work on this site, at all.** Its worker must load from a static
resource and Lightning Web Security blocks that outright ("Cannot request
disallowed endpoint"). Without a worker it parses on the main thread and never
resolves, so an upload sat on the typing indicator forever with no error.
Replaced with a dependency-free extractor: find the stream objects, inflate with
`DecompressionStream`, read the text out of the Tj/TJ operators. That works.

Three traps inside that, each of which looked like a different bug:
* `new Response(stream).arrayBuffer()` is treated as a fetch and blocked. Read
  the DecompressionStream with a reader instead.
* The bytes before `endstream` are an EOL belonging to the syntax. Leaving them
  on makes the inflater throw away a stream it had already decoded.
* The writer rejects independently of the reader, so an unhandled rejection
  surfaces as a page error even when the failure is handled.

**Replies arrive with newlines stripped.** A labelled block comes back as one
line, so any parser that splits on `\n` finds the first field and silently
produces nothing. Split on the labels instead. An API test that counted
`BULLET:` occurrences passed the whole time.

**Repeated surgical edits corrupted the widget.** Successive anchored inserts
left duplicate copies of seven methods, a dedup pass then removed the wrong
`_appendMessage`, and a comment containing `T*/ET` closed its own block early and
failed the deploy, leaving a broken widget live. Restore from the last good
commit and apply one clean change instead of patching a patch.

### Still not working: the resume DOWNLOAD

Reading a resume and rewriting it both work. Turning that into a file does not.
The button is hidden behind `_resumeDownloadReady = false` rather than shipped
broken. Ruled out: the parse (unit-tested against a newline-stripped reply), the
agent's format (correct via API), and a detached anchor (moved into the
component's own template). The remaining suspect is the blob download itself
under LWS. If it is picked up again, the sound design is an Apex action with
typed inputs plus an @AuraEnabled read, not a text format parsed by regex.

