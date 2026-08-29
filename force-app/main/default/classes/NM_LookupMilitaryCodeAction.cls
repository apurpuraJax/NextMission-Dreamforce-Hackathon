/*****************************************************************
Name:          NM_LookupMilitaryCodeAction
============================================================
Purpose:       Invocable action for the Next Mission agent.
               Accepts a military branch and specialty code,
               queries NM_Military_Code__mdt for a match, then
               joins to NM_Specialty_Cluster__mdt for the
               human-readable cluster label.

               Matching is case-insensitive: branch and code are
               normalized (branch to lowercase, code to uppercase)
               before the in-memory lookup, so veteran input of
               'army' / '11b' resolves identically to 'Army' / '11B'.

               Bulkification: two SOQL queries run outside any loop
               and load all relevant CMDT records into maps. Per-input
               resolution is done in memory against those maps.
============================================================
History
-------
VERSION  AUTHOR              DATE         DETAIL    DESCRIPTION
1.0      Revecast Orch.      2026-08-29   Created   NMDH-5
*****************************************************************/
public with sharing class NM_LookupMilitaryCodeAction {

    /*
     * Purpose:    Input wrapper for the @InvocableMethod.
     * Parameters: branch — military branch as the veteran stated it
     *             code   — specialty code (MOS, AFSC, Rate, NEC, etc.)
     */
    public class Input {
        @InvocableVariable(
            required=true
            label='Military Branch'
            description='The military branch as stated by the veteran (Army, Navy, Air Force, Marine Corps, Coast Guard, Space Force).')
        public String branch;

        @InvocableVariable(
            required=true
            label='Specialty Code'
            description='The military specialty code exactly as stated (MOS, AFSC, Rating, NEC, etc.).')
        public String code;
    }

    /*
     * Purpose: Output wrapper returned to the calling Flow or GenAiFunction.
     */
    public class Response {
        @InvocableVariable(
            label='Found'
            description='True when the code was found in the Custom Metadata; false otherwise.')
        public Boolean found;

        @InvocableVariable(
            label='Role Title'
            description='Military role title for the matched code. Null when found=false.')
        public String roleTitle;

        @InvocableVariable(
            label='Cluster Key'
            description='Internal key linking to NM_Specialty_Cluster__mdt. Null when found=false.')
        public String clusterKey;

        @InvocableVariable(
            label='Cluster Label'
            description='Human-readable cluster name (MasterLabel of NM_Specialty_Cluster__mdt). Null when found=false.')
        public String clusterLabel;

        @InvocableVariable(
            label='Not Found Message'
            description='Standard message to surface verbatim when found=false. Null when found=true.')
        public String notFoundMessage;
    }

    // Standard not-found message — surface verbatim; do not rephrase or truncate.
    private static final String NOT_FOUND_MSG =
        'I don\'t recognize that code — can you describe what your role involved day to day? ' +
        'That will help me find the right match.';

    /*
     * Purpose:    Bulk-safe entry point. Resolves one or many (branch, code)
     *             pairs in a single transaction using two SOQL queries outside
     *             any loop.
     * Parameters: inputs — list of Input; each carries branch and code
     * Returns:    list of Response, one per input, in the same order as inputs
     */
    @InvocableMethod(
        label='Look Up Military Code'
        description='Look up a military specialty code to find its civilian mapping.')
    public static List<Response> lookupCode(List<Input> inputs) {
        System.debug('Entering NM_LookupMilitaryCodeAction.lookupCode: inputs.size=' + inputs.size());

        // --- Query 1: load all NM_Military_Code__mdt records once ---------------
        // Composite key: branch.toLowerCase() + '|' + code.toUpperCase()
        // Normalize both sides so 'army|11b' matches 'Army|11B'.
        Map<String, NM_Military_Code__mdt> codeMap = new Map<String, NM_Military_Code__mdt>();
        for (NM_Military_Code__mdt mc : [
            SELECT Branch__c, Code_Value__c, Role_Title__c, Cluster_Key__c
            FROM   NM_Military_Code__mdt
        ]) {
            String key = mc.Branch__c.toLowerCase() + '|' + mc.Code_Value__c.toUpperCase();
            codeMap.put(key, mc);
        }

        // --- Query 2: load all NM_Specialty_Cluster__mdt labels once -----------
        Map<String, String> clusterLabelMap = new Map<String, String>();
        for (NM_Specialty_Cluster__mdt sc : [
            SELECT Cluster_Key__c, MasterLabel
            FROM   NM_Specialty_Cluster__mdt
        ]) {
            clusterLabelMap.put(sc.Cluster_Key__c, sc.MasterLabel);
        }

        // --- Resolve each input in memory — no further SOQL --------------------
        List<Response> responses = new List<Response>();
        for (Input inp : inputs) {
            String branch = (inp.branch != null ? inp.branch.trim() : '').toLowerCase();
            String code   = (inp.code   != null ? inp.code.trim()   : '').toUpperCase();
            String key    = branch + '|' + code;

            Response r = new Response();

            if (codeMap.containsKey(key)) {
                NM_Military_Code__mdt mc = codeMap.get(key);
                r.found        = true;
                r.roleTitle    = mc.Role_Title__c;
                r.clusterKey   = mc.Cluster_Key__c;
                r.clusterLabel = clusterLabelMap.containsKey(mc.Cluster_Key__c)
                                 ? clusterLabelMap.get(mc.Cluster_Key__c)
                                 : mc.Cluster_Key__c;
            } else {
                r.found           = false;
                r.notFoundMessage = NOT_FOUND_MSG;
            }

            responses.add(r);
        }

        System.debug('Exiting NM_LookupMilitaryCodeAction.lookupCode: responses.size=' + responses.size());
        return responses;
    }
}
