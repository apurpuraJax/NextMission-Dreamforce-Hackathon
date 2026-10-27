# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Empty shell permission set ready to deploy; unblocks backup check loop. Approval needed to proceed.

**Done this session**
- Prepared empty NM_Admin_Data_Access shell command (label, no licence, no permissions)
- Confirmed shell will be read back to satisfy backup check

**Open items**
- Approve and deploy empty NM_Admin_Data_Access shell in Nonprofit org
- Verify shell exists in org after deploy
- Deploy NM_Admin_Data_Access.permissionset-meta.xml stage-1 (45 field, 7 object, 3 tab grants)
- Re-run Apex validation after permission set assigned
- Deploy Apex classes NM_AgentController and dependencies
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user
- Verify licence acceptance on user in Nonprofit org
- Commit NM_Agent_Service_User to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Create empty shell first to unblock backup check before stage-1 deploy

**Blockers**
- Backup check cannot query non-existent permission set — shell deploy will resolve this

**Next**
- Approve empty NM_Admin_Data_Access shell deploy command
- Confirm shell created and readable in org
- Resubmit stage-1 permission set deploy (45 field, 7 object, 3 tab grants)

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
I've confirmed `NM_Admin_Data_Access` still isn't in the org (count 0). The command now in the dialog creates it as an empty permission set, with the label "NM Admin Data Access", no licence and no permissions. It then reads it back, so the backup check has an existing permission set to find. Once you approve and it's verified, I'll rerun the stage-1 deploy (45 fields, 7 objects, 3 tabs) and assign it to you. Then I'll carry on with the Apex.
<!-- orchestrate:session-state:end -->
