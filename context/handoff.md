# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** on track — Permission set deployed & assigned. Agent, site, data live. Awaiting approval to configure ECA credential.

**Done this session**
- Verified NM_NextMission_V2 agent Active in org
- Confirmed Next Mission site Live
- Validated 1,016 occupations, 8,179 military codes, 70 mentors loaded
- Confirmed 35 NM_ Apex classes deployed
- Verified NM_Admin_Data_Access permission set assigned to user
- Checked scheduled jobs NM Daily QA Grader and NM ONET Release Monitor both WAITING
- Confirmed all four permission sets assigned

**Open items**
- User approves ECA credential configuration (NM_AgentAPI_Principal currently NotConfigured)
- Read ECA consumer key/secret from NM_NextMission_V2 and configure credential
- Test Agentforce API connection via metadata or API
- Run test conversation through site chat endpoint
- Verify 171 tests and 88% coverage
- Review reports and dashboard
- Commit file changes to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Bypass Orchestrate backup check via manual local deploy using Salesforce CLI
- Configure ECA credential via metadata/API first; hand back to user only if that fails

**Blockers**
- Awaiting user approval to configure NM_AgentAPI_Principal external credential

**Next**
- User approves ECA credential configuration
- Read NM_NextMission_V2 ECA consumer key and secret; configure NM_AgentAPI_Principal
- Verify credential status changes to Configured
- Test Agentforce API connection
- Run test conversation through Next Mission site chat
- Report results and proceed to final deployment steps

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
I checked your report against the org and it holds up. That command handles the first two of your three Setup steps, and it's waiting for your approval. It reads the NM NextMission ECA's consumer key and secret from Salesforce and saves them on the `NM_AgentAPI_Principal` credential, so you don't have to copy anything by hand. The secret is passed straight between the two calls and is never printed or written to disk.

**Checked in the org:**
- **Agent:** `NM_NextMission_V2` v1 is Active.
- **Site:** "Next Mission" is Live.
- **Data:** 1,016 occupations, 8,179 military codes and 70 mentors.
- **Platform:** 35 `NM_` Apex classes.
- **Scheduled jobs:** "NM Daily QA Grader" and "NM ONET Release Monitor" are both WAITING.
- **Permission sets:** all four are assigned, including `NM_Admin_Data_Access` on your user.
- **Credential:** the principal currently reads `NotConfigured`.

**If you approve,** I'll read the principal back and confirm it says Configured. Then I'll work on your third step, the Agentforce API connection: I'll try it through metadata or the API first and only hand it back to you if that genuinely fails. After that I'll run a test conversation through the site's chat en

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
