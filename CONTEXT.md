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
