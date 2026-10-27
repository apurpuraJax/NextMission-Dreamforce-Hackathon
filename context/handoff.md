# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Stage-1 permission set deploy blocked by Orchestrate backup check; manual local deploy required

**Done this session**
- Confirmed NM_Admin_Data_Access exists in org (Id 0PSiw000001Jl4HGAS) and org responds to queries normally
- Identified root cause: Orchestrate's permission-backup check cannot read org profiles/permission sets, not an org or permission set issue
- Saved backup exports (empty field/object/setup-access, metadata retrieve succeeded)
- Generated stage-1 deploy file (NM_Admin_Data_Access-stage1.zip) with manual deploy commands

**Open items**
- Run manual deploy commands locally from NM_Admin_Data_Access-stage1.zip (sf project deploy start + sf org assign permset)
- Verify 45 field grants and permission set assignment in jaxnonprofitpde-dev-ed after manual deploy
- Re-run Apex validation after permission set assigned
- Deploy Apex classes NM_AgentController and dependencies
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user
- Verify licence acceptance on user in Nonprofit org
- Deploy remaining: LWC, flows, prompt templates, agent bundle, O*NET and mentor data, site, publish agent, schedule NM_ONETReleaseMonitor, test conversation
- Commit file changes to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Bypass Orchestrate backup check via manual local deploy using Salesforce CLI

**Blockers**
- Orchestrate's permission-backup check cannot query org profiles/permission sets—root cause unknown, suspected Orchestrate infrastructure issue

**Next**
- Run manual deploy commands locally from attached NM_Admin_Data_Access-stage1.zip
- Report back with deploy success/failure and assignment confirmation
- Once confirmed, proceed with Apex class deploy and permission assignment validation

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
The command didn't run, and nothing in `jaxnonprofitpde-dev-ed` has changed. Orchestrate's permission-backup check stopped the deploy before it reached Salesforce. It gave the same reason as before: it "could not ask the org which profiles and permission sets exist".

**What this tells us**
- `NM_Admin_Data_Access` now exists in the org (Id `0PSiw000001Jl4HGAS`), and the org answers my queries normally. The check still fails, so the problem is in Orchestrate's check, not in your org or the permission set. My earlier guess (that it failed because the permission set didn't exist yet) was wrong.
- I saved the backup the check asked for. It has the field, object and setup-access exports (0 rows each, because the shell is empty) and a metadata retrieve. The deploy only adds access, so there's nothing in the org it could remove.
- I'm not retrying. Each block uses up your approval, so another retry would put you back in the same loop.

**Run it from your own machine**
The stage-1 file is attached to this session as **NM_Admin_Data_Access-stage1.zip**. It grants 45 fields, 7 objects and 3 tabs, with no Apex class grants. Unzip it and run this from inside the unzipped folder:

```
sf proje

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
