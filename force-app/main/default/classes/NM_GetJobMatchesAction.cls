/*****************************************************************
Name:          NM_GetJobMatchesAction
============================================================
Purpose:       Invocable action for the Next Mission agent.
               Accepts a cluster key, queries NM_Specialty_Cluster__mdt,
               and returns the stored civilian job list as a JSON string.

               Jobs are returned in stored order — no ranking, no
               suitability scoring. The agent presents them as-is.

               If the cluster key is not found, the Job_Descriptions__c
               field is blank, or the JSON is malformed, returns
               success=false with a plain-language message.

               Never invents jobs, titles, or descriptions.

               Bulkification: one SOQL query loads all relevant CMDT
               records into a map. Per-input resolution is done in memory.
============================================================
History
-------
VERSION  AUTHOR              DATE         DETAIL    DESCRIPTION
1.0      Revecast Orch.      2026-08-29   Created   NMDH-7
*****************************************************************/
public with sharing class NM_GetJobMatchesAction {

    /*
     * Purpose:    Input wrapper for the @InvocableMethod.
     * Parameters: clusterKey — key from NM_Specialty_Cluster__mdt
     */
    public class Input {
        @InvocableVariable(
            required=true
            label='Cluster Key'
            description='The Cluster_Key__c value from NM_Specialty_Cluster__mdt, as returned by NM_LookupMilitaryCodeAction.')
        public String clusterKey;
    }

    /*
     * Purpose: Output wrapper returned to the calling GenAiFunction.
     */
    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when jobs were found and parsed successfully; false otherwise.')
        public Boolean success;

        @InvocableVariable(
            label='Jobs JSON'
            description='Full JSON array of job objects (title, description). Null when success=false.')
        public String jobsJson;

        @InvocableVariable(
            label='Message'
            description='Plain-language message when success=false. Null when success=true.')
        public String message;
    }

    // Standard messages — agents surface these verbatim; do not rephrase.
    @TestVisible
    private static final String CLUSTER_NOT_FOUND_MSG =
        'I don\'t have job information for that specialty area yet. ' +
        'Try describing what your role involved and I can look for a better match.';

    @TestVisible
    private static final String MALFORMED_DATA_MSG =
        'There was a problem reading the job information for that specialty. ' +
        'Please try again or describe your role and I\'ll help another way.';

    /*
     * Purpose:    Bulk-safe entry point. One SOQL query loads all matching
     *             CMDT records; per-input resolution happens in memory.
     * Parameters: inputs — list of Input, each carrying a clusterKey
     * Returns:    list of Response, one per input, in the same order
     */
    @InvocableMethod(
        label='Get Job Matches'
        description='Return civilian job options for a cluster key. Jobs are from stored data only — no ranking or suitability scoring.')
    public static List<Response> getJobMatches(List<Input> inputs) {
        System.debug('Entering NM_GetJobMatchesAction.getJobMatches: inputs.size=' + inputs.size());

        // Collect the distinct keys we need
        Set<String> keys = new Set<String>();
        for (Input inp : inputs) {
            if (String.isNotBlank(inp.clusterKey)) {
                keys.add(inp.clusterKey.trim());
            }
        }

        // --- One SOQL query — no loop queries --------------------------------
        Map<String, NM_Specialty_Cluster__mdt> clusterMap =
            new Map<String, NM_Specialty_Cluster__mdt>();
        if (!keys.isEmpty()) {
            for (NM_Specialty_Cluster__mdt sc : [
                SELECT Cluster_Key__c, Job_Descriptions__c
                FROM   NM_Specialty_Cluster__mdt
                WHERE  Cluster_Key__c IN :keys
            ]) {
                clusterMap.put(sc.Cluster_Key__c, sc);
            }
        }

        // --- Resolve in memory — no further SOQL ----------------------------
        List<Response> responses = new List<Response>();
        for (Input inp : inputs) {
            String key = (inp.clusterKey != null) ? inp.clusterKey.trim() : '';

            if (String.isBlank(key) || !clusterMap.containsKey(key)) {
                Response r = new Response();
                r.success = false;
                r.message = CLUSTER_NOT_FOUND_MSG;
                responses.add(r);
                continue;
            }

            NM_Specialty_Cluster__mdt sc = clusterMap.get(key);
            responses.add(parseClusterData(key, sc.Job_Descriptions__c));
        }

        System.debug('Exiting NM_GetJobMatchesAction.getJobMatches: responses.size=' + responses.size());
        return responses;
    }

    /*
     * Purpose:    Parse Job_Descriptions__c JSON into a Response.
     *             Extracted as @TestVisible so malformed-JSON paths
     *             can be covered without CMDT record injection.
     * Parameters: clusterKey — used only for debug logging
     *             rawJson    — the raw Job_Descriptions__c field value
     * Returns:    Response with success=true and jobsJson set, or
     *             success=false with a message if data is blank or malformed.
     */
    @TestVisible
    static Response parseClusterData(String clusterKey, String rawJson) {
        Response r = new Response();

        if (String.isBlank(rawJson)) {
            r.success = false;
            r.message = CLUSTER_NOT_FOUND_MSG;
            return r;
        }

        try {
            List<Object> parsed = (List<Object>) JSON.deserializeUntyped(rawJson);
            if (parsed == null || parsed.isEmpty()) {
                r.success = false;
                r.message = CLUSTER_NOT_FOUND_MSG;
            } else {
                r.success  = true;
                r.jobsJson = rawJson;
            }
        } catch (Exception ex) {
            System.debug(
                'NM_GetJobMatchesAction.parseClusterData: malformed JSON for cluster '
                + clusterKey + ': ' + ex.getMessage());
            r.success = false;
            r.message = MALFORMED_DATA_MSG;
        }

        return r;
    }
}
