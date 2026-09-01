/*****************************************************************
Name:          NM_LookupOccupationAction
============================================================
Purpose:       Invocable action for the Next Mission agent.
               Resolves a military specialty code to the civilian
               O*NET occupations it maps to, using the O*NET
               Military Crosswalk loaded into NM_Military_Code_V2__c
               and NM_Occupation__c.

               Replaces the cluster-based lookup for job matching.
               NM_LookupMilitaryCodeAction and the CMDT path remain
               in place until the cutover (NMDH-22).

               Two codes that previously shared a cluster now return
               different occupation sets. 68W returns Paramedics;
               68G returns medical records roles.

               Bulkification: two SOQL queries run outside any loop.
               Per-input resolution is done in memory against maps.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-01  Created   NMDH-22
*****************************************************************/
public with sharing class NM_LookupOccupationAction {

    private static final Integer MAX_OCCUPATIONS = 5;

    /*
     * Purpose:    Input wrapper for the @InvocableMethod.
     * Parameters: branch — military branch as the veteran stated it
     *             code   — specialty code (MOS, AFSC, Rating, NEC)
     */
    public class Request {
        @InvocableVariable(
            required=true
            label='Military Branch'
            description='Branch as stated by the veteran. Normalise to Army, Navy, Air Force, Marine Corps, Coast Guard or Space Force before calling.')
        public String branch;

        @InvocableVariable(
            required=true
            label='Specialty Code'
            description='Military specialty code exactly as stated (MOS, AFSC, Rating, NEC).')
        public String code;
    }

    /*
     * Purpose: Output wrapper returned to the calling agent.
     */
    public class Response {
        @InvocableVariable(
            label='Found'
            description='True when the code resolved to at least one civilian occupation.')
        public Boolean found;

        @InvocableVariable(
            label='Role Title'
            description='Military role title for the matched code, e.g. Combat Medic Specialist.')
        public String roleTitle;

        @InvocableVariable(
            label='Occupations'
            description='Civilian occupations this code maps to. Each entry is Title :: Description. Present these verbatim; never invent occupations.')
        public String occupations;

        @InvocableVariable(
            label='Occupation Count'
            description='How many civilian occupations were returned.')
        public Integer occupationCount;

        @InvocableVariable(
            label='Message'
            description='Populated only when found=false. Surface it as context, never as an accusation that the veteran got their code wrong.')
        public String message;
    }

    // Surfaced when a code is not in the crosswalk. The crosswalk is large but
    // not exhaustive, so a miss is usually our gap, not the veteran's error.
    private static final String NOT_FOUND_MSG =
        'That code is not in the crosswalk I have. That is a gap on my side, not a mistake on yours.';

    /*
     * Purpose:    Bulk-safe entry point. Resolves one or many (branch, code)
     *             pairs using two SOQL queries outside any loop.
     * Parameters: requests — list of Request; each carries branch and code
     * Returns:    list of Response, in the same order as requests
     */
    @InvocableMethod(
        label='Look Up Civilian Occupations For A Military Code'
        description='Resolve a military specialty code to the civilian O*NET occupations it maps to. Returns the role title and up to five occupations with their descriptions. Pass branch normalised to one of the six service names.'
        callout=false)
    public static List<Response> lookupOccupations(List<Request> requests) {
        System.debug('Entering NM_LookupOccupationAction.lookupOccupations: requests=' + requests.size());

        // --- Build the external keys we need, normalised the same way as load ---
        Set<String> keys = new Set<String>();
        for (Request req : requests) {
            String k = buildKey(req.branch, req.code);
            if (k != null) keys.add(k);
        }

        // --- Query 1: the military codes ------------------------------------
        Map<String, NM_Military_Code_V2__c> codeByKey = new Map<String, NM_Military_Code_V2__c>();
        Set<String> onetCodes = new Set<String>();
        if (!keys.isEmpty()) {
            for (NM_Military_Code_V2__c mc : [
                SELECT External_Key__c, Role_Title__c, ONET_Codes__c
                FROM   NM_Military_Code_V2__c
                WHERE  External_Key__c IN :keys
            ]) {
                codeByKey.put(mc.External_Key__c, mc);
                if (String.isNotBlank(mc.ONET_Codes__c)) {
                    for (String c : mc.ONET_Codes__c.split(';')) {
                        if (String.isNotBlank(c)) onetCodes.add(c.trim());
                    }
                }
            }
        }

        // --- Query 2: the occupations those codes point at --------------------
        Map<String, NM_Occupation__c> occByCode = new Map<String, NM_Occupation__c>();
        if (!onetCodes.isEmpty()) {
            for (NM_Occupation__c o : [
                SELECT Name, ONET_Code__c, Description__c
                FROM   NM_Occupation__c
                WHERE  ONET_Code__c IN :onetCodes
            ]) {
                occByCode.put(o.ONET_Code__c, o);
            }
        }

        // --- Resolve each request in memory, no further SOQL ------------------
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            String key = buildKey(req.branch, req.code);

            if (key == null || !codeByKey.containsKey(key)) {
                res.found = false;
                res.occupationCount = 0;
                res.message = NOT_FOUND_MSG;
                results.add(res);
                continue;
            }

            NM_Military_Code_V2__c mc = codeByKey.get(key);
            List<String> parts = new List<String>();
            if (String.isNotBlank(mc.ONET_Codes__c)) {
                for (String c : mc.ONET_Codes__c.split(';')) {
                    if (parts.size() >= MAX_OCCUPATIONS) break;
                    NM_Occupation__c o = occByCode.get(c.trim());
                    if (o != null) {
                        parts.add(o.Name + ' :: ' + (o.Description__c == null ? '' : o.Description__c));
                    }
                }
            }

            if (parts.isEmpty()) {
                res.found = false;
                res.occupationCount = 0;
                res.roleTitle = mc.Role_Title__c;
                res.message = NOT_FOUND_MSG;
            } else {
                res.found = true;
                res.roleTitle = mc.Role_Title__c;
                res.occupations = String.join(parts, '\n\n');
                res.occupationCount = parts.size();
            }
            results.add(res);
        }

        System.debug('Exiting NM_LookupOccupationAction.lookupOccupations: results=' + results.size());
        return results;
    }

    /*
     * Purpose:    Build the external key used at load time: BRANCH|CODE, both
     *             uppercased and trimmed. Returns null when either side is blank.
     */
    private static String buildKey(String branch, String code) {
        if (String.isBlank(branch) || String.isBlank(code)) return null;
        return branch.trim().toUpperCase() + '|' + code.trim().toUpperCase();
    }
}
