# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — NM credential grant done; awaiting probe rerun approval. IT Service org checked—unlicensed, needs setup.

**Done this session**
- Checked jaxpubsecpde-dev-ed: IT Service objects exist but app, agent, and Knowledge not set up

**Open items**
- Approve and run diagnostic Apex probe rerun to capture Agent API HTTP status and response body
- Analyze Agent API response to confirm 404 root cause (missing ECA connection, endpoint, or payload)
- Update repo version of NM_Admin_Data_Access with NM_AgentAPI_Principal credential grant
- User adds NM NextMission ECA as API connection to NM NextMission V2 agent in Agentforce Studio (if confirmed)
- Test conversation via public site chat endpoint after connection added
- Run scripts/scenarios.py against live site to verify full flow
- Commit file changes to feature/NMDH-org-migration
- Decide: enable IT Service management features and Knowledge in jaxpubsecpde-dev-ed, then attempt agent build

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
- Decide whether to enable IT Service features in jaxpubsecpde-dev-ed and attempt agent build

**Checked live on 2026-10-27:** nothing — the status above is as recorded, not re-checked
### Last session — 2026-10-27
| | |
|---|---|
| Type | BUILD |
| Outcome | COMPLETED |
| Branch | `main` |
| Name | Deploy Next Mission |
| Session | `d3f1b5d0-67b8-403a-a331-cde40c98ac0f` |
**In its own words (excerpt):**
I checked `jaxpubsecpde-dev-ed` and changed nothing. The IT Service objects and licences are in the org, but the IT Service app, the Agentforce IT Service agent and Knowledge are not set up.

| Item | In the org? | Details |
|---|---|---|
| **IT Service app** | No | None of the org's 31 apps is an IT Service app. The closest are "Service", "Service Console" and "IT Compliance". |
| **Incident object** | Yes | `Incident` exists, along with `Problem`, `ProblemIncident` and `IncidentRelatedItem`. It has 0 records. |
| **Request object** | Yes | `ServiceRequest` exists. It has 0 records. |
| **Change object** | Yes | `ChangeRequest` exists, along with the related-item and Change Advisory Board objects. It has 0 records. |
| **Agentforce IT Service agent** | No | The only agent is `Copilot_for_Salesforce`, the default internal agent. The org has no IT Service agent topics or prompt templates. |
| **Knowledge** | No | Knowledge is switched off in the settings (`enableKnowledge` = false), and the Knowledge article object isn't available. Licences for it are here: Agentforce Knowledge User has 200 seats and Service Lightning Knowledge Manager has 1. |
| **Service Cloud licence** | Yes | Th

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
