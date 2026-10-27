# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Deploy blocked 6× by backup check; manual deploy needed to proceed

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
- Orchestrate backup check blocks deploy of new permission sets and consumes approval on each retry (6 cycles now)

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
Nothing ran, so the org is unchanged. This is the sixth time it has stopped the same way. First, Orchestrate's permission-backup check blocked the deploy before it started. I then saved the backup it asked for: `NM_Agent_Service_User` still isn't in the org (count 0), so there's nothing to restore. On the retry, the approval gate said your approval had already been used by the blocked attempt, and it has put the same command back in the dialog.

The command deploys the `NM_Agent_Service_User` permission set, assigns it to the agent user `nm.agent@nextmission.jaxnonprofitpde.com` and checks that the user now holds AgentforceServiceAgentUser. That assignment is the test of whether this org can run the agent.

Approving again will almost certainly repeat this loop. To get past it, deploy the file yourself from a local copy of the repo:

`sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed`

The file only exists in this session's copy of the repo; it isn't on GitHub. I can paste its contents here so you can save it, or commit it to `feature/NMDH-org-migration` so you can pull it. Onc

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
