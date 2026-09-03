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
        currentSessionKey = sessionId;
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
                result.replyText =
                    applyDistressNet(text, applyWageNet(extractReplyText(parsed)));
                watchMentorClaims(result.replyText);
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

    // ── Wage verification net ───────────────────────────────────────────────
    //
    // The agent was asked to present the finished wage lines verbatim and did
    // not. It rewrote them and generated its own plausible BLS-looking numbers:
    // Warehouse Operations Manager came back as $98,560 when the stored figure
    // is $102,010, Supply Chain Analyst as $67,190 against a real $80,880. Every
    // figure in the reply was invented, and it read perfectly.
    //
    // No instruction fixes this reliably, and a wrong salary is the most harmful
    // thing this product can output: someone takes or leaves a job on it. So
    // every figure that reaches a veteran is checked against NM_Wage__c here,
    // and a reply containing a number we do not hold is REPLACED with one built
    // from the stored data rather than patched.

    @TestVisible
    private static final String WAGE_PREAMBLE =
        'Here is what the Bureau of Labor Statistics reports for those roles nationally:';

    @TestVisible
    private static final String WAGE_CLOSER =
        'These are national figures, so pay varies by where you live and who you work for.';

    /*
     * Purpose:    Pull every dollar amount out of a reply, as plain integers.
     */
    @TestVisible
    private static Set<Decimal> figuresIn(String text) {
        Set<Decimal> found = new Set<Decimal>();
        if (String.isBlank(text)) return found;
        Matcher m = Pattern.compile('\\$\\s?([0-9][0-9,]{2,})').matcher(text);
        while (m.find()) {
            try {
                found.add(Decimal.valueOf(m.group(1).replace(',', '')));
            } catch (Exception e) {
                // A malformed amount is not a figure we can verify either way.
            }
        }
        return found;
    }

    /*
     * Purpose:    Every wage number we actually hold. Small table, read once.
     */
    private static Set<Decimal> heldFigures {
        get {
            if (heldFigures == null) {
                heldFigures = new Set<Decimal>();
                // Same reason NM_GetWagesAction is without sharing: secure guest
                // access hides these public BLS rows from a site visitor.
                for (NM_Wage__c w : new WageReader().all()) {
                    if (w.Median_Annual__c != null) heldFigures.add(w.Median_Annual__c);
                    if (w.Pct10_Annual__c  != null) heldFigures.add(w.Pct10_Annual__c);
                    if (w.Pct90_Annual__c  != null) heldFigures.add(w.Pct90_Annual__c);
                }
            }
            return heldFigures;
        }
        set;
    }

    /*
     * Purpose:    Find the occupation titles this reply is talking about, so we
     *             can rebuild an accurate answer for exactly those roles.
     */
    @TestVisible
    private static List<String> titlesIn(String text) {
        List<String> hits = new List<String>();
        if (String.isBlank(text)) return hits;
        String lower = text.toLowerCase();
        for (String title : NM_GetWagesAction.knownTitles()) {
            if (lower.contains(title.toLowerCase())) hits.add(title);
        }
        return hits;
    }

    /*
     * Purpose:    Guarantee that no invented salary reaches a veteran.
     * Returns:    the agent's reply when every figure checks out, otherwise a
     *             reply rebuilt from stored BLS data.
     */
    @TestVisible
    private static String applyWageNet(String agentReply) {
        try {
            return checkWages(agentReply);
        } catch (Exception e) {
            // A net that breaks the conversation is worse than no net. If we
            // cannot verify (missing access, a query problem), say nothing about
            // pay rather than pass through a figure we have not checked.
            System.debug(LoggingLevel.WARN, 'Wage net could not run: ' + e.getMessage());
            if (!figuresIn(agentReply).isEmpty()) {
                logGuardrail('Wage', 'Unverifiable', 'Net could not run: ' + e.getMessage());
            }
            return figuresIn(agentReply).isEmpty() ? agentReply
                : 'I want to be sure any pay figure I give you is the real Bureau of Labor '
                + 'Statistics number, and I could not check that one just now. Ask me again '
                + 'and I will pull it properly.';
        }
    }

    private static String checkWages(String agentReply) {
        Set<Decimal> shown = figuresIn(agentReply);
        if (shown.isEmpty()) return agentReply;

        Set<Decimal> held = heldFigures;
        List<Decimal> invented = new List<Decimal>();
        for (Decimal d : shown) {
            if (!held.contains(d)) invented.add(d);
        }
        if (invented.isEmpty()) return agentReply;

        System.debug(LoggingLevel.WARN,
            'Agent stated wage figures we do not hold: ' + invented);

        String inventedDetail = 'Figures not held: ' + invented;

        List<String> titles = titlesIn(agentReply);
        if (titles.isEmpty()) {
            logGuardrail('Wage', 'Withheld', inventedDetail + ' (no roles identifiable)');
            // We cannot tell which roles it meant, so we cannot rebuild. Say
            // nothing about pay rather than repeat a number we cannot stand behind.
            return 'I do not want to give you a pay figure I cannot stand behind, and I '
                 + 'got that one wrong. Ask me again which roles you want the pay for and '
                 + 'I will pull the Bureau of Labor Statistics numbers properly.';
        }

        NM_GetWagesAction.Request req = new NM_GetWagesAction.Request();
        req.occupationTitles = String.join(titles, ';');
        NM_GetWagesAction.Response w =
            NM_GetWagesAction.getWages(new List<NM_GetWagesAction.Request>{ req })[0];

        if (w == null || w.found != true || String.isBlank(w.wages)) {
            logGuardrail('Wage', 'Withheld', inventedDetail + ' (no stored figures for: '
                + String.join(titles, '; ') + ')');
            return 'I do not have Bureau of Labor Statistics figures for those roles, and '
                 + 'I would rather tell you that than guess at a number you might plan '
                 + 'around.';
        }
        logGuardrail('Wage', 'Rebuilt', inventedDetail + ' (rebuilt for: '
            + String.join(titles, '; ') + ')');
        return WAGE_PREAMBLE + '\n\n' + w.wages + '\n\n' + WAGE_CLOSER;
    }

    /*
     * Purpose:    Read the public BLS wage rows in a context guest users can
     *             actually see. Nothing here is private; it is federal data.
     */
    private without sharing class WageReader {
        // Inner classes cannot have static methods, so this is an instance method.
        private List<NM_Wage__c> all() {
            return [ SELECT Median_Annual__c, Pct10_Annual__c, Pct90_Annual__c
                     FROM   NM_Wage__c
                     WHERE  Median_Annual__c != null ];
        }
    }

    // ── Distress safety net ─────────────────────────────────────────────────
    //
    // A veteran who says they are drinking too much and cannot hold a job gets
    // "Sorry, I can't assist with that." from the PLATFORM, not from our agent.
    // It is Agentforce's own refusal, it fires before our instructions are
    // consulted, and no wording change moves it: measured 5 times out of 5 with
    // an explicit instruction in place forbidding exactly that reply.
    //
    // That is the worst answer this product can give. Someone took a risk
    // telling us why their career stalled and got turned away. So the guarantee
    // lives here instead of in a prompt, where it cannot be talked out of.
    //
    // This does not bypass a safety control. It replaces a cold refusal with the
    // response the situation actually calls for: take it seriously in two
    // sentences, name the Veterans Crisis Line, and leave the door open. We do
    // not diagnose, counsel, or ask them to explain.

    @TestVisible
    private static final String CRISIS_REPLY =
        'That sounds genuinely hard, and I am glad you said it. The Veterans Crisis Line ' +
        'is free and confidential, and you do not have to be in crisis to use it: dial 988 ' +
        'then press 1, or text 838255. Whenever you want to pick the career side back up, ' +
        'I am here and we can go at whatever pace suits you.';

    // Deliberately narrow. These are phrases someone uses about THEMSELVES when
    // they are struggling. Broad words like 'stress' or 'hard' would fire on
    // ordinary career talk and bury a real disclosure in noise.
    private static final List<String> DISTRESS_MARKERS = new List<String>{
        'drinking too much', 'drink too much', 'drinking a lot', 'using again',
        'cannot cope', 'can not cope', 'cant cope', 'can t cope',
        'hopeless', 'suicidal', 'kill myself', 'end it all', 'no reason to',
        'cannot hold a job', 'can not hold a job', 'cant hold a job', 'can t hold a job',
        'struggling since', 'really struggling', 'am struggling',
        'depressed', 'depression', 'ptsd is', 'not doing well', 'falling apart',
        'no one cares', 'nothing matters'
    };

    /*
     * Purpose:    True when the veteran's own message signals they are
     *             struggling, rather than merely mentioning a hard topic.
     */
    @TestVisible
    private static Boolean signalsDistress(String text) {
        if (String.isBlank(text)) return false;
        String t = text.toLowerCase().replaceAll('[^a-z0-9 ]', ' ').replaceAll(' +', ' ');
        for (String marker : DISTRESS_MARKERS) {
            if (t.contains(marker)) return true;
        }
        return false;
    }

    /*
     * Purpose:    Decide what the veteran actually sees.
     * Returns:    the crisis reply when they disclosed distress and the agent
     *             either refused or answered without pointing anywhere useful;
     *             otherwise the agent's own reply, untouched.
     */
    @TestVisible
    private static String applyDistressNet(String userText, String agentReply) {
        if (!signalsDistress(userText)) return agentReply;

        String raw = (agentReply == null ? '' : agentReply).toLowerCase();
        if (raw.contains('988') || raw.contains('crisis line')) return agentReply;

        // Strip punctuation before matching. The platform refusal is written
        // "Sorry, I can't assist with that." and an apostrophe-sensitive check
        // silently missed it, so the refusal was APPENDED to the crisis reply
        // instead of replaced by it. Normalise, then match.
        String r = raw.replaceAll('[^a-z0-9 ]', ' ').replaceAll(' +', ' ');
        Boolean refused = String.isBlank(agentReply)
            || r.contains('can t assist') || r.contains('cannot assist')
            || r.contains('can not assist') || r.contains('unable to assist')
            || r.contains('can t help with that') || r.contains('cannot help with that')
            || r.contains('outside my scope') || r.contains('not something i can help');

        // Refused outright, or answered about careers as though they had not
        // spoken. Either way the person comes first.
        // Log the MODEL's behaviour, never the veteran's words.
        logGuardrail('Distress', refused ? 'RefusalReplaced' : 'CrisisPrepended',
            refused ? 'Agent refused or returned nothing to a distress disclosure.'
                    : 'Agent answered about careers without acknowledging the disclosure.');

        return refused ? CRISIS_REPLY : CRISIS_REPLY + '\n\n' + agentReply;
    }

    // A resume runs long and the agent does not need all of it. Two pages of
    // text is comfortably inside this; the cap exists so a pathological file
    // cannot blow the request, not to trim genuine content.
    @TestVisible private static final Integer MAX_RESUME_CHARS = 12000;

    /*
     * Purpose:    Send an uploaded resume to the agent as the veteran's turn.
     *             The FILE never reaches Salesforce. The browser reads it and
     *             sends text only, so we are not storing someone's resume as a
     *             side effect of them asking a question about it.
     * Parameters: sessionId  - Agentforce clientSessionId from startSession.
     *             resumeText - Text already extracted in the browser.
     *             fileName   - Only so the agent can refer to it naturally.
     *             sourceUrl  - The page URL.
     * Returns:    SendMessageResult, exactly as sendMessage does.
     * Note:       Flat String parameters on purpose. The Experience Cloud
     *             webruntime endpoint rejects complex Apex parameter types, which
     *             is the same reason logTurnFlat exists beside logTurn.
     */
    @AuraEnabled
    public static SendMessageResult sendResume(String sessionId, String resumeText,
                                               String fileName, String sourceUrl) {
        System.debug('Entering sendResume: sessionId=' + sessionId
            + ', fileName=' + fileName
            + ', chars=' + (resumeText == null ? 0 : resumeText.length()));

        String cleaned = cleanResumeText(resumeText);
        if (String.isBlank(cleaned)) {
            SendMessageResult empty = new SendMessageResult();
            empty.success      = false;
            empty.errorMessage = 'No readable text could be found in that file.';
            return empty;
        }

        // The marker is what the agent keys its resume handling off. It is
        // stripped before anything is shown, so the veteran never sees it.
        String framed = '[RESUME_UPLOAD] The veteran uploaded a resume'
            + (String.isBlank(fileName) ? '' : ' named ' + fileName.trim())
            + '. Its text follows.\n\n' + cleaned;

        SendMessageResult res = sendMessage(sessionId, framed, sourceUrl);
        System.debug('Exiting sendResume: success=' + (res == null ? null : res.success));
        return res;
    }

    /*
     * Purpose:    Normalise extracted text. PDF extraction produces ragged
     *             whitespace and stray form feeds; left alone they waste the
     *             agent's attention on layout rather than content.
     */
    @TestVisible
    private static String cleanResumeText(String raw) {
        if (String.isBlank(raw)) return null;
        String t = raw.replace('\r\n', '\n').replace('\r', '\n');
        t = t.replaceAll('[\\u000B\\u000C]', '\n');   // vertical tab, form feed
        t = t.replaceAll('[ \\t]+', ' ');                // runs of spaces
        t = t.replaceAll('\n{3,}', '\n\n');             // runs of blank lines
        t = t.trim();
        if (t.length() > MAX_RESUME_CHARS) {
            t = t.substring(0, MAX_RESUME_CHARS);
        }
        return String.isBlank(t) ? null : t;
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
            // Insert-only, one row per turn.
            //
            // A guest user cannot update records AND cannot query them back,
            // even from a without sharing class. Proven at runtime: the SOQL
            // returned nothing while the DUPLICATE_VALUE error named the exact
            // record id it could not see. So there is no read-modify-write
            // available in guest context at all.
            //
            // The widget sends the CUMULATIVE transcript every turn, so the row
            // with the highest Message_Count__c for a session holds the complete
            // conversation. The session key is suffixed per turn to stay within
            // the unique constraint. NMDH-32 collapses these into one row from
            // an admin context.
            ConversationWriter writer = new ConversationWriter();
            Integer turnNo = (req.messageCount == null) ? 0 : req.messageCount;
            NM_Conversation__c conv = new NM_Conversation__c(
                External_Session_Key__c = req.sessionKey + '-t' + String.valueOf(turnNo),
                Started_At__c           = DateTime.now()
            );
            if (req.transcript      != null) { conv.Transcript__c       = req.transcript; }
            if (req.branch          != null) { conv.Branch__c           = req.branch; }
            if (req.specialtyCode   != null) { conv.Specialty_Code__c   = req.specialtyCode; }
            if (req.clusterKey      != null) { conv.Cluster_Key__c      = req.clusterKey; }
            if (req.sourceUrl       != null) { conv.Source_URL__c       = req.sourceUrl; }
            if (req.messageCount    != null) { conv.Message_Count__c    = req.messageCount; }
            if (req.mentorRequested != null) { conv.Mentor_Requested__c = req.mentorRequested; }
            if (req.mentorMatched   != null) { conv.Mentor_Matched__c   = req.mentorMatched; }
            writer.insertRecord(conv);
            System.debug('Exiting logTurn: inserted turn ' + turnNo);
        } catch (AuraHandledException e) { throw e; }
        catch (Exception e) { throw new AuraHandledException('logTurn failed: ' + e.getMessage()); }
    }

    /*
     * Purpose:    Flat-parameter form of logTurn.
     *             The LWC calls THIS one. The LogTurnRequest form takes a custom
     *             Apex type as its parameter, which the Experience Cloud
     *             webruntime Apex endpoint rejects for guest callers with
     *             "The Apex request is invalid" before any Apex runs. That is
     *             why no widget-written transcript ever reached the org.
     *             Primitives marshal cleanly; do not reintroduce a complex
     *             parameter on a method the guest widget calls.
     */
    @AuraEnabled
    public static void logTurnFlat(
        String sessionKey, String transcript, String branch, String specialtyCode,
        String clusterKey, String sourceUrl, Integer messageCount,
        Boolean mentorRequested, Boolean mentorMatched
    ) {
        LogTurnRequest req = new LogTurnRequest();
        req.sessionKey      = sessionKey;
        req.transcript      = transcript;
        req.branch          = branch;
        req.specialtyCode   = specialtyCode;
        req.clusterKey      = clusterKey;
        req.sourceUrl       = sourceUrl;
        req.messageCount    = messageCount;
        req.mentorRequested = mentorRequested;
        req.mentorMatched   = mentorMatched;

        logTurn(req);
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
    /*
     * Purpose:   DML for conversation logging, isolated in a without sharing
     *            class so it works in guest context.
     * Note:      Deliberately does NOT use upsert-by-external-id. That form runs
     *            an implicit match query which guest record visibility blocks, so
     *            every turn after the first was treated as an insert and failed
     *            with DUPLICATE_VALUE on External_Session_Key__c. With
     *            allOrNone=false that error was swallowed and the call still
     *            returned HTTP 200, which is why transcripts silently froze at
     *            one turn. Look the Id up explicitly, then insert or update.
     */
    /* ─── Mentor fabrication watch ──────────────────────────────────────────
     *
     * Measured on the live site: the agent named Alex R., a real mentor, and
     * described them as a paramedic who moved from Army 68W. Alex R. is a
     * Supply Chain Manager in Logistics. It invented a real person's job.
     *
     * This WATCHES rather than rewrites. A net that edits a reply about a named
     * human being needs to be right, and this signal is not precise enough yet
     * to act on: a legitimate reply does not always repeat someone's job title.
     * So it records, and the rate becomes visible instead of assumed. Shipping
     * a corrector on a signal this rough would trade a known problem for an
     * unknown one.
     */
    @TestVisible
    private static void watchMentorClaims(String agentReply) {
        try {
            if (String.isBlank(agentReply)) return;
            String reply = agentReply.toLowerCase();
            for (NM_Mentor__c m : new MentorReader().active()) {
                if (String.isBlank(m.Name) || String.isBlank(m.Civilian_Role__c)) continue;
                if (!reply.contains(m.Name.toLowerCase())) continue;
                if (reply.contains(m.Civilian_Role__c.toLowerCase())) continue;
                logGuardrail('Mentor', 'FabricationSuspected',
                    'Reply names ' + m.Name + ' without their stored role ('
                    + m.Civilian_Role__c + ').');
                return;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Mentor watch failed: ' + e.getMessage());
        }
    }

    private without sharing class MentorReader {
        List<NM_Mentor__c> active() {
            return [ SELECT Name, Civilian_Role__c FROM NM_Mentor__c
                     WHERE Active__c = true LIMIT 200 ];
        }
    }

    /* ─── Guardrail observability ──────────────────────────────────────────
     *
     * The nets used to correct a reply and say nothing. That is worse than it
     * sounds: the QA evaluator grades the stored transcript, and the transcript
     * holds the CORRECTED reply, so every catch was invisible to the grader.
     * The safety net was hiding the model's failure rate from its own builder,
     * and "we have never seen it invent a salary" was true only because nothing
     * was looking.
     *
     * One row per activation, written outside the transcript. It records what
     * the MODEL produced, never what the veteran said, so a distress disclosure
     * is never persisted anywhere.
     */
    @TestVisible
    private static String currentSessionKey;

    @TestVisible
    private static void logGuardrail(String net, String outcome, String detail) {
        try {
            new GuardrailWriter().write(new NM_Guardrail_Event__c(
                Net__c         = net,
                Outcome__c     = outcome,
                Session_Key__c = currentSessionKey,
                Detail__c      = detail == null ? null : detail.abbreviate(2000)
            ));
        } catch (Exception e) {
            // Observability must never cost a veteran their answer. If the row
            // cannot be written, the correction still stands.
            System.debug(LoggingLevel.WARN, 'Guardrail log failed: ' + e.getMessage());
        }
    }

    private without sharing class GuardrailWriter {
        void write(NM_Guardrail_Event__c e) { insert e; }
    }

    private without sharing class ConversationWriter {

        void insertRecord(NM_Conversation__c conv) {
            insert conv;
        }
    }
}
