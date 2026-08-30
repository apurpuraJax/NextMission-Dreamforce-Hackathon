/*****************************************************************
Name:          NM_TranslateSkillsAction
============================================================
Purpose:       @InvocableMethod for Agentforce. Looks up the
               veteran's specialty cluster in NM_Specialty_Cluster__mdt
               by Cluster_Key__c and returns the civilian skill summary
               and job descriptions as grounding data for the agent.
               Fully bulk-safe: one SOQL regardless of request count.
               Created by NMDH-6.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-6
*****************************************************************/
public with sharing class NM_TranslateSkillsAction {

    /*****************************************************************
    Purpose:       Input schema consumed by the Agentforce planner.
    *****************************************************************/
    public class Request {
        @InvocableVariable(
            label='Cluster Key'
            description='NM_Specialty_Cluster__mdt Cluster_Key__c — identifies the civilian skill cluster from session context.'
            required=true
        )
        public String clusterKey;

        @InvocableVariable(
            label='User Prompt'
            description='The veteran\'s own description of their military role or experience.'
            required=false
        )
        public String userPrompt;
    }

    /*****************************************************************
    Purpose:       Output schema returned to the Agentforce planner.
    *****************************************************************/
    public class Response {
        @InvocableVariable(
            label='Found'
            description='True if a matching NM_Specialty_Cluster__mdt record was found.'
        )
        public Boolean found;

        @InvocableVariable(
            label='Translated Skills'
            description='Civilian skill summary and relevant job descriptions for this cluster. Use these to explain how the veteran\'s military background maps to civilian careers.'
        )
        public String translatedSkills;

        @InvocableVariable(
            label='Message'
            description='Human-readable result. Populated only when found=false.'
        )
        public String message;
    }

    /*****************************************************************
    Purpose:       Invoked by the Agentforce planner. Collects all
               cluster keys from the request list, issues a single
               CMDT query, then maps results back to each response.
    Parameters:    requests — one or more Request objects (planner wraps)
    Returns:       parallel list of Response objects
    *****************************************************************/
    @InvocableMethod(
        label='Translate Military Skills to Civilian'
        description='Looks up the veteran\'s specialty cluster and returns civilian skill summary and job descriptions. Pass clusterKey from session context; userPrompt is optional context. Use translatedSkills to explain how military experience maps to civilian careers.'
        callout=false
    )
    public static List<Response> translateSkills(List<Request> requests) {
        System.debug('Entering NM_TranslateSkillsAction.translateSkills: requests=' + requests.size());

        // Collect non-blank keys for a single bulk CMDT query
        Set<String> clusterKeys = new Set<String>();
        for (Request req : requests) {
            if (!String.isBlank(req.clusterKey)) {
                clusterKeys.add(req.clusterKey);
            }
        }

        // Single SOQL — never inside a loop
        Map<String, NM_Specialty_Cluster__mdt> clusterByKey = new Map<String, NM_Specialty_Cluster__mdt>();
        if (!clusterKeys.isEmpty()) {
            for (NM_Specialty_Cluster__mdt c : [
                SELECT Cluster_Key__c, Civilian_Skill_Summary__c, Job_Descriptions__c
                FROM NM_Specialty_Cluster__mdt
                WHERE Cluster_Key__c IN :clusterKeys
            ]) {
                clusterByKey.put(c.Cluster_Key__c, c);
            }
        }

        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            if (String.isBlank(req.clusterKey) || !clusterByKey.containsKey(req.clusterKey)) {
                res.found   = false;
                res.message = 'I don\'t have data on that specialty yet — can you describe what your role involved day to day?';
            } else {
                NM_Specialty_Cluster__mdt cluster = clusterByKey.get(req.clusterKey);
                res.found = true;

                String skillsPart = String.isBlank(cluster.Civilian_Skill_Summary__c)
                    ? '' : cluster.Civilian_Skill_Summary__c;
                String jobsPart = String.isBlank(cluster.Job_Descriptions__c)
                    ? '' : cluster.Job_Descriptions__c;

                // Combine both fields; blank handling prevents orphan separators
                if (!String.isBlank(skillsPart) && !String.isBlank(jobsPart)) {
                    res.translatedSkills = skillsPart + '\n\n' + jobsPart;
                } else if (!String.isBlank(skillsPart)) {
                    res.translatedSkills = skillsPart;
                } else {
                    res.translatedSkills = jobsPart;
                }
            }

            results.add(res);
        }

        System.debug('Exiting NM_TranslateSkillsAction.translateSkills: results=' + results.size());
        return results;
    }
}
