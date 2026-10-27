# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** on track — Agent user permission set assigned successfully. Next: grant builder permissions to your user, then start Step 2 migration.

**Done this session**
- Assigned NM_Agent_Service_User permission set to nm.agent@nextmission.jaxnonprofitpde.com
- Verified AgentforceServiceAgentUser permission active on agent user
- Confirmed Agentforce Service Agent User licence auto-assigned without error

**Open items**
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to your user
- Verify builder/admin permissions accepted on your user licence
- Commit NM_Agent_Service_User permission set file to feature/NMDH-org-migration branch
- Report backup check issue to Revecast (consumed 11 approvals before fix)

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Deploy outside approval gate to break blocking cycle
- Truncate description to 210 characters to comply with Salesforce 255-char limit

**Blockers**
- None

**Next**
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to your user and check licence acceptance
- Commit NM_Agent_Service_User to feature/NMDH-org-migration
- Start Step 2 migration once your permissions verified

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
Salesforce accepted the assignment, so this org can grant the agent user the service-agent permission. That's the step that failed with the licence error in the Public Sector org.

**What the command did:**
- **Assignment:** the first line didn't print a result. `jq` failed with "Invalid numeric literal", most likely because the CLI printed a warning in front of its JSON. So I don't have the new assignment's record Id. The next two read-backs show the assignment was made.
- **Permission sets on `nm.agent@nextmission.jaxnonprofitpde.com`:** `NM_Agent_Service_User` is now assigned, with AgentforceServiceAgentUser set to **true**. The other entry, `X00eWs000006fkQ4IAI`, is the permission set that comes with the user's profile. It doesn't grant that permission.
- **Permission set licences on the user:** **Agentforce Service Agent User**. Salesforce added this licence automatically when it took the assignment, and it didn't raise a licence error.

**Not covered yet:** this only tests one of the four permissions, AgentforceServiceAgentUser on the agent user. Your Step 1 also needs ManageAgentforceServiceAgent, EinsteinCopilotBuilder and SetupAgentBuilder on your own user. I haven't teste

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
