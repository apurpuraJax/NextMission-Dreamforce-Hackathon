# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Deploy blocked 4× by backup check; manual deploy needed to proceed

**Done this session**
- Identified root cause: backup check blocks new permission set deploys and consumes approvals

**Open items**
- Manual deploy of NM_Agent_Service_User.permissionset-meta.xml from session repo copy
- Assign permission set to nm.agent@nextmission.jaxnonprofitpde.com after manual deploy
- Verify user holds AgentforceServiceAgentUser licence
- Report backup check issue to Revecast (blocks new permission sets, consumes approvals)

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Proceed with manual deploy outside approval gate to break blocking cycle

**Blockers**
- Orchestrate backup check blocks deploy of new permission sets and consumes approval on each retry

**Next**
- Run manual deploy: sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed
- Report to Revecast: backup check needs exemption or fix for new permission set deploys

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
The command didn't run, so the org is unchanged. This is the fourth time it has stopped the same way.

1. Orchestrate's permission-backup check blocked the deploy before it started.
2. I saved the backup to the folder it named. `NM_Agent_Service_User` still doesn't exist in the org (count 0), so there's nothing to restore.
3. On the retry the backup check let it through, but the approval gate said your approval had already been used by the blocked attempt. It has put the same command back in the dialog.

The command deploys the `NM_Agent_Service_User` permission set, assigns it to `nm.agent@nextmission.jaxnonprofitpde.com` and checks that the user holds AgentforceServiceAgentUser. That assignment is the test of whether this org can run the agent.

Each block uses up an approval and each new attempt asks for a new backup folder, so approving again may just repeat this. The quickest way out is to deploy that one file yourself from your copy of the repo:

`sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed`

The file isn't on GitHub yet. It was never committed, so it only exists in

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
