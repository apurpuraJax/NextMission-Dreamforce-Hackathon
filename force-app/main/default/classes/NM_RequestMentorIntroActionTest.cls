/*****************************************************************
Name:          NM_RequestMentorIntroActionTest
============================================================
Purpose:       Unit tests for NM_RequestMentorIntroAction.
               Covers: happy path (creates intro + sets flag),
               invalid email, missing session key, duplicate guard.
               Coverage target: 90%+.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-8
*****************************************************************/
@isTest
private class NM_RequestMentorIntroActionTest {

    @TestSetup
    static void makeData() {
        // Conversation record
        NM_Conversation__c conv = new NM_Conversation__c(
            External_Session_Key__c = 'intro-test-session-001',
            Started_At__c           = DateTime.now().addMinutes(-5)
        );
        insert conv;

        // Mentor record
        NM_Mentor__c mentor = new NM_Mentor__c(
            Name               = 'Sam Torres',
            Specialty_Cluster__c = 'healthcare',
            Branch__c          = 'Army',
            Civilian_Role__c   = 'Physician Assistant',
            Employer__c        = 'Valley Medical Group',
            Bio__c             = 'Ten years as an Army PA. Now in civilian surgical care.',
            Active__c          = true
        );
        insert mentor;
    }

    /*****************************************************************
    Purpose:       Happy path — valid inputs create intro record and
                   set Mentor_Requested__c on the conversation.
    *****************************************************************/
    @isTest
    static void testHappyPath() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId       = mentor.Id;
        req.requesterEmail = 'veteran@example.com';
        req.conversationKey = 'intro-test-session-001';

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        // Response assertions
        System.assertEquals(1, results.size(), 'Expected one response');
        NM_RequestMentorIntroAction.Response res = results[0];
        System.assertEquals(true, res.success, 'success should be true');
        System.assertNotEquals(null, res.message, 'message should be set');

        // Intro record created
        List<NM_Mentor_Introduction__c> intros = [
            SELECT Id, Requester_Email__c, Status__c, Introduced_At__c,
                   Mentor__c, Conversation__r.External_Session_Key__c
            FROM NM_Mentor_Introduction__c
            WHERE Mentor__c = :mentor.Id
        ];
        System.assertEquals(1, intros.size(),                        'Exactly one intro should exist');
        System.assertEquals('veteran@example.com', intros[0].Requester_Email__c, 'email should match');
        System.assertEquals('Pending', intros[0].Status__c,           'Status should be Pending');
        System.assertNotEquals(null, intros[0].Introduced_At__c,      'Introduced_At__c should be set');

        // Conversation flag set
        NM_Conversation__c conv = [
            SELECT Mentor_Requested__c FROM NM_Conversation__c
            WHERE External_Session_Key__c = 'intro-test-session-001' LIMIT 1
        ];
        System.assertEquals(true, conv.Mentor_Requested__c, 'Mentor_Requested__c should be true');
    }

    /*****************************************************************
    Purpose:       Duplicate guard — second call with same inputs
                   returns success=true without creating a second record.
    *****************************************************************/
    @isTest
    static void testDuplicateGuard() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = mentor.Id;
        req.requesterEmail  = 'vet2@example.com';
        req.conversationKey = 'intro-test-session-001';

        Test.startTest();
        // First call — creates the record
        NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        // Second call — should hit the duplicate guard
        List<NM_RequestMentorIntroAction.Response> secondResults = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        NM_RequestMentorIntroAction.Response res = secondResults[0];
        System.assertEquals(true, res.success, 'Duplicate guard should return success=true');

        // Still only one intro record
        Integer introCount = [
            SELECT COUNT()
            FROM NM_Mentor_Introduction__c
            WHERE Mentor__c = :mentor.Id
        ];
        System.assertEquals(1, introCount, 'Duplicate guard must prevent a second intro record');
    }

    /*****************************************************************
    Purpose:       Invalid email — returns success=false with guidance.
    *****************************************************************/
    @isTest
    static void testInvalidEmail() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = mentor.Id;
        req.requesterEmail  = 'not-a-valid-email';
        req.conversationKey = 'intro-test-session-001';

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        NM_RequestMentorIntroAction.Response res = results[0];
        System.assertEquals(false, res.success,   'Invalid email should return success=false');
        System.assertNotEquals(null, res.message, 'message should ask to correct the email');

        Integer introCount = [SELECT COUNT() FROM NM_Mentor_Introduction__c WHERE Mentor__c = :mentor.Id];
        System.assertEquals(0, introCount, 'No intro record should be created on invalid email');
    }

    /*****************************************************************
    Purpose:       Blank email — treated as invalid, returns failure.
    *****************************************************************/
    @isTest
    static void testBlankEmail() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = mentor.Id;
        req.requesterEmail  = '';
        req.conversationKey = 'intro-test-session-001';

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Blank email should fail');
    }

    /*****************************************************************
    Purpose:       Unknown session key — returns success=false.
    *****************************************************************/
    @isTest
    static void testUnknownConversationKey() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = mentor.Id;
        req.requesterEmail  = 'vet3@example.com';
        req.conversationKey = 'nonexistent-session-key-xyz';

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Unknown session key should return false');
        System.assertNotEquals(null, results[0].message, 'message should be set');
    }
}
