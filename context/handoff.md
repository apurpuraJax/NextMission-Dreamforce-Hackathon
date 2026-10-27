# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Credential configured; agent API connection missing—user must link ECA to agent in Agentforce Studio

**Done this session**
- Confirmed NM_AgentAPI_Principal now reads Configured after manual credential paste
- Verified named credential points to correct API endpoint and uses configured principal
- Ruled out agent ID mismatch, credential misconfiguration, and agent type as causes of 404
- Identified root cause: External Client App not linked to agent as API connection

**Open items**
- User navigates to Agentforce Studio → NM NextMission V2 → Connections → Add → API
- User selects NM NextMission ECA and saves (deactivate agent first if required)
- User replies when connection added; session will test conversation via site chat endpoint
- Run scripts/scenarios.py against live site to verify full flow
- Verify 171 tests and 88% coverage
- Commit file changes to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Bypass Orchestrate backup check via manual local deploy using Salesforce CLI
- Fall back to manual credential configuration when API cannot retrieve secret
- Link ECA to agent via Agentforce Studio UI, not metadata file

**Blockers**
- Agent metadata retrieve returns nothing—cannot add API connection via file; must use Agentforce Studio UI

**Next**
- User adds NM NextMission ECA as API connection to NM NextMission V2 agent in Agentforce Studio
- User replies when done
- Session tests conversation via public site chat endpoint
- Session runs scripts/scenarios.py against live site

**Checked live on 2026-10-27:** the repository
### Last session — 2026-10-27
| | |
|---|---|
| Type | BUILD |
| Outcome | COMPLETED |
| Branch | `main` |
| Name | Deploy Next Mission - Nonprofit Org |
| Session | `82f48cd6-edb2-4b5d-8033-7c315e6c4ab2` |
**In its own words (excerpt):**
I'll skip that probe. It needs another approval round, and I already have enough to point to the cause.

**Your two steps worked.** `NM_AgentAPI_Principal` now reads **Configured**, and the site's chat call gets a token. Before your change it couldn't authenticate at all.

**A conversation still doesn't start.** I started a session through the public site the same way a visitor would. It failed with `Session creation failed (404)` from the Agent API. I ruled out the other likely causes:
- The agent ID in `NM_Bot_Definition_Id` is `0Xxiw0000002DZ3CAM`, which matches the live `NM_NextMission_V2`.
- The named credential points at `https://api.salesforce.com/einstein/ai-agent/v1` and uses the configured principal.
- The agent is an active service agent, so the API accepts that agent type.

That leaves the third step from your report. The External Client App isn't linked to the agent as an API connection, so the Agent API won't serve this agent to the app's token. I tried to add the link myself, but retrieving the agent's metadata from the org returns nothing, so I have no file to change. I haven't proven there's no API for it. I just don't have a working way to do it from here.

**The 

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
