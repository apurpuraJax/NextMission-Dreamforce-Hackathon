# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Deploy blocked 10× by backup check — manual deploy required to proceed

**Done this session**
- None

**Open items**
- Manual deploy of NM_Agent_Service_User.permissionset-meta.xml from session repo copy
- Assign permission set to nm.agent@nextmission.jaxnonprofitpde.com after manual deploy
- Verify user holds AgentforceServiceAgentUser licence
- Report backup check issue to Revecast (blocks new permission sets, consumes approvals)
- Commit NM_Agent_Service_User.permissionset-meta.xml to feature/NMDH-org-migration or save locally

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Proceed with manual deploy outside approval gate to break blocking cycle

**Blockers**
- Orchestrate backup check blocks deploy of new permission sets and consumes approval on each retry (10 cycles now)

**Next**
- Save NM_Agent_Service_User.permissionset-meta.xml locally or commit to feature/NMDH-org-migration
- Run manual deploy: sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed
- Report to Revecast: backup check needs exemption or fix for new permission set deploys
- Confirm deploy complete, then continue with permission set assignment and licence verification

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
The command didn't run and the org is unchanged. It stopped the same way for the tenth time. The backup check blocked the first attempt, so I saved the backup it asked for. `NM_Agent_Service_User` still isn't in the org (count 0), so there's nothing to restore. Then the retry was held because the blocked attempt had already used up your approval.

The command in the dialog would deploy `NM_Agent_Service_User`, assign it to `nm.agent@nextmission.jaxnonprofitpde.com`, and check that the user now has AgentforceServiceAgentUser. That assignment is the test of whether this org can run the agent.

Approving again will almost certainly go round the same loop. The way out is to deploy the file yourself with `sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed`, then tell me to continue. I'll do the assignment and check it in the org. The file only exists in this session's copy of the repo, so I can paste it here or commit it to `feature/NMDH-org-migration` for you to pull. The backup check blocking new permission sets and using up an approval each time is a defect worth reporting to Reve

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
