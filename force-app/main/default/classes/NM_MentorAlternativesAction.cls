/*****************************************************************
Name:          NM_MentorAlternativesAction
============================================================
Purpose:       Turn a single recommended mentor into a shortlist the
               veteran can actually choose from.

               The live match is made by a prompt template that reads
               every active mentor and returns ONE id. That semantic
               match is good and worth keeping. What was not defensible
               was that it arrived as the only option: the veteran's
               entire say was yes or no to a person a model picked for
               them, while the product claimed it recommends and the
               human decides.

               So the recommendation stays, and this puts real
               alternatives beside it. Position 1 is always the
               recommended mentor, and the ordering is disclosed to the
               veteran rather than presented as a ranking of who is
               better, because nothing here scores one person above
               another.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, human-in-the-loop
*****************************************************************/
public with sharing class NM_MentorAlternativesAction {

    private static final Integer SHORTLIST_SIZE = 3;

    public class Request {
        @InvocableVariable(
            label='Recommended Mentor Id'
            description='The mentorId find_mentor already returned. It stays in position 1.'
            required=true)
        public String recommendedMentorId;

        @InvocableVariable(
            label='Cluster Key'
            description='Specialty cluster to draw alternatives from. Optional; without it the alternatives come from the wider active roster.')
        public String clusterKey;

        @InvocableVariable(
            label='Branch'
            description='Veteran branch, used to prefer a same-branch alternative. Optional.')
        public String branch;
    }

    public class Response {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(
            label='Mentor Options'
            description='The shortlist, numbered, one per line, recommendation first. Present ALL of them.')
        public String mentorOptions;

        @InvocableVariable(
            label='Mentor Option Ids'
            description='Record Ids in the SAME ORDER, separated by semicolons. Pass verbatim to Select Mentor. Never parse or reorder it.')
        public String mentorOptionIds;

        @InvocableVariable(label='Mentor Option Count')
        public Integer mentorOptionCount;

        @InvocableVariable(
            label='Has Alternatives'
            description='False when the recommended mentor is the only active match. Say so plainly rather than implying a choice that does not exist.')
        public Boolean hasAlternatives;
    }

    /*
     * Purpose:    Build the shortlist around an already-chosen recommendation.
     */
    @InvocableMethod(
        label='Get Mentor Alternatives'
        description='Return the recommended mentor plus up to two others the veteran could pick instead. Always present every option and let them choose.'
        callout=false)
    public static List<Response> getAlternatives(List<Request> requests) {
        System.debug('Entering NM_MentorAlternativesAction.getAlternatives');

        Set<Id> recommended = new Set<Id>();
        Set<String> clusters = new Set<String>();
        for (Request req : requests) {
            if (req == null) continue;
            if (String.isNotBlank(req.recommendedMentorId)) {
                try { recommended.add((Id) req.recommendedMentorId.trim()); }
                catch (Exception e) { /* not an Id */ }
            }
            if (String.isNotBlank(req.clusterKey)) clusters.add(req.clusterKey);
        }

        // One query for the whole batch. Ordered by Name so the shortlist a
        // veteran sees is stable if they come back to it in the same session.
        List<NM_Mentor__c> pool = [
            SELECT Id, Name, Civilian_Role__c, Employer__c, Bio__c,
                   Specialty_Cluster__c, Branch__c
            FROM   NM_Mentor__c
            WHERE  Active__c = true
            ORDER BY Name
            LIMIT  200
        ];
        Map<Id, NM_Mentor__c> byId = new Map<Id, NM_Mentor__c>(pool);

        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(buildOne(req, pool, byId));
        }

        System.debug('Exiting NM_MentorAlternativesAction: results=' + results.size());
        return results;
    }

    @TestVisible
    private static Response buildOne(Request req, List<NM_Mentor__c> pool,
                                     Map<Id, NM_Mentor__c> byId) {
        Response res = new Response();
        res.found = false;
        res.hasAlternatives = false;

        NM_Mentor__c primary = null;
        if (req != null && String.isNotBlank(req.recommendedMentorId)) {
            try { primary = byId.get((Id) req.recommendedMentorId.trim()); }
            catch (Exception e) { primary = null; }
        }
        if (primary == null) return res;

        List<NM_Mentor__c> shortlist = new List<NM_Mentor__c>{ primary };
        Set<Id> used = new Set<Id>{ primary.Id };

        // Same cluster and same branch is the closest alternative, then same
        // cluster, then anyone active. Each pass only fills what is left.
        for (Integer pass = 0; pass < 3; pass++) {
            for (NM_Mentor__c m : pool) {
                if (shortlist.size() >= SHORTLIST_SIZE) break;
                if (used.contains(m.Id)) continue;
                Boolean ok =
                    pass == 0 ? (req.clusterKey == m.Specialty_Cluster__c
                                 && String.isNotBlank(req.branch) && req.branch == m.Branch__c)
                  : pass == 1 ? (req.clusterKey == m.Specialty_Cluster__c)
                  : true;
                if (!ok) continue;
                shortlist.add(m);
                used.add(m.Id);
            }
            if (shortlist.size() >= SHORTLIST_SIZE) break;
        }

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

        res.found             = true;
        res.mentorOptions     = String.join(lines, '\n');
        res.mentorOptionIds   = String.join(ids, ';');
        res.mentorOptionCount = shortlist.size();
        res.hasAlternatives   = shortlist.size() > 1;
        return res;
    }
}
