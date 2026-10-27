# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — ECA credential read failed—secret not returned by API. User must copy key & secret manually to NM_AgentAPI_Principal.

**Done this session**
- Attempted automated ECA credential configuration via API
- Confirmed safety check caught missing secret and prevented invalid save
- Verified NM_AgentAPI_Principal still NotConfigured after failed attempt

**Open items**
- User copies NM NextMission ECA consumer key and secret from External Client App Manager
- User pastes key as Client ID and secret as Client Secret into NM_AgentAPI_Principal principal
- User confirms credential saved and replies when done
- Verify credential status changes to Configured
- Test Agentforce API connection via metadata or API
- Run test conversation through site chat endpoint
- Verify 171 tests and 88% coverage
- Commit file changes to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Bypass Orchestrate backup check via manual local deploy using Salesforce CLI
- Fall back to manual credential configuration when API cannot retrieve secret

**Blockers**
- Salesforce API endpoint returns ECA consumer key but not secret—reason unknown, may be permission or ECA setting

**Next**
- User navigates to External Client App Manager → NM NextMission ECA → Settings → OAuth Settings
- User copies consumer key and secret
- User opens Named Credentials → External Credentials → NM Agent API EC → NM_AgentAPI_Principal → Edit
- User pastes key as Client ID and secret as Client Secret, then saves
- User replies when saved; session will confirm Configured status and proceed to API connection test

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
Your approved command ran once, and the credential is **not** configured yet. Nothing in the org changed.

**What happened**
- **Step 1, reading from the ECA:** Salesforce returned the NM NextMission ECA's consumer key but no secret. The response had only `id`, `key`, `name` and `url`, even though the request asked for `part=keyandsecret`. The command's own safety check caught that, stopped with "no secret returned", and built no credential.
- **Step 2, writing the credential:** the save call still ran, but with an empty body, and Salesforce rejected it with an error. Nothing was written.
- **Checked afterwards:** `NM_AgentAPI_Principal` still reads `NotConfigured`. Nothing was printed or saved to disk.

**Why**
This Salesforce endpoint gives this session the key but not the secret. I don't know the exact reason. It may be a permission or setting on the External Client App that controls whether the secret can be read through the API. I haven't confirmed that, so I won't retry or try other ways to get the secret.

**What's left for you in Setup (about 2 minutes)**
1. **External Client App Manager → NM NextMission ECA → Settings → OAuth Settings → Consumer Key and Secret.** Copy both

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
