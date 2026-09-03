/*****************************************************************
Name:          NM_FindMentorWithOptionsAction
============================================================
Purpose:       Find a mentor AND the alternatives, in one call the
               agent cannot take half of.

               The shortlist began as a second action with an
               instruction telling the agent to call it. Measured on
               the live site, it did not: it said "let me check if
               there are other mentors" and then introduced the first
               one without ever checking. The veteran was offered a
               choice in words and given none in fact, which is worse
               than not offering.

               The corpus that drives the semantic match is in the
               model's context, so it can describe any mentor whether
               or not an action ran. Removing outputs did not stop it.
               The only thing that stops it is not having a step to
               skip. One action, one round trip, shortlist included.

               This is the same lesson as the wage net and the distress
               net: an instruction is a preference, a boundary is a
               guarantee.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, human-in-the-loop
*****************************************************************/
public with sharing class NM_FindMentorWithOptionsAction {

    public class Request {
        @InvocableVariable(
            label='Cluster Key'
            description='Specialty cluster, if known. Optional; matching works without it.')
        public String clusterKey;

        @InvocableVariable(
            label='Description'
            description='A short summary of this veteran: role title, occupations, what they did, and what they want from a mentor. A blank description returns no mentor at all.'
            required=true)
        public String description;

        @InvocableVariable(label='Branch' description='Veteran branch, used to prefer a same-branch alternative. Optional.')
        public String branch;
    }

    public class Response {
        @InvocableVariable(label='Found')
        public Boolean found;

        @InvocableVariable(label='Mentor Id' description='The recommended mentor. Position 1 in the options.')
        public String mentorId;

        @InvocableVariable(
            label='Mentor Options'
            description='Every mentor the veteran may choose from, numbered, recommendation first. This is the ONLY text you may use to describe anyone. Present all of it, in this order, unedited.')
        public String mentorOptions;

        @InvocableVariable(
            label='Mentor Option Ids'
            description='Record Ids in the SAME ORDER as Mentor Options, semicolon separated. Pass verbatim to Select Mentor. Never parse or reorder it.')
        public String mentorOptionIds;

        @InvocableVariable(
            label='Has Alternatives'
            description='False when the recommendation is the only active match. Say that plainly rather than implying a choice that is not there.')
        public Boolean hasAlternatives;

        // Restored deliberately. Stripping these to force the agent through the
        // shortlist backfired: handed an id and no words, the model INVENTED a
        // mentor. It described a real person, Alex R., as a paramedic who moved
        // from Army 68W. Alex R. is a Supply Chain Manager in Logistics. Give it
        // true text or it will write its own, which is the same lesson as the
        // wage net in a worse place, because this is somebody's name.
        @InvocableVariable(label='Mentor Name' description='The recommended mentor. Use this or mentorOptions, never your own words.')
        public String mentorName;

        @InvocableVariable(label='Mentor Civilian Role')
        public String mentorCivilianRole;

        @InvocableVariable(label='Mentor Employer')
        public String mentorEmployer;

        @InvocableVariable(label='Mentor Bio')
        public String mentorBio;

        @InvocableVariable(label='Message' description='Populated when no mentor was found.')
        public String message;
    }

    @InvocableMethod(
        label='Find Mentor With Options'
        description='Find the best-matching mentor AND the alternatives the veteran can pick instead, in one call. Always present every option returned.'
        callout=false)
    public static List<Response> findWithOptions(List<Request> requests) {
        System.debug('Entering NM_FindMentorWithOptionsAction: requests=' + requests.size());

        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(oneRequest(req));
        }

        System.debug('Exiting NM_FindMentorWithOptionsAction: results=' + results.size());
        return results;
    }

    private static Response oneRequest(Request req) {
        Response res = new Response();
        res.found = false;
        res.hasAlternatives = false;

        if (req == null || String.isBlank(req.description)) {
            res.message = 'I need to know a bit about your background before I can match you.';
            return res;
        }

        String mentorId;
        try {
            // The semantic match lives in this Flow and is worth keeping; it
            // reads every active mentor and picks the closest. We only take the
            // id from it, never the descriptive fields, so there is exactly one
            // source for what the veteran is shown.
            Flow.Interview f = Flow.Interview.createInterview(
                'NM_FindMentor_Flow',
                new Map<String, Object>{
                    'clusterKey'  => req.clusterKey,
                    'description' => req.description
                });
            f.start();
            Boolean found = (Boolean) f.getVariableValue('found');
            mentorId = (String) f.getVariableValue('mentorId');
            if (found != true || String.isBlank(mentorId)) {
                res.message = (String) f.getVariableValue('message');
                if (String.isBlank(res.message)) {
                    res.message = 'I do not have a matched mentor for that background yet, '
                                + 'but the roster is growing.';
                }
                return res;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Mentor match failed: ' + e.getMessage());
            res.message = 'I could not look up a mentor just then. Ask me again in a moment.';
            return res;
        }

        NM_MentorAlternativesAction.Request ar = new NM_MentorAlternativesAction.Request();
        ar.recommendedMentorId = mentorId;
        ar.clusterKey          = req.clusterKey;
        ar.branch              = req.branch;
        NM_MentorAlternativesAction.Response alt =
            NM_MentorAlternativesAction.getAlternatives(
                new List<NM_MentorAlternativesAction.Request>{ ar })[0];

        if (alt == null || alt.found != true) {
            res.message = 'I found a mentor but could not read their details. '
                        + 'Ask me again in a moment.';
            return res;
        }

        // Every descriptive field comes from the record, never from the model.
        NM_Mentor__c primary = [
            SELECT Name, Civilian_Role__c, Employer__c, Bio__c
            FROM   NM_Mentor__c WHERE Id = :mentorId LIMIT 1 ];
        res.mentorName         = primary.Name;
        res.mentorCivilianRole = primary.Civilian_Role__c;
        res.mentorEmployer     = primary.Employer__c;
        res.mentorBio          = primary.Bio__c;

        res.found            = true;
        res.mentorId         = mentorId;
        res.mentorOptions    = alt.mentorOptions;
        res.mentorOptionIds  = alt.mentorOptionIds;
        res.hasAlternatives  = alt.hasAlternatives;
        return res;
    }
}
