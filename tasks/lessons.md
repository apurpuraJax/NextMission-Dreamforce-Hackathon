
## NMDH-14 (2026-08-30) — Bot shell + GenAiPlannerBundle

### GenAiPlannerFunctionDef correct structure
- `<genAiPlugins>` uses `<genAiPluginName>` (just a string reference to the GenAiPlugin developer name)
- NO `<developerName>`, NO `<sortOrder>` inside `<genAiPlugins>` — those cause "invalid at this location" errors
- Example:
  ```xml
  <genAiPlugins>
      <genAiPluginName>NM_Greeting_And_Background</genAiPluginName>
  </genAiPlugins>
  ```

### Bot agentType for ExternalCopilot public-site bots
- Use `EinsteinServiceAgent` (not `Employee`, not `AgentforceServiceAgent`)
- `Employee` passes schema validation but fails license check on hackathon orgs
- Discover valid enum values via SOAP `describeValueType` on `{http://soap.sforce.com/2006/04/metadata}Bot`

### BotVersion fullName
- Must be `<fullName>v1</fullName>` — platform auto-prepends the bot name
- `<fullName>NM_NextMission_Bot.v1</fullName>` causes "Not in package.xml" error

### ConversationVariable visibility
- Required field; valid values: `Internal` or `External`
- For public ExternalCopilot sites, use `External`

### Activation — UI only
- No Metadata API or CLI path to activate a Bot in Setup → Agents
- Must be done manually in Setup → Agents after deploy

### GenAiPlugin topic linkage — Tooling API required for surface-deployed planners
- When a Bot is configured via the UI, Salesforce auto-generates `{BotApiName}_{VersionName}` planner (e.g. `NM_NextMission_Bot_v1`) as the active planner
- Adding `<genAiPlugins>` to this planner's XML via Metadata API deploy is SILENTLY STRIPPED for surface-deployed planners (those with `<plannerSurfaces>`)
- The real linkage is `GenAiPluginDefinition.PlannerId` (Tooling API field)
- Fix: `sf data update record --sobject GenAiPluginDefinition --record-id <topicId> --values "PlannerId=<plannerDefId>" --use-tooling-api`
- `<genAiPlugins>` in XML ONLY works for planners WITHOUT `<plannerSurfaces>` (non-deployed, orphaned planners)
- Script `scripts/apex/link-topics-to-planner.sh` documents the exact commands for any org

### SOAP describeValueType — invaluable technique
- Use Node.js HTTPS direct POST to `/services/Soap/m/67.0` with SOAPAction: '""'
- Body: `describeValueType` for `{http://soap.sforce.com/2006/04/metadata}<TypeName>`
- Extracts all valid enum values and field names — use this before guessing
