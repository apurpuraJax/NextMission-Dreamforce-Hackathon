/*****************************************************************
Name:          NM_MentorCorpusAction
============================================================
Purpose:       Build the mentor corpus that NM_Find_Mentor_Template
               matches against, capped and prioritised.

               NM_FindMentor_Flow previously passed the ENTIRE active
               roster into the prompt. At 19 mentors that was ~2,000
               tokens; the staged roster of 75 takes it to ~6,000, and
               turns the task into "pick one of 75", which is the shape
               of problem small models handle worst. They skew toward
               items at the start and end of a long list and lose the
               middle.

               This returns the veteran's own career area first, then
               fills the remainder from other areas so a cross-area
               match is still possible. That was the point of NMDH-24:
               cluster is a tie-breaker, never a hard filter.

               Ordering is deterministic (Name) so the same veteran gets
               the same shortlist twice, which makes defects
               reproducible.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-01  Created   NMDH-24 corpus cap
*****************************************************************/
public with sharing class NM_MentorCorpusAction {

    /* Total candidates handed to the model. Chosen so the shortlist stays
       comfortably readable rather than to hit a token budget. */
    @TestVisible private static Integer MAX_TOTAL      = 15;
    /* Of those, how many may come from the veteran's own career area. */
    @TestVisible private static Integer MAX_IN_CLUSTER = 10;

    public class Request {
        @InvocableVariable(
            label='Cluster Key'
            description='The veteran career area to prioritise. Safe to leave blank; the shortlist is then drawn from the whole roster.')
        public String clusterKey;
    }

    public class Response {
        @InvocableVariable(label='Mentor Corpus'
            description='One mentor per line: Id | Name | Civilian Role | Employer | Cluster | Bio')
        public String corpus;

        @InvocableVariable(label='Candidate Count'
            description='How many mentors are in the shortlist.')
        public Integer candidateCount;

        @InvocableVariable(label='Roster Size'
            description='How many active mentors exist in total, for observability.')
        public Integer rosterSize;
    }

    /*
     * Purpose:    Return a capped, cluster-prioritised mentor shortlist.
     * Parameters: requests — one Request; clusterKey may be blank
     * Returns:    one Response per request
     */
    @InvocableMethod(
        label='Build Mentor Corpus'
        description='Return a capped shortlist of active mentors for semantic matching, prioritising the veteran career area but always including others so cross-area matches remain possible.'
        callout=false)
    public static List<Response> buildCorpus(List<Request> requests) {
        System.debug('Entering NM_MentorCorpusAction.buildCorpus');

        List<NM_Mentor__c> all = [
            SELECT Id, Name, Civilian_Role__c, Employer__c, Specialty_Cluster__c, Bio__c
            FROM   NM_Mentor__c
            WHERE  Active__c = true
            ORDER BY Name ASC
        ];

        List<Response> out = new List<Response>();
        for (Request req : requests) {
            String key = (req == null || req.clusterKey == null) ? '' : req.clusterKey.trim();

            List<NM_Mentor__c> inCluster = new List<NM_Mentor__c>();
            List<NM_Mentor__c> others    = new List<NM_Mentor__c>();
            for (NM_Mentor__c m : all) {
                if (String.isNotBlank(key) && key.equalsIgnoreCase(m.Specialty_Cluster__c)) {
                    inCluster.add(m);
                } else {
                    others.add(m);
                }
            }

            List<NM_Mentor__c> shortlist = new List<NM_Mentor__c>();
            for (NM_Mentor__c m : inCluster) {
                if (shortlist.size() >= MAX_IN_CLUSTER) break;
                shortlist.add(m);
            }
            // Always leave room for other areas. A veteran whose best match sits
            // outside their own field must still be able to reach them.
            for (NM_Mentor__c m : others) {
                if (shortlist.size() >= MAX_TOTAL) break;
                shortlist.add(m);
            }

            List<String> lines = new List<String>();
            for (NM_Mentor__c m : shortlist) {
                lines.add(
                    m.Id + ' | ' +
                    (m.Name == null ? '' : m.Name) + ' | ' +
                    (m.Civilian_Role__c == null ? '' : m.Civilian_Role__c) + ' | ' +
                    (m.Employer__c == null ? '' : m.Employer__c) + ' | ' +
                    (m.Specialty_Cluster__c == null ? '' : m.Specialty_Cluster__c) + ' | ' +
                    (m.Bio__c == null ? '' : m.Bio__c)
                );
            }

            Response res = new Response();
            res.corpus         = String.join(lines, '\n');
            res.candidateCount = shortlist.size();
            res.rosterSize     = all.size();
            out.add(res);
        }

        System.debug('Exiting NM_MentorCorpusAction.buildCorpus: roster=' + all.size());
        return out;
    }
}
