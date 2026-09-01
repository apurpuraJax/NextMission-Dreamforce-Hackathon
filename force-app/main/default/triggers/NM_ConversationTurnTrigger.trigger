/*****************************************************************
Name:          NM_ConversationTurnTrigger
============================================================
Purpose:       Persist conversation turns published by the chat widget.

               A guest user cannot update records. Salesforce blocks it at
               the licence level, so the widget's upsert silently no-opped
               on every turn after the first and the transcript froze at one
               turn. Database.upsert with allOrNone=false swallowed the
               failure and the call still returned HTTP 200.

               The widget now publishes NM_Conversation_Turn__e and this
               trigger does the DML. Platform event triggers run as the
               Automated Process user, which can update.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-01  Created   NMDH-19
*****************************************************************/
trigger NM_ConversationTurnTrigger on NM_Conversation_Turn__e (after insert) {

    // Last event wins per session. The widget sends the cumulative transcript
    // every turn, so the newest event is always the most complete one.
    Map<String, NM_Conversation__c> bySessionKey = new Map<String, NM_Conversation__c>();

    for (NM_Conversation_Turn__e evt : Trigger.new) {
        if (String.isBlank(evt.Session_Key__c)) { continue; }

        NM_Conversation__c conv = new NM_Conversation__c(
            External_Session_Key__c = evt.Session_Key__c
        );
        if (evt.Transcript__c       != null) { conv.Transcript__c       = evt.Transcript__c; }
        if (evt.Branch__c           != null) { conv.Branch__c           = evt.Branch__c; }
        if (evt.Specialty_Code__c   != null) { conv.Specialty_Code__c   = evt.Specialty_Code__c; }
        if (evt.Cluster_Key__c      != null) { conv.Cluster_Key__c      = evt.Cluster_Key__c; }
        if (evt.Source_URL__c       != null) { conv.Source_URL__c       = evt.Source_URL__c; }
        if (evt.Message_Count__c    != null) { conv.Message_Count__c    = evt.Message_Count__c.intValue(); }
        if (evt.Mentor_Requested__c != null) { conv.Mentor_Requested__c = evt.Mentor_Requested__c; }
        if (evt.Mentor_Matched__c   != null) { conv.Mentor_Matched__c   = evt.Mentor_Matched__c; }

        bySessionKey.put(evt.Session_Key__c, conv);
    }

    if (bySessionKey.isEmpty()) { return; }

    // Stamp Started_At only on rows that do not exist yet.
    Set<String> existing = new Set<String>();
    for (NM_Conversation__c c : [
        SELECT External_Session_Key__c
        FROM   NM_Conversation__c
        WHERE  External_Session_Key__c IN :bySessionKey.keySet()
    ]) {
        existing.add(c.External_Session_Key__c);
    }
    for (String k : bySessionKey.keySet()) {
        if (!existing.contains(k)) { bySessionKey.get(k).Started_At__c = System.now(); }
    }

    // allOrNone = true. A swallowed failure here is exactly how transcripts
    // went missing; let it throw so it surfaces in the event replay logs.
    Database.upsert(bySessionKey.values(), NM_Conversation__c.External_Session_Key__c, true);
}
