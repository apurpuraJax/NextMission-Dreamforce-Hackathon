# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Diagnostic probe failed silently; revised probe ready for approval to identify 404 root cause

**Done this session**
- Executed initial diagnostic Apex probe
- Identified probe design flaw: AuraHandledException masks error details
- Designed corrected probe: raw HTTP status/body via callout:NM_AgentAPI, no exception filtering

**Open items**
- Approve and run corrected diagnostic Apex to capture raw Agent API 404 response
- Analyze error body to confirm root cause: missing API connection vs endpoint/payload issue
- User adds NM NextMission ECA as API connection to NM NextMission V2 agent in Agentforce Studio (if confirmed)
- Test conversation via public site chat endpoint after connection added
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
- Use diagnostic Apex to inspect full error response before manual remediation

**Blockers**
- Awaiting approval to run corrected diagnostic Apex that prints raw Agent API HTTP response

**Next**
- Approve corrected diagnostic Apex execution
- Analyze returned HTTP status and response body to confirm root cause
- Proceed with ECA-to-agent connection in Agentforce Studio or fix identified issue

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
I ran your approved probe once, unchanged. It printed nothing at all, not even the `NMPROBE DOMAIN` line, which doesn't depend on the agent call. So the script failed before its first output, or its log never came back. The command's `grep` threw away whatever error the CLI returned, so the 404 cause is still unknown. Nothing in the org changed.

There was also a flaw in the probe: `NM_AgentController` throws an `AuraHandledException`, and that exception's `getMessage()` usually returns only "Script-thrown exception". Even a clean run would have hidden the error body.

The command waiting for your approval runs a corrected probe. It makes the same Agent API session call that `startSession` makes, through `callout:NM_AgentAPI`, and prints the raw HTTP status and response body. It also shows any compile or run error instead of filtering it out, and it doesn't write any records. If you approve it, the output should tell us whether the 404 comes from the missing API connection or from the endpoint or payload.
<!-- orchestrate:session-state:end -->
