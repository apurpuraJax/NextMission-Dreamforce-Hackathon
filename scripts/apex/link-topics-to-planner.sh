#!/bin/bash
# link-topics-to-planner.sh
#
# PURPOSE: Wire the 4 NM Next Mission GenAiPlugin (topic) definitions to the
#          active GenAiPlannerDefinition for this bot.
#
# BACKGROUND: Salesforce auto-generates a GenAiPlannerBundle named
#   {BotApiName}_{VersionName} when a bot is configured via UI. This becomes
#   the active planner. Adding <genAiPlugins> to this planner via Metadata API
#   is silently stripped for surface-deployed planners. The real linkage is
#   stored in GenAiPluginDefinition.PlannerId (Tooling API).
#
# WHEN TO RUN: After deploying the bot to a fresh org, or if topics stop
#   appearing in Agentforce Studio Builder.
#
# PREREQUISITES:
#   sf CLI authenticated to the target org
#   Set TARGET_ORG below to the sf CLI alias for your org.

TARGET_ORG="${1:-dreamforce-hackathon}"

echo "Linking topics to NM_NextMission_Bot_v1 planner in org: $TARGET_ORG"
echo ""

# Get the active planner ID (NM_NextMission_Bot_v1)
PLANNER_ID=$(sf data query \
  --query "SELECT Id FROM GenAiPlannerDefinition WHERE DeveloperName = 'NM_NextMission_Bot_v1'" \
  --target-org "$TARGET_ORG" --use-tooling-api --json 2>/dev/null \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['result']['records'][0]['Id'])")

if [ -z "$PLANNER_ID" ]; then
  echo "ERROR: Could not find GenAiPlannerDefinition NM_NextMission_Bot_v1 in org $TARGET_ORG"
  exit 1
fi

echo "Active planner ID: $PLANNER_ID"
echo ""

# Get the 4 topic IDs
echo "Fetching GenAiPluginDefinition IDs..."
TOPICS_JSON=$(sf data query \
  --query "SELECT Id, DeveloperName FROM GenAiPluginDefinition ORDER BY DeveloperName" \
  --target-org "$TARGET_ORG" --use-tooling-api --json 2>/dev/null)

# Wire each topic to the planner
echo "$TOPICS_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
records = d['result']['records']
print(f'Found {len(records)} topics to wire:')
for r in records:
    print(f'  {r[\"DeveloperName\"]} -> {r[\"Id\"]}')
"

echo ""
echo "Setting PlannerId on each topic..."

echo "$TOPICS_JSON" | python3 -c "
import json, sys, subprocess
d = json.load(sys.stdin)
records = d['result']['records']
planner_id = sys.argv[1]
target_org = sys.argv[2]
for r in records:
    result = subprocess.run([
        'sf', 'data', 'update', 'record',
        '--sobject', 'GenAiPluginDefinition',
        '--record-id', r['Id'],
        '--values', f'PlannerId={planner_id}',
        '--target-org', target_org,
        '--use-tooling-api', '--json'
    ], capture_output=True, text=True)
    out = json.loads(result.stdout)
    status = '✅' if out['result']['success'] else '❌'
    print(f'  {status} {r[\"DeveloperName\"]}')
" "$PLANNER_ID" "$TARGET_ORG"

echo ""
echo "Verification:"
sf data query \
  --query "SELECT DeveloperName, PlannerId FROM GenAiPluginDefinition ORDER BY DeveloperName" \
  --target-org "$TARGET_ORG" --use-tooling-api 2>/dev/null

echo ""
echo "Done. Topics should now appear in Agentforce Studio Builder."
echo "Note: You may need to refresh the Agentforce Studio page."
