# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** at risk — Deploy split to unblock: awaiting approval to run metadata without permission set, then Apex, then permission set

**Done this session**
- Prepared revised deploy excluding NM_Admin_Data_Access permission set

**Open items**
- Approve revised deploy: Next Mission objects, metadata, labels, remotes, credentials, tabs WITHOUT permission set
- Verify objects deployed to jaxnonprofitpde-dev-ed after approval
- Deploy NM_AgentController and other Apex classes in separate deploy
- Deploy NM_Admin_Data_Access permission set after Apex classes exist
- Confirm Test Agentforce Service Agent location (Public Sector vs Nonprofit org)
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user in Nonprofit org
- Verify licence acceptance on user in Nonprofit org
- Commit NM_Agent_Service_User to feature/NMDH-org-migration

**Decisions**
- Permission set grants only AgentforceServiceAgentUser on Agentforce Service Agent User licence
- Deploy outside approval gate to break blocking cycle
- Truncate description to 210 characters to comply with Salesforce 255-char limit
- Switch deployment target from Public Sector org to Nonprofit org
- Batch remaining deploys to minimize approval rounds
- Split deploy sequence: metadata first (without permission set), then Apex, then permission set

**Blockers**
- NM_Admin_Data_Access permission set references Apex classes not yet in org — awaiting approval to deploy metadata separately

**Next**
- Approve rerun of deploy without NM_Admin_Data_Access permission set to jaxnonprofitpde-dev-ed
- Verify objects deployed after approval
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
I stopped because Orchestrate requires your approval for every deploy and every record change in `jaxnonprofitpde-dev-ed`. The runtime treats it as a production org, and telling me not to ask doesn't lift that. The rerun is now in the dialog: the same deploy as before (objects, custom metadata, labels, remote sites, credentials and tabs), minus the `NM_Admin_Data_Access` permission set that caused the rollback.

Once you approve it, I'll check the objects exist in the org. Then I'll fold the Apex, the permission set and as much else as I can into the next deploy, so you get as few approval prompts as possible.
<!-- orchestrate:session-state:end -->
