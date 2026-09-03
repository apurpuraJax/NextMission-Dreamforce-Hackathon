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

    // Three, not one. A veteran used to be handed a single mentor chosen for
    // them; three is enough to be a real choice and few enough to stay readable
    // in a screen reader announcement.
    private static final Integer MAX_OPTIONS = 3;

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

        // A veteran used to be offered ONE mentor, chosen for them, and their
        // only say was yes or no. That is a selection dressed up as an offer.
        // These carry the whole shortlist so the person picks.
        @InvocableVariable(
            label='Mentor Options'
            description='The shortlist, numbered, one per line. Present ALL of them and let the veteran choose. Never pick for them and never show only the first.')
        public String mentorOptions;

        @InvocableVariable(
            label='Mentor Option Ids'
            description='Record Ids in the SAME ORDER as Mentor Options, separated by semicolons. Pass this straight to Select Mentor along with what the veteran said. Never parse it yourself.')
        public String mentorOptionIds;

        @InvocableVariable(label='Mentor Option Count')
        public Integer mentorOptionCount;
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
        description='Returns up to three matching mentors for the given specialty cluster, for the VETERAN to choose between. NEVER returns mentor email. Pass clusterKey from session context; branch is optional and used for preferred matching.'
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

            // Same-branch first because it is the stronger match, then filled
            // out from the wider cluster. Order is meaningful and disclosed to
            // the veteran; it is not a ranking of who is better.
            List<NM_Mentor__c> shortlist = new List<NM_Mentor__c>();
            Set<Id> seen = new Set<Id>();

            if (!String.isBlank(req.branch)) {
                for (NM_Mentor__c m : [
                    SELECT Id, Name, Civilian_Role__c, Employer__c, Bio__c
                    FROM NM_Mentor__c
                    WHERE Specialty_Cluster__c = :req.clusterKey
                    AND Active__c = true
                    AND Branch__c = :req.branch
                    ORDER BY Name
                    LIMIT :MAX_OPTIONS
                ]) { if (seen.add(m.Id)) shortlist.add(m); }
            }

            if (shortlist.size() < MAX_OPTIONS) {
                for (NM_Mentor__c m : [
                    SELECT Id, Name, Civilian_Role__c, Employer__c, Bio__c
                    FROM NM_Mentor__c
                    WHERE Specialty_Cluster__c = :req.clusterKey
                    AND Active__c = true
                    ORDER BY Name
                    LIMIT :MAX_OPTIONS
                ]) {
                    if (shortlist.size() >= MAX_OPTIONS) break;
                    if (seen.add(m.Id)) shortlist.add(m);
                }
            }

            if (!shortlist.isEmpty()) {
                NM_Mentor__c mentor = shortlist[0];
                res.found          = true;
                // Emit the Id as text so it flows through a string session variable.
                res.mentorId       = String.valueOf(mentor.Id);
                res.mentorName     = mentor.Name;
                res.mentorCivilianRole = mentor.Civilian_Role__c;
                res.mentorEmployer = mentor.Employer__c;
                res.mentorBio      = mentor.Bio__c;

                List<String> lines = new List<String>();
                List<String> ids   = new List<String>();
                for (Integer i = 0; i < shortlist.size(); i++) {
                    NM_Mentor__c m = shortlist[i];
                    String line = String.valueOf(i + 1) + '. ' + m.Name;
                    if (String.isNotBlank(m.Civilian_Role__c)) line += ', ' + m.Civilian_Role__c;
                    if (String.isNotBlank(m.Employer__c))      line += ' at ' + m.Employer__c;
                    if (String.isNotBlank(m.Bio__c))           line += '. ' + m.Bio__c;
                    lines.add(line);
                    ids.add(String.valueOf(m.Id));
                }
                res.mentorOptions      = String.join(lines, '\n');
                res.mentorOptionIds    = String.join(ids, ';');
                res.mentorOptionCount  = shortlist.size();
            } else {
                res.message = 'I don\'t have a matched mentor for that background yet, but the roster is growing.';
            }

            results.add(res);
        }

        System.debug('Exiting NM_FindMentorAction.findMentor: results=' + results.size());
        return results;
    }
}
