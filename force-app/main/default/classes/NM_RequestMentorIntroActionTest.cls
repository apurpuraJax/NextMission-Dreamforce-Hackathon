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
3.0      Orchestrate  2026-08-31   Updated   NMDH-8 mentorId is now String on
                                             the Request; happy path passes a
                                             plain string, plus new coverage for
                                             the blank/malformed mentorId guard.
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
        // NMDH-8 v3.0: pass the mentor Id as a PLAIN STRING to mirror what the
        // Agentforce planner supplies now that Request.mentorId is String-typed.
        req.mentorId       = String.valueOf(mentor.Id);
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
    Purpose:       Unknown session key (NMDH-8 v2.0) — the action now
                   CREATES a new NM_Conversation__c on lookup miss and
                   still queues the intro instead of failing. If the key
                   is non-blank, the new conversation is stamped with it.
    *****************************************************************/
    @isTest
    static void testUnknownConversationKey() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = mentor.Id;
        req.requesterEmail  = 'vet3@example.com';
        req.conversationKey = 'nonexistent-session-key-xyz';

        Integer convsBefore = [SELECT COUNT() FROM NM_Conversation__c];

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Unknown session key should now succeed by creating the conversation');
        System.assertNotEquals(null, results[0].message, 'message should be set');

        // A brand-new conversation was created and stamped with the key.
        Integer convsAfter = [SELECT COUNT() FROM NM_Conversation__c];
        System.assertEquals(convsBefore + 1, convsAfter,
            'A new NM_Conversation__c should be created on lookup miss');

        NM_Conversation__c created = [
            SELECT Id, External_Session_Key__c, Mentor_Requested__c,
                   Lead_Captured__c, Mentor_Matched__c, QA_Reviewed__c
            FROM NM_Conversation__c
            WHERE External_Session_Key__c = 'nonexistent-session-key-xyz' LIMIT 1
        ];
        System.assertEquals(true, created.Mentor_Requested__c, 'Mentor_Requested__c should be set true');
        System.assertEquals(false, created.Lead_Captured__c,   'Lead_Captured__c should default false');
        System.assertEquals(false, created.Mentor_Matched__c,  'Mentor_Matched__c should default false');
        System.assertEquals(false, created.QA_Reviewed__c,     'QA_Reviewed__c should default false');

        // The intro record was queued against the new conversation.
        List<NM_Mentor_Introduction__c> intros = [
            SELECT Id, Conversation__c FROM NM_Mentor_Introduction__c WHERE Mentor__c = :mentor.Id
        ];
        System.assertEquals(1, intros.size(), 'Intro should be queued against the new conversation');
        System.assertEquals(created.Id, intros[0].Conversation__c, 'Intro should link to the created conversation');
    }

    /*****************************************************************
    Purpose:       Blank/absent conversation key — the action creates a
                   fresh conversation (no key stamped) and queues the intro.
    *****************************************************************/
    @isTest
    static void testBlankConversationKeyCreatesConversation() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = mentor.Id;
        req.requesterEmail  = 'vet-blank@example.com';
        req.conversationKey = null;

        Integer convsBefore = [SELECT COUNT() FROM NM_Conversation__c];

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Blank key should succeed by creating a conversation');
        Integer convsAfter = [SELECT COUNT() FROM NM_Conversation__c];
        System.assertEquals(convsBefore + 1, convsAfter, 'Exactly one conversation created for blank key');

        Integer introCount = [SELECT COUNT() FROM NM_Mentor_Introduction__c WHERE Mentor__c = :mentor.Id];
        System.assertEquals(1, introCount, 'One intro queued for the blank-key request');
    }

    /*****************************************************************
    Purpose:       Bulk safety — 200 requests with distinct unknown keys
                   run within governor limits (single insert outside loop),
                   creating 200 conversations and 200 intros.
    *****************************************************************/
    @isTest
    static void testBulkCreateOnMiss() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        List<NM_RequestMentorIntroAction.Request> reqs =
            new List<NM_RequestMentorIntroAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            NM_RequestMentorIntroAction.Request r = new NM_RequestMentorIntroAction.Request();
            r.mentorId        = mentor.Id;
            r.requesterEmail  = 'bulk' + i + '@example.com';
            r.conversationKey = 'bulk-miss-key-' + i;
            reqs.add(r);
        }

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results =
            NM_RequestMentorIntroAction.requestIntro(reqs);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'One response per request');
        for (NM_RequestMentorIntroAction.Response res : results) {
            System.assertEquals(true, res.success, 'Every bulk request should succeed');
        }

        Integer introCount = [SELECT COUNT() FROM NM_Mentor_Introduction__c WHERE Mentor__c = :mentor.Id];
        System.assertEquals(200, introCount, '200 intros created for 200 distinct-key requests');
    }

    /*****************************************************************
    Purpose:       Bulk in-batch dedupe — the SAME real key repeated
                   across the batch resolves to ONE conversation and,
                   for the same mentor, ONE intro.
    *****************************************************************/
    @isTest
    static void testBulkSameKeyDedupes() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        List<NM_RequestMentorIntroAction.Request> reqs =
            new List<NM_RequestMentorIntroAction.Request>();
        for (Integer i = 0; i < 5; i++) {
            NM_RequestMentorIntroAction.Request r = new NM_RequestMentorIntroAction.Request();
            r.mentorId        = mentor.Id;
            r.requesterEmail  = 'same' + i + '@example.com';
            r.conversationKey = 'shared-new-key-abc';
            reqs.add(r);
        }

        Integer convsBefore = [SELECT COUNT() FROM NM_Conversation__c];

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results =
            NM_RequestMentorIntroAction.requestIntro(reqs);
        Test.stopTest();

        for (NM_RequestMentorIntroAction.Response res : results) {
            System.assertEquals(true, res.success, 'All same-key requests should report success');
        }

        Integer convsAfter = [SELECT COUNT() FROM NM_Conversation__c];
        System.assertEquals(convsBefore + 1, convsAfter,
            'Repeated real key should create exactly one new conversation');

        Integer introCount = [SELECT COUNT() FROM NM_Mentor_Introduction__c WHERE Mentor__c = :mentor.Id];
        System.assertEquals(1, introCount,
            'Same conversation + same mentor should yield exactly one intro');
    }

    /*****************************************************************
    Purpose:       NMDH-8 v3.0 — blank mentorId (String) is terminal for
                   that request: success=false, guidance message, and NO
                   intro record is created. The rest of the batch is
                   unaffected (bulk-safety of the per-request guard).
    *****************************************************************/
    @isTest
    static void testBlankMentorId() {
        NM_RequestMentorIntroAction.Request req = new NM_RequestMentorIntroAction.Request();
        req.mentorId        = '';
        req.requesterEmail  = 'blank-mentor@example.com';
        req.conversationKey = 'intro-test-session-001';

        Integer introsBefore = [SELECT COUNT() FROM NM_Mentor_Introduction__c];

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Blank mentorId should return success=false');
        System.assertNotEquals(null, results[0].message, 'A guidance message should be returned');

        Integer introsAfter = [SELECT COUNT() FROM NM_Mentor_Introduction__c];
        System.assertEquals(introsBefore, introsAfter, 'No intro should be created for a blank mentorId');
    }

    /*****************************************************************
    Purpose:       NMDH-8 v3.0 — a malformed (non-Id) mentorId string is
                   caught by Id.valueOf and fails ONLY that request; it
                   must not throw and abort the batch. Asserts the valid
                   sibling request in the same call still succeeds.
    *****************************************************************/
    @isTest
    static void testMalformedMentorIdIsPerRequest() {
        NM_Mentor__c mentor = [SELECT Id FROM NM_Mentor__c WHERE Name = 'Sam Torres' LIMIT 1];

        // Bad request — garbage that Id.valueOf cannot parse.
        NM_RequestMentorIntroAction.Request bad = new NM_RequestMentorIntroAction.Request();
        bad.mentorId        = 'not-a-real-id';
        bad.requesterEmail  = 'bad-id@example.com';
        bad.conversationKey = 'intro-test-session-001';

        // Good request — valid mentor Id as a string, in the SAME batch.
        NM_RequestMentorIntroAction.Request good = new NM_RequestMentorIntroAction.Request();
        good.mentorId        = String.valueOf(mentor.Id);
        good.requesterEmail  = 'good-id@example.com';
        good.conversationKey = 'intro-test-session-001';

        Test.startTest();
        List<NM_RequestMentorIntroAction.Response> results = NM_RequestMentorIntroAction.requestIntro(
            new List<NM_RequestMentorIntroAction.Request>{ bad, good }
        );
        Test.stopTest();

        // The malformed request fails on its own; the valid one still succeeds.
        System.assertEquals(false, results[0].success, 'Malformed mentorId should fail its own request');
        System.assertNotEquals(null, results[0].message, 'A guidance message should be returned for the bad request');
        System.assertEquals(true, results[1].success, 'Valid sibling request must still succeed (batch not aborted)');

        // Exactly one intro — from the good request only.
        Integer introCount = [SELECT COUNT() FROM NM_Mentor_Introduction__c WHERE Mentor__c = :mentor.Id];
        System.assertEquals(1, introCount, 'Only the valid request should create an intro');
    }
}
