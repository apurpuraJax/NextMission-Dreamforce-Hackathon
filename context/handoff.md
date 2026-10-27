# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Diagnostic probe blocked by credential access; adding grant to NM_Admin_Data_Access for rerun approval

**Done this session**
- Ran corrected diagnostic Apex probe
- Identified root cause of probe failure: user lacks credential access via permission set
- Confirmed agent ID 0Xxiw0000002DZ3CAM and org domain are correct
- Designed fix: grant NM_AgentAPI_Principal credential access to NM_Admin_Data_Access

**Open items**
- Approve and run credential grant addition to NM_Admin_Data_Access permission set
- Rerun diagnostic Apex probe after credential grant is in place
- Analyze Agent API HTTP status and response body to confirm 404 root cause
- Update repo version of NM_Admin_Data_Access with NM_AgentAPI_Principal credential grant
- User adds NM NextMission ECA as API connection to NM NextMission V2 agent in Agentforce Studio (if confirmed)
- Test conversation via public site chat endpoint after connection added
- Run scripts/scenarios.py against live site to verify full flow
- Commit file changes to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Bypass Orchestrate backup check via manual local deploy using Salesforce CLI
- Fall back to manual credential configuration when API cannot retrieve secret
- Link ECA to agent via Agentforce Studio UI, not metadata file
- Use diagnostic Apex to inspect full error response before manual remediation

**Blockers**
- Awaiting approval to add NM_AgentAPI_Principal credential grant to NM_Admin_Data_Access and rerun probe

**Next**
- Approve credential grant addition to NM_Admin_Data_Access
- Rerun diagnostic Apex probe to capture raw Agent API HTTP status and response body
- Analyze returned error to confirm whether 404 is from missing ECA connection, endpoint, or payload

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
I ran your approved probe once and it worked, but it didn't reach the Agent API, so we still don't know what's causing the 404. Salesforce blocked the callout before it was sent: `System.CalloutException: We couldn't access the credential(s)… "NM_AgentAPI_EC"`. That's because the probe runs as you, and your user can't use the credential. Only `NM_Guest_Site_Access` and `NM_Agent_Data_Access` grant that access, and you don't hold either. The probe did confirm the agent ID `0Xxiw0000002DZ3CAM` and the org domain. Nothing in the org changed.

The command now waiting for your approval adds one record. It gives `NM_Admin_Data_Access`, which you already hold, access to the `NM_AgentAPI_Principal` credential, then reads the grant back. Once that's in, I can rerun the same probe unchanged and get the real Agent API status and error body. The repo version of `NM_Admin_Data_Access` should also get this grant so the change isn't lost on the next deploy.

Sources: checked live: jaxnonprofitpde-dev-ed (probe output, which permission sets grant the credential, your permission set assignments) · not checked: the Agent API response itself
<!-- orchestrate:session-state:end -->
