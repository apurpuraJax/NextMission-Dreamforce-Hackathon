/*****************************************************************
Name:          NM_FindMentorAction
============================================================
Purpose:       @InvocableMethod for Agentforce. Returns one
               matching mentor (no email) for the given specialty
               cluster key. Tries exact-branch match first; falls
               back to any active mentor in the cluster.
               Created by NMDH-8.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-8
1.1      Orchestrate  2026-09-01   Updated   NMDH-8 mentorId typed as String
                                             so the Agentforce planner can hold
                                             it in a simple string session
                                             variable and pass it downstream to
                                             NM_RequestMentorIntroAction.
*****************************************************************/
public with sharing class NM_FindMentorAction {

    /*****************************************************************
    Purpose:       Input schema consumed by the Agentforce planner.
    *****************************************************************/
    public class Request {
        @InvocableVariable(
            label='Cluster Key'
            description='NM_Specialty_Cluster__mdt key from session context — identifies the civilian skill cluster to match against.'
            required=true
        )
        public String clusterKey;

        @InvocableVariable(
            label='Branch'
            description='Military branch of the veteran (e.g. Army, Navy). Optional — used for preferred same-branch matching.'
            required=false
        )
        public String branch;
    }

    /*****************************************************************
    Purpose:       Output schema returned to the Agentforce planner.
                   Contact_Email__c is intentionally never included.
    *****************************************************************/
    public class Response {
        @InvocableVariable(label='Found' description='True if a mentor was located.')
        public Boolean found;

        @InvocableVariable(label='Mentor Name')
        public String mentorName;

        @InvocableVariable(label='Mentor Civilian Role')
        public String mentorCivilianRole;

        @InvocableVariable(label='Mentor Employer')
        public String mentorEmployer;

        @InvocableVariable(label='Mentor Bio')
        public String mentorBio;

        // Typed as String (not Id) so the Agentforce planner can store the
        // value in a simple string session variable and pass it to
        // NM_RequestMentorIntroAction, which also accepts mentorId as String.
        @InvocableVariable(label='Mentor Id' description='NM_Mentor__c record Id as text — pass to NM_RequestMentorIntroAction.')
        public String mentorId;

        @InvocableVariable(label='Message' description='Human-readable result. Populated when found=false.')
        public String message;
    }

    /*****************************************************************
    Purpose:       Invoked by the Agentforce planner. Attempts an
                   exact-branch match first; falls back to any active
                   mentor in the cluster when no branch match exists.
    Parameters:    requests — single-element list (planner wraps it)
    Returns:       single-element list of Response
    *****************************************************************/
    @InvocableMethod(
        label='Find Mentor'
        description='Returns one matching mentor for the given specialty cluster. NEVER returns mentor email. Pass clusterKey from session context; branch is optional and used for preferred matching.'
        callout=false
    )
    public static List<Response> findMentor(List<Request> requests) {
        System.debug('Entering NM_FindMentorAction.findMentor');

        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.found = false;

            if (String.isBlank(req.clusterKey)) {
                res.message = 'I don\'t have a matched mentor for that background yet, but the roster is growing.';
                results.add(res);
                continue;
            }

            NM_Mentor__c mentor = null;

            // Attempt 1: exact-branch match when branch is provided
            if (!String.isBlank(req.branch)) {
                List<NM_Mentor__c> branchMatches = [
                    SELECT Id, Name, Civilian_Role__c, Employer__c, Bio__c
                    FROM NM_Mentor__c
                    WHERE Specialty_Cluster__c = :req.clusterKey
                    AND Active__c = true
                    AND Branch__c = :req.branch
                    LIMIT 1
                ];
                if (!branchMatches.isEmpty()) {
                    mentor = branchMatches[0];
                }
            }

            // Attempt 2: any-branch fallback
            if (mentor == null) {
                List<NM_Mentor__c> anyMatches = [
                    SELECT Id, Name, Civilian_Role__c, Employer__c, Bio__c
                    FROM NM_Mentor__c
                    WHERE Specialty_Cluster__c = :req.clusterKey
                    AND Active__c = true
                    LIMIT 1
                ];
                if (!anyMatches.isEmpty()) {
                    mentor = anyMatches[0];
                }
            }

            if (mentor != null) {
                res.found          = true;
                // Emit the Id as text so it flows through a string session variable.
                res.mentorId       = String.valueOf(mentor.Id);
                res.mentorName     = mentor.Name;
                res.mentorCivilianRole = mentor.Civilian_Role__c;
                res.mentorEmployer = mentor.Employer__c;
                res.mentorBio      = mentor.Bio__c;
            } else {
                res.message = 'I don\'t have a matched mentor for that background yet, but the roster is growing.';
            }

            results.add(res);
        }

        System.debug('Exiting NM_FindMentorAction.findMentor: results=' + results.size());
        return results;
    }
}
