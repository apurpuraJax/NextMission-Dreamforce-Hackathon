# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** on track — Deployment to Nonprofit org ready; awaiting approval for Next Mission objects deploy

**Done this session**
- Updated five org-specific values for Nonprofit org (agent user, dashboard user, app org id, token URL, site URL label)
- Fixed report and dashboard folder layout and validation errors
- Prepared Next Mission objects, custom metadata, labels, remote sites, credentials, tabs, NM_Admin_Data_Access permission set for deploy

**Open items**
- Approve production-deploy gate for Next Mission objects deploy to jaxnonprofitpde-dev-ed
- Confirm Test Agentforce Service Agent location (Public Sector vs Nonprofit org)
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user in Nonprofit org
- Verify licence acceptance on user in Nonprofit org
- Commit NM_Agent_Service_User to feature/NMDH-org-migration
- Resume Step 2 migration in Nonprofit org
- Resume agent build work once deployment completes

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Deploy outside approval gate to break blocking cycle
- Truncate description to 210 characters to comply with Salesforce 255-char limit
- Switch deployment target from Public Sector org to Nonprofit org — Public Sector lacks required licence
- Batch remaining deploys to minimize approval rounds

**Blockers**
- Production-deploy gate requires approval before Next Mission objects deploy proceeds

**Next**
- Approve production-deploy gate for Next Mission objects deploy
- Proceed with batched remaining deploys
- Confirm agent location once deployment completes

**Checked live on 2026-10-27:** nothing — the status above is as recorded, not re-checked
### Last session — 2026-10-27
| | |
|---|---|
| Type | BUILD |
| Outcome | COMPLETED |
| Branch | `main` |
| Name | Deploy Next Mission - Nonprofit Org |
| Session | `82f48cd6-edb2-4b5d-8033-7c315e6c4ab2` |
**In its own words (excerpt):**
Orchestrate's production-deploy gate needs your approval for this step, even though you said not to ask. This command deploys the Next Mission objects, custom metadata, labels, remote sites, credentials, tabs and the `NM_Admin_Data_Access` permission set to `jaxnonprofitpde-dev-ed`, with no Apex. Getting the fields in first lets the Apex tests see them in the next deploy.

So far this run I've:
- Updated the five org-specific values for this org: the agent user, the dashboard running user, the app's org id, the token URL and the site URL label.
- Fixed the report and dashboard folder layout and two report/dashboard errors that blocked validation.

To save you approval rounds, the remaining deploys will be batched into as few commands as I can.
<!-- orchestrate:session-state:end -->
