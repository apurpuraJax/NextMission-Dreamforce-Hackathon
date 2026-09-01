/*****************************************************************
Name:    NM_AgentController
Purpose: AuraEnabled proxy for the Agentforce External Client API.
         Exposes startSession / sendMessage / logTurn to NM_ChatWidget LWC.
         Conversation persistence (logTurn) must be called unconditionally
         in the LWC finally block so failed turns are also recorded.
History
-------
VERSION  AUTHOR          DATE        DETAIL
1.0      Orchestrate     2026-08-31  NMDH-16 initial build
2.0      Orchestrate     2026-08-31  NMDH-15/S14 — repoint to modern Agent API
                                     (Named Credential NM_AgentAPI ->
                                     https://api.salesforce.com/einstein/ai-agent/v1).
                                     Streaming session payload, UUID session key,
                                     ai-agent/v1 response parsing. Return types
                                     (StartSessionResult / SendMessageResult) and
                                     logTurn preserved: the NM_ChatWidget LWC and
                                     CONTEXT.md client-owned persistence depend on them.
*****************************************************************/
public with sharing class NM_AgentController {

    // Bot Definition Id from Custom Label (set in S13). Never hardcode the id.
    private static final String  AGENT_ID   = Label.NM_Bot_Definition_Id;
    // Named Credential base URL already includes /einstein/ai-agent/v1 (see the
    // NM_AgentAPI Named Credential metadata). Paths below are relative to that base.
    private static final String  NAMED_CRED = 'callout:NM_AgentAPI';
    private static final Integer TIMEOUT_MS = 30000;

    // ── Result & Request inner classes ─────────────────────────────────────

    public class StartSessionResult {
        @AuraEnabled public String sessionId;
        @AuraEnabled public String sessionKey;
    }

    public class SendMessageResult {
        @AuraEnabled public String  replyText;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  errorMessage;
    }

    public class LogTurnRequest {
        @AuraEnabled public String  sessionKey;
        @AuraEnabled public String  transcript;
        @AuraEnabled public String  branch;
        @AuraEnabled public String  specialtyCode;
        @AuraEnabled public String  clusterKey;
        @AuraEnabled public String  sourceUrl;
        @AuraEnabled public Integer messageCount;
        @AuraEnabled public Boolean mentorRequested;
        @AuraEnabled public Boolean mentorMatched;
    }

    // ── Public AuraEnabled methods ──────────────────────────────────────────

    /*
     * Purpose:    Start a new Agentforce session and return sessionId + sessionKey.
     * Parameters: sourceUrl - the page URL to embed as a conversation variable.
     * Returns:    StartSessionResult with sessionId (agent token) and sessionKey (upsert key).
     */
    @AuraEnabled
    public static StartSessionResult startSession(String sourceUrl) {
        System.debug('Entering startSession: sourceUrl=' + sourceUrl);
        try {
            String sessionKey = generateSessionKey();
            Map<String, Object> body = new Map<String, Object>{
                'externalSessionKey' => sessionKey,
                'instanceConfig' => new Map<String, Object>{
                    'endpoint' => URL.getOrgDomainUrl().toExternalForm()
                },
                'featureSupport' => 'Streaming',
                'streamingCapabilities' => new Map<String, Object>{
                    'chunkTypes' => new List<String>{ 'Text' }
                },
                'bypassUser' => true,
                'variables' => new List<Object>{
                    new Map<String, Object>{'name'=>'sourceUrl',  'type'=>'Text','value'=>(sourceUrl==null?'':sourceUrl)},
                    new Map<String, Object>{'name'=>'sessionKey', 'type'=>'Text','value'=>sessionKey}
                }
            };
            HttpResponse resp = doPost('/agents/' + AGENT_ID + '/sessions', JSON.serialize(body));
            if (resp.getStatusCode() == 200 || resp.getStatusCode() == 201) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
                StartSessionResult result = new StartSessionResult();
                result.sessionId  = (String) parsed.get('sessionId');
                result.sessionKey = sessionKey;
                System.debug('Exiting startSession: sessionId=' + result.sessionId);
                return result;
            }
            throw new AuraHandledException('Session creation failed (' + resp.getStatusCode() + '): ' + resp.getBody());
        } catch (AuraHandledException e) { throw e; }
        catch (Exception e) { throw new AuraHandledException('Could not start session: ' + e.getMessage()); }
    }

    /*
     * Purpose:    Send a user message to the active agent session.
     * Parameters: sessionId  - Agentforce clientSessionId from startSession.
     *             text       - The user's message text.
     *             sourceUrl  - Reserved for future use; pass the page URL.
     * Returns:    SendMessageResult with replyText, success flag, and errorMessage.
     */
    @AuraEnabled
    public static SendMessageResult sendMessage(String sessionId, String text, String sourceUrl) {
        System.debug('Entering sendMessage: sessionId=' + sessionId + ', text=' + text);
        try {
            Map<String, Object> body = new Map<String, Object>{
                'message' => new Map<String, Object>{
                    'sequenceId' => DateTime.now().getTime(),
                    'type'       => 'Text',
                    'text'       => text
                },
                'variables' => new List<Object>{
                    new Map<String, Object>{'name'=>'sourceUrl',  'type'=>'Text','value'=>(sourceUrl==null?'':sourceUrl)},
                    new Map<String, Object>{'name'=>'sessionKey', 'type'=>'Text','value'=>(sessionId==null?'':sessionId)}
                }
            };
            HttpResponse resp = doPost('/sessions/' + sessionId + '/messages', JSON.serialize(body));
            SendMessageResult result = new SendMessageResult();
            if (resp.getStatusCode() == 200) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
                result.replyText = extractReplyText(parsed);
                result.success   = true;
            } else {
                result.success      = false;
                result.errorMessage = 'Agent error (' + resp.getStatusCode() + ')';
            }
            System.debug('Exiting sendMessage: success=' + result.success);
            return result;
        } catch (AuraHandledException e) { throw e; }
        catch (Exception e) { throw new AuraHandledException('Message send failed: ' + e.getMessage()); }
    }

    /*
     * Purpose:    Upsert a NM_Conversation__c record for conversation persistence.
     *             Must be called in the LWC finally block so it fires on every turn,
     *             including failed agent turns. DML is delegated to the inner
     *             ConversationWriter (without sharing) to support guest user context.
     * Parameters: req - LogTurnRequest with sessionKey (required) and optional fields.
     */
    @AuraEnabled
    public static void logTurn(LogTurnRequest req) {
        System.debug('Entering logTurn: sessionKey=' + req.sessionKey);
        try {
            if (String.isBlank(req.sessionKey)) {
                throw new AuraHandledException('sessionKey is required for logTurn.');
            }
            ConversationWriter writer = new ConversationWriter();
            Boolean isNew = writer.countExisting(req.sessionKey) == 0;
            NM_Conversation__c conv = new NM_Conversation__c(External_Session_Key__c = req.sessionKey);
            if (isNew)                  { conv.Started_At__c       = DateTime.now(); }
            if (req.transcript      != null) { conv.Transcript__c       = req.transcript; }
            if (req.branch          != null) { conv.Branch__c           = req.branch; }
            if (req.specialtyCode   != null) { conv.Specialty_Code__c   = req.specialtyCode; }
            if (req.clusterKey      != null) { conv.Cluster_Key__c      = req.clusterKey; }
            if (req.sourceUrl       != null) { conv.Source_URL__c       = req.sourceUrl; }
            if (req.messageCount    != null) { conv.Message_Count__c    = req.messageCount; }
            if (req.mentorRequested != null) { conv.Mentor_Requested__c = req.mentorRequested; }
            if (req.mentorMatched   != null) { conv.Mentor_Matched__c   = req.mentorMatched; }
            writer.upsertRecord(conv);
            System.debug('Exiting logTurn: upsert complete, isNew=' + isNew);
        } catch (AuraHandledException e) { throw e; }
        catch (Exception e) { throw new AuraHandledException('logTurn failed: ' + e.getMessage()); }
    }

    // ── Private helpers ─────────────────────────────────────────────────────

    private static HttpResponse doPost(String path, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CRED + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(body);
        req.setTimeout(TIMEOUT_MS);
        return new Http().send(req);
    }

    @TestVisible
    private static String extractReplyText(Map<String, Object> parsed) {
        // ai-agent/v1 returns a "messages" array; concatenate the text of every
        // chunk so multi-part (streamed-then-collated) agent replies come through
        // whole rather than truncated to the first Inform chunk.
        List<Object> messages = (List<Object>) parsed.get('messages');
        if (messages == null || messages.isEmpty()) { return ''; }
        String reply = '';
        for (Object msgObj : messages) {
            reply += chunkText((Map<String, Object>) msgObj);
        }
        return reply;
    }

    /*
     * Purpose:    Pull the text out of a single ai-agent/v1 response message,
     *             tolerating both shapes the API emits: a nested
     *             { "message": { "text": ... } } Map, or a top-level "message"
     *             / "text" String. Returns '' for control messages (SessionEnded,
     *             etc.) that carry no text.
     * Parameters: msg - one element of the response "messages" array.
     * Returns:    the message's text, or '' when the element carries none.
     */
    @TestVisible
    private static String chunkText(Map<String, Object> msg) {
        if (msg == null) { return ''; }
        Object messageVal = msg.get('message');
        if (messageVal instanceof Map<String, Object>) {
            String nested = (String) ((Map<String, Object>) messageVal).get('text');
            if (String.isNotBlank(nested)) { return nested; }
        } else if (messageVal instanceof String && String.isNotBlank((String) messageVal)) {
            return (String) messageVal;
        }
        Object topText = msg.get('text');
        if (topText instanceof String && String.isNotBlank((String) topText)) {
            return (String) topText;
        }
        return '';
    }

    private static String generateSessionKey() {
        Blob key = Crypto.generateAesKey(128);
        return 'nm-' + EncodingUtil.convertToHex(key).substring(0, 24);
    }

    /*
     * Inner class without sharing allows DML in guest user (LWR public site) context.
     * The outer class remains with sharing for HTTP callouts.
     */
    private without sharing class ConversationWriter {
        Integer countExisting(String sessionKey) {
            return [SELECT COUNT() FROM NM_Conversation__c WHERE External_Session_Key__c = :sessionKey];
        }
        void upsertRecord(NM_Conversation__c conv) {
            Database.upsert(conv, NM_Conversation__c.External_Session_Key__c, false);
        }
    }
}
