/*****************************************************************
Name:          NM_QAEvaluatorTest
============================================================
Purpose:       Unit tests for NM_QAEvaluator. Injects mock JSON
               via the @TestVisible static to bypass the live
               ConnectApi.EinsteinLLM callout.
               Coverage: happy path, error/catch path.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-29   Created   NMDH-19
*****************************************************************/
@isTest
private class NM_QAEvaluatorTest {

    @TestSetup
    static void makeData() {
        List<NM_Conversation__c> convs = new List<NM_Conversation__c>{
            new NM_Conversation__c(
                External_Session_Key__c = 'qa-test-nmdh19-001',
                Started_At__c = DateTime.now().addHours(-1),
                Transcript__c = 'Visitor: I served as a 68W Army Combat Medic for eight years.\n' +
                    'Agent: That experience maps closely to emergency medical technician, ' +
                    'surgical technician, or clinical care coordinator roles.'
            ),
            new NM_Conversation__c(
                External_Session_Key__c = 'qa-test-nmdh19-002',
                Started_At__c = DateTime.now().addHours(-2),
                Transcript__c = 'Visitor: I handled logistics as a 92A in the Army.\n' +
                    'Agent: Your experience translates directly to logistics coordinator, ' +
                    'supply chain analyst, and procurement specialist roles.'
            )
        };
        insert convs;
    }

    @isTest
    static void testEvaluatorGradesRecords() {
        // Arrange: inject a valid mock JSON response
        NM_QAEvaluator.mockResponseJson =
            '{"score":8,"sentiment":"Positive","issueCategories":[],' +
            '"details":"Clear and accurate response mapping military experience to civilian roles.",' +
            '"summary":"Agent accurately translated 68W combat medic experience to civilian health roles."}';

        List<NM_Conversation__c> before = [
            SELECT Id FROM NM_Conversation__c
            WHERE QA_Reviewed__c = false AND Transcript__c != null
        ];
        System.assertEquals(2, before.size(), 'Expected 2 unreviewed seed records');

        // Act
        Test.startTest();
        System.enqueueJob(new NM_QAEvaluator());
        Test.stopTest();

        // Assert
        List<NM_Conversation__c> after = [
            SELECT Id, QA_Score__c, QA_Reviewed__c, QA_Reviewed_At__c,
                   Sentiment__c, QA_Issue_Categories__c, QA_Issues__c, Summary__c
            FROM NM_Conversation__c
            WHERE QA_Reviewed__c = true
            ORDER BY CreatedDate ASC
        ];
        System.assert(after.size() >= 1, 'At least one record should have been graded');

        NM_Conversation__c graded = after[0];
        System.assertEquals(true, graded.QA_Reviewed__c,        'QA_Reviewed__c should be true');
        System.assertNotEquals(null, graded.QA_Reviewed_At__c,  'QA_Reviewed_At__c should be set');
        System.assert(graded.QA_Score__c > 0,                   'QA_Score__c should be > 0');
        System.assertEquals('Positive', graded.Sentiment__c,    'Sentiment should match mock response');
        System.assertNotEquals(null, graded.Summary__c,         'Summary__c should be populated');
    }

    @isTest
    static void testEvaluatorHandlesGraderError() {
        // Arrange: inject invalid JSON to exercise the catch block
        NM_QAEvaluator.mockResponseJson = 'not valid json {{ at all';

        // Act
        Test.startTest();
        System.enqueueJob(new NM_QAEvaluator());
        Test.stopTest();

        // Assert: records should be marked reviewed with error details
        List<NM_Conversation__c> after = [
            SELECT Id, QA_Score__c, QA_Reviewed__c, QA_Reviewed_At__c, QA_Issues__c
            FROM NM_Conversation__c
            WHERE QA_Reviewed__c = true
        ];
        System.assert(after.size() >= 1, 'At least one record should be processed on error');

        NM_Conversation__c errored = after[0];
        System.assertEquals(true, errored.QA_Reviewed__c,       'QA_Reviewed__c must be true even on error');
        System.assertNotEquals(null, errored.QA_Reviewed_At__c, 'QA_Reviewed_At__c must be set on error');
        System.assertEquals(0, (Integer) errored.QA_Score__c,   'QA_Score__c should be 0 on error');
        System.assert(
            errored.QA_Issues__c != null && errored.QA_Issues__c.startsWith('Grader error:'),
            'QA_Issues__c should start with "Grader error:"'
        );
    }
}
