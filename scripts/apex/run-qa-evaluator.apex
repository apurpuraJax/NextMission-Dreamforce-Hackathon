// Grades all unreviewed NM_Conversation__c transcripts synchronously via the
// Einstein Prompt Template REST endpoint. Session ID is captured in the
// synchronous context (Execute Anonymous) where it is always available.
//
// Run: sf apex run --file scripts/apex/run-qa-evaluator.apex --target-org dreamforce-hackathon
//
// For daily automated grading, NM_QAScheduler enqueues NM_QAEvaluator which
// passes the same session ID captured at enqueue time.

String sessionId = UserInfo.getSessionId();
String templateEndpoint = URL.getOrgDomainUrl().toExternalForm()
    + '/services/data/v67.0/einstein/prompt-templates/NM_QA_Evaluator_Template/generations';

List<NM_Conversation__c> records = [
    SELECT Id, External_Session_Key__c, Transcript__c
    FROM NM_Conversation__c
    WHERE QA_Reviewed__c = false
    ORDER BY External_Session_Key__c
];

System.debug('NM_QAEvaluator: unreviewed conversations to grade = ' + records.size());

if (records.isEmpty()) {
    System.debug('No unreviewed conversations found. Nothing to grade.');
    return;
}

List<NM_Conversation__c> toUpdate = new List<NM_Conversation__c>();

for (NM_Conversation__c record : records) {
    NM_Conversation__c upd = new NM_Conversation__c(Id = record.Id);
    upd.QA_Reviewed__c    = true;
    upd.QA_Reviewed_At__c = DateTime.now();

    if (String.isBlank(record.Transcript__c)) {
        upd.QA_Score__c  = 0;
        upd.QA_Issues__c = 'Skipped: no transcript available';
        toUpdate.add(upd);
        continue;
    }

    try {
        // Build request body
        String body = JSON.serialize(new Map<String, Object>{
            'isPreview' => false,
            'additionalConfig' => new Map<String, Object>{
                'applicationName' => 'PromptBuilderPreview',
                'numGenerations'  => 1,
                'temperature'     => 0.0
            },
            'inputParams' => new Map<String, Object>{
                'valueMap' => new Map<String, Object>{
                    'Input:Transcript' => new Map<String, Object>{ 'value' => record.Transcript__c }
                }
            }
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint(templateEndpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setBody(body);
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 201) {
            throw new CalloutException('HTTP ' + res.getStatusCode() + ': ' + res.getBody().left(200));
        }

        Map<String, Object> apiResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> generations = (List<Object>) apiResponse.get('generations');
        if (generations == null || generations.isEmpty()) {
            throw new CalloutException('Empty generations list from template');
        }
        String responseText = (String) ((Map<String, Object>) generations[0]).get('text');

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseText);

        upd.QA_Score__c = Integer.valueOf(String.valueOf(parsed.get('score')));
        upd.Sentiment__c = (String) parsed.get('sentiment');

        List<Object> cats = (List<Object>) parsed.get('issueCategories');
        if (cats != null && !cats.isEmpty()) {
            List<String> catStrings = new List<String>();
            for (Object cat : cats) { catStrings.add((String) cat); }
            upd.QA_Issue_Categories__c = String.join(catStrings, ';');
        }

        String details = (String) parsed.get('details');
        upd.QA_Issues__c = details;

        String summary = (String) parsed.get('summary');
        upd.Summary__c = (summary != null && summary.length() > 255) ? summary.substring(0, 255) : summary;

        System.debug('GRADED ' + record.External_Session_Key__c
            + ' → score=' + upd.QA_Score__c
            + ' sentiment=' + upd.Sentiment__c
            + ' issues=' + (upd.QA_Issue_Categories__c != null ? upd.QA_Issue_Categories__c : 'none'));

    } catch (Exception e) {
        System.debug('ERROR grading ' + record.External_Session_Key__c + ': ' + e.getMessage());
        upd.QA_Score__c  = 0;
        upd.QA_Issues__c = 'Grader error: ' + e.getMessage();
    }

    toUpdate.add(upd);
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' records.');
}
