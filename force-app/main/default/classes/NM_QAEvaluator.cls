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

        List<NM_Conversation__c> records = [
            SELECT Id, Transcript__c
            FROM NM_Conversation__c
            WHERE QA_Reviewed__c = false
            ORDER BY CreatedDate ASC
            LIMIT 10
        ];

        List<NM_Conversation__c> toUpdate = new List<NM_Conversation__c>();

        for (NM_Conversation__c record : records) {
            NM_Conversation__c upd = new NM_Conversation__c(Id = record.Id);
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

        // Self-chain if more unreviewed records remain after this batch
        Integer remaining = [
            SELECT COUNT()
            FROM NM_Conversation__c
            WHERE QA_Reviewed__c = false
        ];
        if (remaining > 0) {
            System.enqueueJob(new NM_QAEvaluator());
        }

        System.debug('Exiting NM_QAEvaluator.execute: processed=' + toUpdate.size() + ', remaining=' + remaining);
    }

    /*****************************************************************
    Purpose:       Returns the raw JSON string for a given transcript,
                   either from the test mock or the live Einstein LLM.
                   Structured so the closing debug + return execute in
                   BOTH test and live paths, maximising unit-test coverage.
    Parameters:    transcript — full conversation text
    Returns:       JSON string from the prompt template response
    *****************************************************************/
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
