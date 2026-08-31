/*****************************************************************
Name:          NM_RequestMentorIntroAction
============================================================
Purpose:       @InvocableMethod for Agentforce. Creates a
               NM_Mentor_Introduction__c record linking the current
               session to the chosen mentor, and marks the session's
               NM_Conversation__c as mentor-requested.
               Guards against duplicate introductions.
               Validates email format before inserting.

               NMDH-8 DEFECT FIX (v2.0): the agent conversation does
               not pre-create an NM_Conversation__c and has no session
               key to look one up, so the original lookup-miss path
               returned success=false and blocked every agent-driven
               intro. This version CREATES a minimal NM_Conversation__c
               on lookup miss (status booleans default to false) instead
               of failing, and is fully bulk-safe: all SOQL and DML are
               executed in single operations outside the request loop.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-8
2.0      Orchestrate  2026-08-31   Updated   NMDH-8 create NM_Conversation__c
                                             on lookup miss; full bulkification
*****************************************************************/
public with sharing class NM_RequestMentorIntroAction {

    // RFC 5321-compliant email pattern (simplified, avoids unicode edge cases)
    private static final String EMAIL_REGEX =
        '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$';

    private static final String MSG_BAD_EMAIL =
        'That email address doesn\'t look right. Could you double-check it and try again?';
    private static final String MSG_DUPLICATE =
        'I\'ve already sent that introduction request for this session.';
    private static final String MSG_SUCCESS =
        'Done. I\'ve queued the introduction and someone will reach out soon.';

    /*****************************************************************
    Purpose:       Input schema consumed by the Agentforce planner.
    *****************************************************************/
    public class Request {
        @InvocableVariable(
            label='Mentor Id'
            description='Id of the NM_Mentor__c record — returned by NM_FindMentorAction.'
            required=true
        )
        public Id mentorId;

        @InvocableVariable(
            label='Requester Email'
            description='Email address the veteran provided for the introduction.'
            required=true
        )
        public String requesterEmail;

        @InvocableVariable(
            label='Conversation Key'
            description='External_Session_Key__c of the current NM_Conversation__c session. Optional — when absent or unmatched, a new session record is created so the introduction is never lost.'
            required=false
        )
        public String conversationKey;
    }

    /*****************************************************************
    Purpose:       Output schema returned to the Agentforce planner.
    *****************************************************************/
    public class Response {
        @InvocableVariable(label='Success' description='True when the intro was created or already existed.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Human-readable result for the agent to relay.')
        public String message;
    }

    /*****************************************************************
    Purpose:       Validates each email, resolves (or creates) the
                   conversation, guards against duplicate intros, then
                   creates NM_Mentor_Introduction__c records and marks
                   NM_Conversation__c.Mentor_Requested__c = true.
                   Fully bulk-safe: no SOQL/DML inside the request loop.
    Parameters:    requests — list of Request (planner may wrap 1..n)
    Returns:       list of Response, index-aligned to requests
    *****************************************************************/
    @InvocableMethod(
        label='Request Mentor Introduction'
        description='Creates an introduction record linking this session to the chosen mentor. Call ONLY after visitor explicitly says yes and provides their email. After success, do not re-prompt for another intro this session.'
        callout=false
    )
    public static List<Response> requestIntro(List<Request> requests) {
        System.debug('Entering NM_RequestMentorIntroAction.requestIntro: requests=' +
                     (requests == null ? 0 : requests.size()));

        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        // Pre-size the result list so we can write results by index.
        List<Boolean> emailValid = new List<Boolean>();
        for (Integer i = 0; i < requests.size(); i++) {
            results.add(new Response());
            emailValid.add(false);
        }

        // -----------------------------------------------------------
        // PASS 1 — validate emails and collect the non-blank keys to
        // look up. Invalid emails are terminal for that request.
        // -----------------------------------------------------------
        Set<String> keysToFind = new Set<String>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            if (String.isBlank(req.requesterEmail) ||
                !Pattern.matches(EMAIL_REGEX, req.requesterEmail)) {
                results[i].success = false;
                results[i].message = MSG_BAD_EMAIL;
                continue;
            }
            emailValid[i] = true;
            if (String.isNotBlank(req.conversationKey)) {
                keysToFind.add(req.conversationKey);
            }
        }

        // -----------------------------------------------------------
        // PASS 2 — single SOQL for existing conversations by key.
        // -----------------------------------------------------------
        Map<String, Id> keyToConvId = new Map<String, Id>();
        if (!keysToFind.isEmpty()) {
            for (NM_Conversation__c c : [
                SELECT Id, External_Session_Key__c
                FROM NM_Conversation__c
                WHERE External_Session_Key__c IN :keysToFind
            ]) {
                // First match wins for a given key.
                if (!keyToConvId.containsKey(c.External_Session_Key__c)) {
                    keyToConvId.put(c.External_Session_Key__c, c.Id);
                }
            }
        }

        // -----------------------------------------------------------
        // PASS 3 — create-on-miss. Build conversations for every valid
        // request whose key is blank or unmatched. Dedupe by token so a
        // repeated real key in the same batch yields ONE new record;
        // blank keys get a per-request token so each gets its own.
        // Single insert outside the loop.
        // -----------------------------------------------------------
        List<NM_Conversation__c> convsToCreate = new List<NM_Conversation__c>();
        List<String> createTokens = new List<String>();   // token per convsToCreate entry
        Map<String, Integer> tokenToCreateIdx = new Map<String, Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            if (!emailValid[i]) {
                continue;
            }
            String key = requests[i].conversationKey;
            Boolean isBlank = String.isBlank(key);
            // Existing real-key match — nothing to create.
            if (!isBlank && keyToConvId.containsKey(key)) {
                continue;
            }
            String token = isBlank ? ('BLANK#' + i) : key;
            if (tokenToCreateIdx.containsKey(token)) {
                continue; // already queued a new record for this token
            }
            NM_Conversation__c newConv = new NM_Conversation__c(
                Started_At__c = DateTime.now()
                // Lead_Captured__c / Mentor_Matched__c / Mentor_Requested__c /
                // QA_Reviewed__c all default to false on insert.
            );
            if (!isBlank) {
                newConv.External_Session_Key__c = key;
            }
            tokenToCreateIdx.put(token, convsToCreate.size());
            convsToCreate.add(newConv);
            createTokens.add(token);
        }

        if (!convsToCreate.isEmpty()) {
            insert convsToCreate;
            // Fold newly-created real-key ids back into the lookup map.
            for (Integer j = 0; j < convsToCreate.size(); j++) {
                String token = createTokens[j];
                if (!token.startsWith('BLANK#')) {
                    keyToConvId.put(token, convsToCreate[j].Id);
                }
            }
        }

        // -----------------------------------------------------------
        // PASS 4 — resolve the conversation Id for each valid request.
        // -----------------------------------------------------------
        List<Id> convIdPerReq = new List<Id>();
        Set<Id> allConvIds = new Set<Id>();
        Set<Id> allMentorIds = new Set<Id>();
        for (Integer i = 0; i < requests.size(); i++) {
            if (!emailValid[i]) {
                convIdPerReq.add(null);
                continue;
            }
            String key = requests[i].conversationKey;
            Id convId;
            if (String.isBlank(key)) {
                convId = convsToCreate[tokenToCreateIdx.get('BLANK#' + i)].Id;
            } else {
                convId = keyToConvId.get(key);
            }
            convIdPerReq.add(convId);
            allConvIds.add(convId);
            if (requests[i].mentorId != null) {
                allMentorIds.add(requests[i].mentorId);
            }
        }

        // -----------------------------------------------------------
        // PASS 5 — single SOQL duplicate guard across all pairs.
        // -----------------------------------------------------------
        Set<String> existingPairs = new Set<String>();
        if (!allConvIds.isEmpty() && !allMentorIds.isEmpty()) {
            for (NM_Mentor_Introduction__c x : [
                SELECT Conversation__c, Mentor__c
                FROM NM_Mentor_Introduction__c
                WHERE Conversation__c IN :allConvIds
                AND Mentor__c IN :allMentorIds
            ]) {
                existingPairs.add(x.Conversation__c + '|' + x.Mentor__c);
            }
        }

        // -----------------------------------------------------------
        // PASS 6 — build intros + conversation flag updates. In-batch
        // dedupe so two identical requests in one call create one intro.
        // Single insert + single update outside the loop.
        // -----------------------------------------------------------
        List<NM_Mentor_Introduction__c> introsToInsert = new List<NM_Mentor_Introduction__c>();
        List<Integer> introReqIndex = new List<Integer>(); // maps intro -> request index
        Set<Id> convIdsToMark = new Set<Id>();
        Set<String> seenPairsThisBatch = new Set<String>();

        for (Integer i = 0; i < requests.size(); i++) {
            if (!emailValid[i]) {
                continue;
            }
            Id convId = convIdPerReq[i];
            Id mentorId = requests[i].mentorId;
            String pairKey = convId + '|' + mentorId;

            if (existingPairs.contains(pairKey) || seenPairsThisBatch.contains(pairKey)) {
                // Already exists (in org or earlier in this batch) — success, no new record.
                results[i].success = true;
                results[i].message = MSG_DUPLICATE;
                continue;
            }

            seenPairsThisBatch.add(pairKey);
            introsToInsert.add(new NM_Mentor_Introduction__c(
                Conversation__c    = convId,
                Mentor__c          = mentorId,
                Requester_Email__c = requests[i].requesterEmail,
                Status__c          = 'Pending',
                Introduced_At__c   = DateTime.now()
            ));
            introReqIndex.add(i);
            convIdsToMark.add(convId);
        }

        if (!introsToInsert.isEmpty()) {
            insert introsToInsert;
            for (Integer k = 0; k < introReqIndex.size(); k++) {
                Integer reqIdx = introReqIndex[k];
                results[reqIdx].success = true;
                results[reqIdx].message = MSG_SUCCESS;
            }
        }

        if (!convIdsToMark.isEmpty()) {
            List<NM_Conversation__c> convUpdates = new List<NM_Conversation__c>();
            for (Id cid : convIdsToMark) {
                convUpdates.add(new NM_Conversation__c(Id = cid, Mentor_Requested__c = true));
            }
            update convUpdates;
        }

        System.debug('Exiting NM_RequestMentorIntroAction.requestIntro: results=' + results.size());
        return results;
    }
}
