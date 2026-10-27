# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Permission set deploy blocked by backup check 5 times; recommend creating empty shell first

**Done this session**
- Identified root cause: backup check fails when permission set doesn't exist in org yet
- Confirmed org query works and NM_Admin_Data_Access count remains 0
- Saved backup again; approval gate consumed on blocked attempt

**Open items**
- Create NM_Admin_Data_Access shell in Setup (API name only, no licence) to unblock backup check
- Deploy NM_Admin_Data_Access.permissionset-meta.xml stage-1 (45 field, 7 object, 3 tab grants)
- Re-run Apex validation after permission set assigned
- Deploy Apex classes NM_AgentController and dependencies
- Confirm Test Agentforce Service Agent location (Public Sector vs Nonprofit org)
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user
- Verify licence acceptance on user in Nonprofit org
- Commit NM_Agent_Service_User to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder (precedent: NM_Agent_Service_User)
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed), not Public Sector
- Decline current dialog command; create empty permission set shell first instead

**Blockers**
- Backup check cannot query non-existent permission set; blocks every deploy attempt in approval loop

**Next**
- Create empty NM_Admin_Data_Access permission set shell in Nonprofit org Setup (one-time, no approval needed)
- Decline current dialog command
- Resubmit stage-1 deploy command after shell exists

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
The command still didn't run, so `jaxnonprofitpde-dev-ed` is unchanged. This is the fifth time it has stopped in the same loop, and I don't think approving it again will break the loop.

**What happened:** the permission-backup check blocked the deploy before it started. It said it "could not ask the org which profiles and permission sets exist". The org itself answers fine: my query came back normally and showed `NM_Admin_Data_Access` still isn't there (count 0). I saved the backup it asked for and retried once. The approval gate then said the blocked attempt had already used up your approval, and it has put the same command back in the dialog.

**Why it keeps looping:** each time, the backup check blocks the first run with a new backup folder, and that blocked run uses up your approval. The retry then needs a fresh approval, and that fresh approval runs into the backup check again. My guess is that the check fails because this permission set doesn't exist in the org yet, so it has nothing to look up. If that's right, the check will block any brand-new permission set the same way. Naming the file directly didn't change anything, so that earlier theory was wrong.

**A way out:** cr

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
