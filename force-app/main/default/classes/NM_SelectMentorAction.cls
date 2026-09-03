/*****************************************************************
Name:          NM_SelectMentorAction
============================================================
Purpose:       Resolve what a veteran SAID into which mentor they
               meant, in Apex rather than in the model.

               Find Mentor now returns a shortlist so the person
               chooses instead of accepting someone chosen for them.
               That only helps if the choice is honoured exactly.
               Asking the model to index into a list is the same
               class of thing as asking it not to invent a salary:
               it works until it does not, and the failure is
               invisible because the wrong mentor still reads fine.

               So the ordinal and the name matching happen here. An
               ambiguous answer is reported as ambiguous rather than
               guessed at, because introducing someone to the wrong
               person is not a small error.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, human-in-the-loop
*****************************************************************/
public with sharing class NM_SelectMentorAction {

    public class Request {
        @InvocableVariable(
            label='Mentor Option Ids'
            description='The Mentor Option Ids string exactly as Find Mentor returned it. Do not reorder or edit it.'
            required=true)
        public String mentorOptionIds;

        @InvocableVariable(
            label='Recommended Mentor Id'
            description='The mentor already recommended. Returned unchanged when the choice cannot be resolved, so a failed resolve never blanks the mentor.')
        public String recommendedMentorId;

        @InvocableVariable(
            label='What The Veteran Said'
            description='Their choice in their own words, passed through verbatim. For example "the second one", "Alex", or "2".'
            required=true)
        public String choice;
    }

    public class Response {
        @InvocableVariable(label='Resolved' description='True when the choice matched exactly one mentor.')
        public Boolean resolved;

        @InvocableVariable(label='Mentor Id' description='Pass to Request Mentor Intro. Only set when Resolved is true.')
        public String mentorId;

        @InvocableVariable(label='Mentor Name')
        public String mentorName;

        @InvocableVariable(
            label='Message'
            description='Set when the choice could not be resolved. Ask them again using this wording rather than picking one yourself.')
        public String message;
    }

    /*
     * Purpose:    Turn a spoken choice into exactly one mentor, or into an
     *             honest "say that again".
     */
    @InvocableMethod(
        label='Select Mentor'
        description='Resolve which mentor from the shortlist the veteran chose. NEVER choose on their behalf: if Resolved is false, ask them again.'
        callout=false)
    public static List<Response> selectMentor(List<Request> requests) {
        System.debug('Entering NM_SelectMentorAction.selectMentor');

        // Gather every candidate Id across the batch for one query.
        List<List<Id>> perRequest = new List<List<Id>>();
        Set<Id> allIds = new Set<Id>();
        for (Request req : requests) {
            List<Id> ids = new List<Id>();
            if (req != null && String.isNotBlank(req.mentorOptionIds)) {
                for (String raw : req.mentorOptionIds.split(';')) {
                    String v = raw.trim();
                    if (String.isBlank(v)) continue;
                    try { Id parsed = (Id) v; ids.add(parsed); allIds.add(parsed); }
                    catch (Exception e) { /* not an Id, ignore it */ }
                }
            }
            perRequest.add(ids);
        }

        Map<Id, NM_Mentor__c> byId = allIds.isEmpty()
            ? new Map<Id, NM_Mentor__c>()
            : new Map<Id, NM_Mentor__c>([
                SELECT Id, Name FROM NM_Mentor__c WHERE Id IN :allIds ]);

        List<Response> results = new List<Response>();
        for (Integer n = 0; n < requests.size(); n++) {
            Request req = requests[n];
            Response res = resolveOne(perRequest[n], byId, req == null ? null : req.choice);
            // Never hand back a blank mentor. The first version set mentorId to
            // null whenever it could not resolve, the agent stored that null
            // over a perfectly good mentor, and two regression conversations
            // ended with "the system could not identify which mentor". An
            // unresolved choice must degrade to the recommendation, never to
            // nothing, and resolved=false still tells the agent to ask again.
            if (res.resolved != true && req != null
                    && String.isNotBlank(req.recommendedMentorId)) {
                res.mentorId = req.recommendedMentorId;
            }
            results.add(res);
        }

        System.debug('Exiting NM_SelectMentorAction.selectMentor: results=' + results.size());
        return results;
    }

    /*
     * Purpose:    Match one spoken choice against one shortlist.
     *             Ordinal first, then name. Anything that matches more than
     *             one, or none, comes back unresolved.
     */
    @TestVisible
    private static Response resolveOne(List<Id> ids, Map<Id, NM_Mentor__c> byId, String choice) {
        Response res = new Response();
        res.resolved = false;

        List<NM_Mentor__c> options = new List<NM_Mentor__c>();
        for (Id i : ids) if (byId.containsKey(i)) options.add(byId.get(i));

        if (options.isEmpty()) {
            res.message = 'I have lost track of that shortlist. Let me look up mentors again.';
            return res;
        }
        if (String.isBlank(choice)) {
            res.message = 'Which of those would you like me to introduce you to?';
            return res;
        }

        String said = choice.toLowerCase();

        // 1. An ordinal, however it was phrased.
        Integer picked = ordinalIn(said, options.size());
        if (picked != null) return hit(res, options[picked - 1]);

        // 2. A name. Match on the whole name or on the first word of it, so
        //    "Alex" resolves when the record says "Alex R.".
        List<NM_Mentor__c> nameHits = new List<NM_Mentor__c>();
        for (NM_Mentor__c m : options) {
            if (String.isBlank(m.Name)) continue;
            String full = m.Name.toLowerCase();
            Boolean hit = said.contains(full);
            if (!hit) {
                // Any part of the name. Someone answering "Whitfield" has
                // chosen just as clearly as someone answering "Sam".
                for (String part : full.split(' ')) {
                    String w = part.replaceAll('[^a-z]', '');
                    if (w.length() > 2 && Pattern.compile('\\b' + w + '\\b').matcher(said).find()) {
                        hit = true;
                        break;
                    }
                }
            }
            if (hit) nameHits.add(m);
        }
        if (nameHits.size() == 1) return hit(res, nameHits[0]);

        // Two people called Alex, or nothing recognisable. Either way, ask.
        res.message = nameHits.size() > 1
            ? 'More than one of those matches that name. Could you tell me the number instead?'
            : 'I want to be sure I introduce you to the right person. Which number would you like?';
        return res;
    }

    private static Response hit(Response res, NM_Mentor__c m) {
        res.resolved   = true;
        res.mentorId   = String.valueOf(m.Id);
        res.mentorName = m.Name;
        return res;
    }

    /*
     * Purpose:    Find a 1-based position in what someone said. Handles digits
     *             and the words people actually use, including "last".
     *             Returns null when there is no position in it, so a name like
     *             "Warren" is never read as a number.
     */
    @TestVisible
    private static Integer ordinalIn(String said, Integer count) {
        // ORDER MATTERS and a Map will not do. "the second one" contains the
        // word "one", so a cardinal checked first resolves it to mentor 1 and
        // introduces the veteran to the wrong person. Ordinals are checked
        // before cardinals, and every term is matched on a word boundary so
        // "someone" and "twofold" cannot count as a choice.
        List<String> terms = new List<String>{
            'first', '1st', 'second', '2nd', 'third', '3rd', 'last',
            'one', 'two', 'three'
        };
        Map<String, Integer> value = new Map<String, Integer>{
            'first' => 1, '1st' => 1, 'one' => 1,
            'second' => 2, '2nd' => 2, 'two' => 2,
            'third' => 3, '3rd' => 3, 'three' => 3,
            'last' => count
        };
        for (String t : terms) {
            if (Pattern.compile('\\b' + t + '\\b').matcher(said).find()) {
                Integer v = value.get(t);
                return (v != null && v >= 1 && v <= count) ? v : null;
            }
        }
        // A bare digit, but only when the message is essentially just that.
        String bare = said.replaceAll('[^0-9]', '');
        if (bare.length() == 1 && said.replaceAll('[^a-z0-9]', '').length() <= 12) {
            Integer v = Integer.valueOf(bare);
            if (v >= 1 && v <= count) return v;
        }
        return null;
    }
}
