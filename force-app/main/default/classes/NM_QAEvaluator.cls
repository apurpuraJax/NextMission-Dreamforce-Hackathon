/*****************************************************************
Name:          NM_QAEvaluator
============================================================
Purpose:       Queueable Apex that grades NM_Conversation__c
               transcripts using the NM_QA_Evaluator_Template
               Prompt Template via ConnectApi.EinsteinLLM.
               Processes up to 10 unreviewed records per execution
               and self-chains when more remain.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-29   Created   NMDH-19
*****************************************************************/
public class NM_QAEvaluator implements Queueable, Database.AllowsCallouts {

    /**
     * Allows test classes to inject a mock JSON response without a live
     * ConnectApi callout. Set before enqueuing in tests.
     */
    @TestVisible
    private static String mockResponseJson = null;

    /*****************************************************************
    Purpose:       Entry point for the Queueable. Queries up to 10
                   unreviewed conversations, grades each one, bulk-updates
                   all fields, then self-chains if more records remain.
    Parameters:    context — provided by the platform
    *****************************************************************/
    public void execute(QueueableContext context) {
        System.debug('Entering NM_QAEvaluator.execute');

        // Conversation logging writes ONE ROW PER TURN, because a guest user
        // cannot update a record (see NM_AgentController). So the same
        // conversation appears as several rows keyed <session>-t1, -t2, -t3,
        // each holding the cumulative transcript up to that point.
        //
        // Grade only the LAST row of a settled conversation. Grading every row
        // would score a one-line fragment as a finished conversation, which
        // reads as "NoHelpDelivered" and drags the average down, and it burns
        // one Einstein call per turn instead of one per conversation.
        // Only real visitors. The regression harnesses drive the live agent
        // hundreds of times a day with deliberately hostile input: someone
        // abusive, someone in crisis, someone asking the same question four
        // times to prove we do not stonewall. Grading those as if they were
        // veterans would report this agent as far worse than it is, and it
        // would be OUR OWN test traffic saying so. They are tagged by
        // sourceUrl, so they are excluded here rather than explained away in
        // a dashboard later.
        String sitePrefix = 'https://orgfarm-3bfff135af.my.site.com/nextmission%';

        List<NM_Conversation__c> candidates = [
            SELECT Id, Transcript__c, External_Session_Key__c, Message_Count__c, CreatedDate
            FROM NM_Conversation__c
            WHERE QA_Reviewed__c = false
            AND   (Source_URL__c LIKE :sitePrefix OR Source_URL__c = null)
            ORDER BY CreatedDate ASC
            LIMIT 200
        ];

        List<NM_Conversation__c> toUpdate = new List<NM_Conversation__c>();

        // Keep the highest-turn row per conversation; supersede the rest.
        Map<String, NM_Conversation__c> latestBySession = new Map<String, NM_Conversation__c>();
        List<NM_Conversation__c> superseded = new List<NM_Conversation__c>();

        for (NM_Conversation__c c : candidates) {
            String base = baseSessionKey(c.External_Session_Key__c);
            if (base == null) {
                // No key at all, e.g. the minimal record NM_RequestMentorIntroAction
                // creates so an introduction is never orphaned. Handled below.
                latestBySession.put('nokey-' + c.Id, c);
                continue;
            }
            NM_Conversation__c held = latestBySession.get(base);
            if (held == null) {
                latestBySession.put(base, c);
            } else if (turnOf(c) > turnOf(held)) {
                latestBySession.put(base, c);
                superseded.add(held);
            } else {
                superseded.add(c);
            }
        }

        for (NM_Conversation__c prior : superseded) {
            toUpdate.add(new NM_Conversation__c(
                Id                = prior.Id,
                QA_Reviewed__c    = true,
                QA_Reviewed_At__c = DateTime.now(),
                QA_Score__c       = null,
                QA_Issues__c      = 'Not scored: superseded by a later turn of the same conversation'
            ));
        }

        // A conversation is treated as settled once nothing new has arrived for
        // SETTLE_MINUTES. There is no end-of-conversation signal, so this is the
        // closest honest approximation. An unsettled row is simply left for the
        // next run rather than graded half-finished.
        // Tests create records with CreatedDate = now, which the settle window
        // would always exclude, so bypass the wait under test.
        Integer settle = Test.isRunningTest() ? 0 : SETTLE_MINUTES;
        DateTime cutoff = DateTime.now().addMinutes(-settle);
        List<NM_Conversation__c> records = new List<NM_Conversation__c>();
        for (NM_Conversation__c c : latestBySession.values()) {
            if (String.isBlank(c.Transcript__c) || c.CreatedDate < cutoff) {
                records.add(c);
            }
            if (records.size() >= BATCH_SIZE) { break; }
        }

        for (NM_Conversation__c record : records) {
            NM_Conversation__c upd = new NM_Conversation__c(Id = record.Id);

            // NOTE: deliberately NOT skipping short conversations. Someone who
            // asks one question, gets a good answer and leaves has had a
            // COMPLETE conversation, and turn count cannot tell that apart from
            // giving up. The template is instructed to judge the agent's conduct
            // only and never to penalise it for the visitor leaving.

            if (String.isBlank(record.Transcript__c)) {
                // No/blank transcript. Mark reviewed so it is not re-queried on
                // every batch, but leave QA_Score__c NULL. Writing 0 here scored
                // an empty shell as if the agent had performed terribly and
                // dragged every average to the floor. A conversation with no
                // transcript is unscored, not bad.
                //
                // Most of these shells come from NM_RequestMentorIntroAction,
                // which creates a minimal conversation when the agent does not
                // pass a session key so an introduction is never orphaned.
                upd.QA_Reviewed__c    = true;
                upd.QA_Reviewed_At__c = DateTime.now();
                upd.QA_Score__c       = null;
                upd.QA_Issues__c      = 'Not scored: no transcript on this record';
                toUpdate.add(upd);
                continue;
            }
            try {
                String responseJson = invokeTemplate(record.Transcript__c);
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseJson);

                upd.QA_Reviewed__c    = true;
                upd.QA_Reviewed_At__c = DateTime.now();
                upd.QA_Score__c       = Integer.valueOf(String.valueOf(parsed.get('score')));
                upd.Sentiment__c      = (String) parsed.get('sentiment');

                List<Object> cats = (List<Object>) parsed.get('issueCategories');
                List<String> catStrings = new List<String>();
                if (cats != null) {
                    for (Object cat : cats) {
                        catStrings.add((String) cat);
                    }
                }
                upd.QA_Issue_Categories__c = catStrings.isEmpty() ? null : String.join(catStrings, ';');

                String details = (String) parsed.get('details');
                upd.QA_Issues__c = details;

                String summary = (String) parsed.get('summary');
                upd.Summary__c = (summary != null && summary.length() > 255)
                    ? summary.substring(0, 255)
                    : summary;

            } catch (Exception e) {
                System.debug('NM_QAEvaluator error for Id=' + record.Id + ': ' + e.getMessage());
                // A grader failure is OUR failure, not a bad conversation.
                // Writing 0 here made a broken Einstein call look identical to
                // an agent that performed terribly. Leave the score NULL.
                // Reviewed stays true so a permanently failing record cannot
                // re-burn an Einstein call every hour; re-run deliberately
                // after fixing the cause.
                upd.QA_Reviewed__c    = true;
                upd.QA_Reviewed_At__c = DateTime.now();
                upd.QA_Score__c       = null;
                upd.QA_Issues__c      = 'Grader error, not scored: ' + e.getMessage();
            }
            toUpdate.add(upd);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        // Self-chain ONLY when this batch was full, which is the only case that
        // implies more gradeable work. Chaining on "any unreviewed record
        // remains" recursed until "Maximum stack depth has been reached",
        // because rows inside the settle window are deliberately left
        // unreviewed and would never clear.
        if (records.size() >= BATCH_SIZE && !Test.isRunningTest()) {
            System.enqueueJob(new NM_QAEvaluator());
        }

        System.debug('Exiting NM_QAEvaluator.execute: processed=' + toUpdate.size()
            + ', batch=' + records.size());
    }

    /*****************************************************************
    Purpose:       Returns the raw JSON string for a given transcript,
                   either from the test mock or the live Einstein LLM.
                   Structured so the closing debug + return execute in
                   BOTH test and live paths, maximising unit-test coverage.
    Parameters:    transcript — full conversation text
    Returns:       JSON string from the prompt template response
    *****************************************************************/
    /* Minutes of silence after which a conversation is treated as finished. */
    private static final Integer SETTLE_MINUTES = 30;

    /* Records graded per queueable execution. */
    private static final Integer BATCH_SIZE = 10;

    /*
     * Purpose:  Strip the per-turn suffix so every row of one conversation
     *           groups together. "nm-abc123-t4" -> "nm-abc123".
     * Returns:  null when the record has no session key at all.
     */
    @TestVisible
    private static String baseSessionKey(String key) {
        if (String.isBlank(key)) { return null; }
        Integer i = key.lastIndexOf('-t');
        if (i <= 0) { return key; }
        String suffix = key.substring(i + 2);
        return suffix.isNumeric() ? key.substring(0, i) : key;
    }

    /* Turn number for ordering; 0 when absent. */
    @TestVisible
    private static Integer turnOf(NM_Conversation__c c) {
        return (c.Message_Count__c == null) ? 0 : c.Message_Count__c.intValue();
    }

    @TestVisible
    private static String invokeTemplate(String transcript) {
        System.debug('Entering NM_QAEvaluator.invokeTemplate: transcriptLength=' + transcript.length());

        String responseText;
        if (Test.isRunningTest() && mockResponseJson != null) {
            System.debug('NM_QAEvaluator.invokeTemplate: returning mock response');
            responseText = mockResponseJson;
        } else {
            responseText = callLiveEinsteinApi(transcript);
        }

        System.debug('Exiting NM_QAEvaluator.invokeTemplate: responseLength=' + responseText.length());
        return responseText;
    }

    /*****************************************************************
    Purpose:       Makes the live ConnectApi call to the Einstein LLM
                   Prompt Template. Extracted from invokeTemplate so the
                   test-mock early-exit path does not hide the closing
                   debug and return statements from code coverage.
    Parameters:    transcript — full conversation text
    Returns:       raw text from the prompt template generation
    Throws:        CalloutException when the response has no generations
    *****************************************************************/
    private static String callLiveEinsteinApi(String transcript) {
        // Invoked through NM_QAGrade_Flow, NOT ConnectApi.
        //
        // ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate throws
        // "Failed to generate Einstein LLM generations response" in this org for
        // EVERY prompt template, including NM_Find_Mentor_Template, which works
        // correctly when the agent calls it from a Flow. So the failure is the
        // ConnectApi path itself, not the QA template. Proven by calling the
        // known-good template through ConnectApi and watching it fail the same
        // way. Do not "simplify" this back to a direct ConnectApi call.
        Map<String, Object> inputs = new Map<String, Object>{ 'transcript' => transcript };
        Flow.Interview flow = Flow.Interview.createInterview('NM_QAGrade_Flow', inputs);
        flow.start();

        String responseText = (String) flow.getVariableValue('responseText');
        if (String.isNotBlank(responseText)) {
            return responseText;
        }
        throw new CalloutException('Empty response from NM_QA_Evaluator_Template via NM_QAGrade_Flow');
    }
}
