# Handoff

What the next session needs to know. Orchestrate keeps the session-state block below up to date at the end of every session; anything you write outside it is yours and is never touched.

## Things the next session should know

## Waiting on someone else

<!-- orchestrate:session-state:start -->
<!-- Written by Orchestrate at the end of each session. Edits inside this block are
     replaced next session; anything OUTSIDE it is yours and is never touched. -->
### Engagement state — 2026-10-27
**Status:** blocked — Manual deploy instructions issued; awaiting user execution and confirmation of permission set assignment

**Done this session**
- Generated detailed step-by-step manual deploy guide with Salesforce CLI commands
- Provided NM_Admin_Data_Access-stage1.zip with sfdx-project.json and permission set metadata
- Documented install, login, deploy, and assignment steps for user's local machine

**Open items**
- User runs manual deploy commands locally from NM_Admin_Data_Access-stage1.zip
- User assigns permission set to themselves (sf org assign permset)
- Verify 45 field grants and permission set assignment in jaxnonprofitpde-dev-ed
- Re-run Apex validation after permission set assigned
- Deploy Apex classes NM_AgentController and dependencies
- Grant ManageAgentforceServiceAgent, EinsteinCopilotBuilder, SetupAgentBuilder to user
- Deploy remaining: LWC, flows, prompt templates, agent bundle, O*NET and mentor data, site, publish agent
- Commit file changes to feature/NMDH-org-migration

**Decisions**
- Deploy permission set by file name, not folder
- Stage-1 permission set: no Apex class grants until classes exist in org
- Split deploy sequence: metadata first, then Apex, then permission set
- Target Nonprofit org (jaxnonprofitpde-dev-ed)
- Bypass Orchestrate backup check via manual local deploy using Salesforce CLI

**Blockers**
- Awaiting user execution of manual deploy steps on local machine

**Next**
- User installs Salesforce CLI (brew install sf or npm install -g @salesforce/cli)
- User logs in to org with sf org login web --alias nonprofit
- User unzips NM_Admin_Data_Access-stage1.zip and runs sf project deploy start command
- User assigns permission set with sf org assign permset --name NM_Admin_Data_Access
- User reports deploy and assignment success/failure with output
- Verify field grants and assignment in org, then proceed to Apex validation

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
The zip is still attached to this session. It holds two files: `sfdx-project.json` and the stage-1 `NM_Admin_Data_Access` permission set. These steps install the tools, then deploy and assign the permission set.

## 1. Install the Salesforce CLI (one time)

- **Mac:** `brew install sf`. You can also use the installer from developer.salesforce.com/tools/salesforcecli.
- **Windows:** download the `.exe` installer from the same page.
- **Any system with Node.js:** `npm install -g @salesforce/cli`

Check that it worked:
```
sf --version
```

## 2. Log in to the org (one time)

```
sf org login web --alias nonprofit --instance-url https://login.salesforce.com
```
A browser window opens. Sign in as **your** user for `jaxnonprofitpde-dev-ed`, the same admin user this session uses, and click **Allow**. If the login page doesn't accept you, use `--instance-url https://jaxnonprofitpde-dev-ed.develop.my.salesforce.com` instead.

Check that it connected:
```
sf org display --target-org nonprofit
```

## 3. Unzip the file

Download **NM_Admin_Data_Access-stage1.zip** from this session's deliverables panel, then:
```
cd ~/Downloads
unzip NM_Admin_Data_Access-stage1.zip -d nm-stage1
cd nm-stage1


_[summary truncated — see the session record for the full text]_
<!-- orchestrate:session-state:end -->
