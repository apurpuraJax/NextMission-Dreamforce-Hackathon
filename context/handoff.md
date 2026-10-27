# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Deploy blocked 11× by backup check — manual deploy required to proceed

**Done this session**
- None

**Open items**
- Manual deploy of NM_Agent_Service_User.permissionset-meta.xml from session repo copy
- Assign permission set to nm.agent@nextmission.jaxnonprofitpde.com after manual deploy
- Verify user holds AgentforceServiceAgentUser licence
- Report backup check issue to Revecast (blocks new permission sets, consumes approvals)
- Commit NM_Agent_Service_User.permissionset-meta.xml to feature/NMDH-org-migration or paste contents

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Proceed with manual deploy outside approval gate to break blocking cycle

**Blockers**
- Orchestrate backup check blocks deploy of new permission sets and consumes approval on each retry (11 cycles now)

**Next**
- Choose: paste NM_Agent_Service_User.permissionset-meta.xml contents here OR commit to feature/NMDH-org-migration
- Run manual deploy: sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed
- Report to Revecast: backup check needs exemption or fix for new permission set deploys
- Say 'continue' when deploy completes to proceed with assignment and licence verification

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
The command didn't run, so the org is unchanged. This is the eleventh time it has stopped the same way. Orchestrate's permission-backup check blocked the deploy before it started, and the error said it "could not ask the org which profiles and permission sets exist."

I saved the backup it asked for in a new folder. `NM_Agent_Service_User` still isn't in the org (count 0), so there's nothing to restore. I didn't retry, because each of the last ten retries was held for a new approval.

**Approving again won't fix this.** The check asks for a backup in a new folder on every attempt, and each blocked attempt uses up your approval. The only way through is to deploy the file outside Orchestrate:

`sf project deploy start --source-dir force-app/main/default/permissionsets/NM_Agent_Service_User.permissionset-meta.xml --target-org jaxnonprofitpde-dev-ed`

The file only exists in this session's copy of the repo; it isn't on GitHub. It grants just AgentforceServiceAgentUser, on the Agentforce Service Agent User licence. Tell me which you'd like:
- **Paste it here:** I paste the file contents so you can save and deploy it.
- **Commit it:** I commit it to `feature/NMDH-org-migration` so you ca

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
