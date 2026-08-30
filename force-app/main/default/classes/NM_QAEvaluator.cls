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
            // LongTextArea fields cannot be filtered in SOQL — skip blanks here
            if (String.isBlank(record.Transcript__c)) {
                continue;
            }
            NM_Conversation__c upd = new NM_Conversation__c(Id = record.Id);
            if (record.Transcript__c == null) {
                // No transcript — skip this record; mark reviewed so it isn't re-queried
                upd.QA_Reviewed__c    = true;
                upd.QA_Reviewed_At__c = DateTime.now();
                upd.QA_Score__c       = 0;
                upd.QA_Issues__c      = 'Skipped: no transcript available';
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
                upd.QA_Reviewed__c    = true;
                upd.QA_Reviewed_At__c = DateTime.now();
                upd.QA_Score__c       = 0;
                upd.QA_Issues__c      = 'Grader error: ' + e.getMessage();
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
    Purpose:       Calls NM_QA_Evaluator_Template via ConnectApi and
                   returns the raw JSON string response. Overridable
                   in tests via the mockResponseJson static variable.
    Parameters:    transcript — full conversation text
    Returns:       JSON string from the prompt template response
    *****************************************************************/
    @TestVisible
    private static String invokeTemplate(String transcript) {
        System.debug('Entering NM_QAEvaluator.invokeTemplate: transcriptLength=' + transcript.length());

        if (Test.isRunningTest() && mockResponseJson != null) {
            System.debug('NM_QAEvaluator.invokeTemplate: returning mock response');
            return mockResponseJson;
        }

        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        promptInput.isPreview = false;

        Map<String, ConnectApi.WrappedValue> valueMap = new Map<String, ConnectApi.WrappedValue>();
        ConnectApi.WrappedValue transcriptValue = new ConnectApi.WrappedValue();
        transcriptValue.value = transcript;
        valueMap.put('Input:Transcript', transcriptValue);
        promptInput.inputParams = valueMap;

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'NM_QA_Evaluator_Template',
                promptInput
            );

        String responseText;
        if (response.generations != null && !response.generations.isEmpty()) {
            responseText = response.generations[0].text;
        } else {
            throw new CalloutException('Empty response from NM_QA_Evaluator_Template');
        }

        System.debug('Exiting NM_QAEvaluator.invokeTemplate: responseLength=' + responseText.length());
        return responseText;
    }
}
