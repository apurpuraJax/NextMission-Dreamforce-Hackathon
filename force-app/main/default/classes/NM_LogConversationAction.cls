/*****************************************************************
Name:          NM_LogConversationAction
============================================================
Purpose:       Invocable action for the Next Mission agent.
               Upserts NM_Conversation__c on External_Session_Key__c
               so the agent can log progress at the end of each major
               topic turn. sessionKey is the only required field;
               all others are optional — pass only what is known.

               Started_At__c is set on create only. Subsequent calls
               with the same sessionKey update other fields without
               overwriting the original start timestamp.

               Bulk-safe: one SOQL outside the loop to detect
               existing records, one DML (upsert) outside the loop.
============================================================
History
-------
VERSION  AUTHOR              DATE         DETAIL    DESCRIPTION
1.0      Revecast Orch.      2026-08-29   Created   NMDH-9
*****************************************************************/
public with sharing class NM_LogConversationAction {

    public class Input {
        @InvocableVariable(required=true label='Session Key'
            description='External session key — uniquely identifies this conversation. Required.')
        public String sessionKey;

        @InvocableVariable(label='Branch'
            description='Military branch as stated by the visitor (e.g. Army, Navy). Optional.')
        public String branch;

        @InvocableVariable(label='Specialty Code'
            description='Military specialty code (MOS, AFSC, Rate, etc.). Optional.')
        public String specialtyCode;

        @InvocableVariable(label='Cluster Key'
            description='Civilian skill cluster key resolved by the lookup action. Optional.')
        public String clusterKey;

        @InvocableVariable(label='Message Count'
            description='Running count of messages exchanged so far. Optional.')
        public Integer messageCount;

        @InvocableVariable(label='Transcript'
            description='Conversation transcript so far. Optional.')
        public String transcript;

        @InvocableVariable(label='Mentor Requested'
            description='True if the veteran has requested a mentor introduction. Optional.')
        public Boolean mentorRequested;

        @InvocableVariable(label='Mentor Matched'
            description='True if a mentor has been matched. Optional.')
        public Boolean mentorMatched;
    }

    public class Response {
        @InvocableVariable(label='Success'
            description='True if the upsert succeeded.')
        public Boolean success;

        @InvocableVariable(label='Conversation Id'
            description='Salesforce Id of the NM_Conversation__c record.')
        public Id conversationId;

        @InvocableVariable(label='Message'
            description='Human-readable outcome or error description.')
        public String message;
    }

    @InvocableMethod(
        label='Log Conversation'
        description='Log conversation progress to the session sink record. Call at the end of each major topic turn.'
    )
    public static List<Response> logConversation(List<Input> inputs) {

        // ── Pass 1: validate inputs; collect valid session keys ────────────
        List<Response> responses = new List<Response>();
        Set<String>    sessionKeys  = new Set<String>();
        List<Integer>  validIndices = new List<Integer>();

        for (Integer i = 0; i < inputs.size(); i++) {
            Input inp = inputs[i];
            if (String.isBlank(inp.sessionKey)) {
                Response r = new Response();
                r.success = false;
                r.message = 'sessionKey is required.';
                responses.add(r);
            } else {
                sessionKeys.add(inp.sessionKey);
                validIndices.add(i);
                responses.add(null); // placeholder — replaced in Pass 3
            }
        }

        if (sessionKeys.isEmpty()) {
            return responses;
        }

        // ── SOQL: detect existing records (1 query, outside any loop) ─────
        Map<String, Id> existingByKey = new Map<String, Id>();
        for (NM_Conversation__c existing : [
            SELECT Id, External_Session_Key__c
            FROM   NM_Conversation__c
            WHERE  External_Session_Key__c IN :sessionKeys
        ]) {
            existingByKey.put(existing.External_Session_Key__c, existing.Id);
        }

        // ── Pass 2: build records for upsert ──────────────────────────────
        List<NM_Conversation__c> toUpsert = new List<NM_Conversation__c>();
        for (Integer idx : validIndices) {
            Input inp = inputs[idx];
            NM_Conversation__c conv = new NM_Conversation__c(
                External_Session_Key__c = inp.sessionKey
            );

            // Set Started_At__c on create only — never overwrite
            if (!existingByKey.containsKey(inp.sessionKey)) {
                conv.Started_At__c = DateTime.now();
            }

            // Optional fields — only assign when caller provides a value
            if (inp.branch          != null) { conv.Branch__c           = inp.branch; }
            if (inp.specialtyCode   != null) { conv.Specialty_Code__c   = inp.specialtyCode; }
            if (inp.clusterKey      != null) { conv.Cluster_Key__c      = inp.clusterKey; }
            if (inp.messageCount    != null) { conv.Message_Count__c    = inp.messageCount; }
            if (inp.transcript      != null) { conv.Transcript__c       = inp.transcript; }
            if (inp.mentorRequested != null) { conv.Mentor_Requested__c = inp.mentorRequested; }
            if (inp.mentorMatched   != null) { conv.Mentor_Matched__c   = inp.mentorMatched; }

            toUpsert.add(conv);
        }

        // ── DML: upsert on external ID (1 DML, outside any loop) ─────────
        List<Database.UpsertResult> upsertResults =
            Database.upsert(toUpsert, NM_Conversation__c.External_Session_Key__c, false);

        // ── Pass 3: map upsert outcomes back to responses ─────────────────
        for (Integer i = 0; i < validIndices.size(); i++) {
            Integer              idx = validIndices[i];
            Database.UpsertResult ur = upsertResults[i];
            Response r               = new Response();

            if (ur.isSuccess()) {
                r.success        = true;
                r.conversationId = ur.getId();
                r.message        = ur.isCreated() ? 'Conversation created.' : 'Conversation updated.';
            } else {
                r.success = false;
                r.message = ur.getErrors()[0].getMessage();
            }
            responses.set(idx, r);
        }

        return responses;
    }
}