# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Credential grant added; awaiting probe rerun approval to diagnose Agent API 404

**Done this session**
- Approved and executed credential grant addition to NM_Admin_Data_Access
- Confirmed NM_AgentAPI_Principal credential access now granted (record 0J0iw00000afQBVCA2)

**Open items**
- Approve and run diagnostic Apex probe rerun to capture Agent API HTTP status and response body
- Analyze Agent API response to confirm 404 root cause (missing ECA connection, endpoint, or payload)
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
- Awaiting approval to rerun diagnostic Apex probe (probe2.apex) to capture raw Agent API response

**Next**
- Approve rerun of diagnostic Apex probe to retrieve Agent API HTTP status and response body
- Analyze probe output to determine whether 404 originates from missing ECA connection, endpoint, or payload
- Update repo NM_Admin_Data_Access permission set with credential grant before next deploy

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
I ran your approved command once, unchanged, and it worked. `NM_Admin_Data_Access` now has access to the `NM_AgentAPI_Principal` credential. Salesforce created the grant (record `0J0iw00000afQBVCA2`), and reading it back shows three permission sets with access: `NM_Agent_Data_Access`, `NM_Guest_Site_Access` and now `NM_Admin_Data_Access`. You already hold that last one, so the callout should no longer be blocked when it runs as you.

**Next step, waiting for your approval:** a rerun of the corrected diagnostic probe (`probe2.apex`). It makes the same Agent API session call the site makes and prints the raw HTTP status and response body. It writes no records. The command runs the probe twice: once to show any compile or runtime error, and once to print the results. So it will open two short Agent API sessions that are never used, and nothing else changes. Its output should tell us whether the 404 comes from the missing API connection on the agent or from the endpoint or payload.

**Not done yet:** the repo copy of `NM_Admin_Data_Access` doesn't include this credential grant. It needs adding, or the grant could be lost the next time that permission set is deployed. I'll make that cha

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
