// Enqueues NM_QAEvaluator to grade all unreviewed NM_Conversation__c transcripts.
// The evaluator processes up to 10 records per batch and self-chains when more remain.
// Run AFTER seed-conversations.apex to ensure records and transcripts are present.
//
// Run: sf apex run --file scripts/apex/run-qa-evaluator.apex --target-org dreamforce-hackathon

Integer unreviewed = [
    SELECT COUNT()
    FROM NM_Conversation__c
    WHERE QA_Reviewed__c = false
];

System.debug('NM_QAEvaluator: unreviewed conversations to grade = ' + unreviewed);

if (unreviewed > 0) {
    Id jobId = System.enqueueJob(new NM_QAEvaluator());
    System.debug('NM_QAEvaluator enqueued. Job ID: ' + jobId);
    System.debug('Poll for completion:');
    System.debug('  SELECT Id, Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE Id = \'' + jobId + '\'');
} else {
    System.debug('No unreviewed conversations found. Nothing to grade.');
}
