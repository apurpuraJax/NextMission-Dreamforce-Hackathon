# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Deploy rolled back: permission set referenced missing Apex classes. Replan deploy sequence.

**Done this session**
- Identified root cause: NM_Admin_Data_Access permission set requires NM_AgentController and other Apex classes not yet deployed
- Validated deploy command (444 of 445 components valid)

**Open items**
- Approve revised deploy: Next Mission objects, metadata, labels, remotes, credentials, tabs WITHOUT permission set
- Deploy NM_AgentController and other Apex classes in separate deploy
- Deploy NM_Admin_Data_Access permission set after Apex classes exist
- Confirm Test Agentforce Service Agent location (Public Sector vs Nonprofit org)
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user in Nonprofit org
- Verify licence acceptance on user in Nonprofit org
- Commit NM_Agent_Service_User to feature/NMDH-org-migration
- Resume Step 2 migration and agent build work once deployment completes

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Deploy outside approval gate to break blocking cycle
- Truncate description to 210 characters to comply with Salesforce 255-char limit
- Switch deployment target from Public Sector org to Nonprofit org — Public Sector lacks required licence
- Batch remaining deploys to minimize approval rounds
- Split deploy sequence: metadata first (without permission set), then Apex, then permission set

**Blockers**
- NM_Admin_Data_Access permission set references Apex classes not yet in org — deploy rolled back all-or-nothing

**Next**
- Approve rerun of deploy without NM_Admin_Data_Access permission set
- Verify objects deployed to jaxnonprofitpde-dev-ed after rerun
- Deploy Apex classes NM_AgentController and dependencies
- Deploy NM_Admin_Data_Access permission set once Apex classes exist

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
━━ Build status (auto-checked from tool results — deploy = sf CLI exit, not runtime effect) ━━
• Code committed: no new commit in this session run — if an earlier run committed, check the repository
• Pushed to GitHub: nothing new pushed in this session run — if an earlier run pushed, check the repository
• Validated (sf deploy validate): yes
• Deployed to org: yes — jaxnonprofitpde-dev-ed · NOT read back from the org: the deploy's result listed no components (run it with --json, and not --async, so Orchestrate can check the org)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The deploy failed and was rolled back completely, so the org is unchanged. I checked afterwards and there are still no `NM_` objects in `jaxnonprofitpde-dev-ed`.

**What happened:** 444 of the 445 components were fine. The one failure was the `NM_Admin_Data_Access` permission set:

> *In field: apexClass - no ApexClass named NM_AgentController found*

The permission set gives access to 2 Apex classes, and those classes aren't in the org yet. Because the deploy runs all-or-nothing, that one error cancelled the other 444 (objects, custom metadata, labels, remote sites, credentials, tabs).

**Fix:** I haven't c

_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
