/*****************************************************************
Name:          NM_LogConversationActionTest
============================================================
Purpose:       Unit tests for NM_LogConversationAction.
               Covers: new session create, existing session update
               (Started_At__c not overwritten), missing sessionKey
               guard, mixed batch, and bulk-safe (25 records).
============================================================
History
-------
VERSION  AUTHOR              DATE         DETAIL    DESCRIPTION
1.0      Revecast Orch.      2026-08-29   Created   NMDH-9
*****************************************************************/
@isTest
public class NM_LogConversationActionTest {

    // ── Test 1: New session — Started_At__c must be set ───────────────────
    @isTest
    static void testCreateSetsStartedAt() {
        NM_LogConversationAction.Input inp = new NM_LogConversationAction.Input();
        inp.sessionKey      = 'NM-TEST-CREATE-001';
        inp.branch          = 'Army';
        inp.specialtyCode   = '11B';
        inp.clusterKey      = 'infantry-ops';
        inp.messageCount    = 3;
        inp.transcript      = 'Session transcript content.';
        inp.mentorRequested = false;
        inp.mentorMatched   = false;

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(
                new List<NM_LogConversationAction.Input>{ inp }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Expected one response');
        System.assertEquals(true, responses[0].success, 'Create should succeed');
        System.assertNotEquals(null, responses[0].conversationId, 'conversationId should be returned');

        NM_Conversation__c created = [
            SELECT External_Session_Key__c, Started_At__c, Branch__c,
                   Specialty_Code__c, Cluster_Key__c, Message_Count__c,
                   Transcript__c, Mentor_Requested__c, Mentor_Matched__c
            FROM   NM_Conversation__c
            WHERE  External_Session_Key__c = 'NM-TEST-CREATE-001'
        ];
        System.assertNotEquals(null, created.Started_At__c,
            'Started_At__c must be populated on create');
        System.assertEquals('Army',          created.Branch__c);
        System.assertEquals('11B',           created.Specialty_Code__c);
        System.assertEquals('infantry-ops',  created.Cluster_Key__c);
        System.assertEquals(3,               Integer.valueOf(created.Message_Count__c));
        System.assertEquals(false,           created.Mentor_Requested__c);
    }

    // ── Test 2: Existing session — Started_At__c must NOT be overwritten ──
    @isTest
    static void testUpdateDoesNotOverwriteStartedAt() {
        DateTime originalStart = DateTime.newInstance(2026, 1, 15, 9, 0, 0);
        NM_Conversation__c seed = new NM_Conversation__c(
            External_Session_Key__c = 'NM-TEST-UPDATE-001',
            Started_At__c           = originalStart,
            Message_Count__c        = 2
        );
        insert seed;

        NM_LogConversationAction.Input inp = new NM_LogConversationAction.Input();
        inp.sessionKey      = 'NM-TEST-UPDATE-001';
        inp.messageCount    = 8;
        inp.mentorRequested = true;
        inp.mentorMatched   = false;

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(
                new List<NM_LogConversationAction.Input>{ inp }
            );
        Test.stopTest();

        System.assertEquals(true, responses[0].success, 'Update should succeed');
        System.assertEquals(seed.Id, responses[0].conversationId,
            'Should return the existing record Id');

        NM_Conversation__c updated = [
            SELECT Started_At__c, Message_Count__c, Mentor_Requested__c
            FROM   NM_Conversation__c
            WHERE  External_Session_Key__c = 'NM-TEST-UPDATE-001'
        ];
        System.assertEquals(originalStart, updated.Started_At__c,
            'Started_At__c must not be overwritten on update');
        System.assertEquals(8,    Integer.valueOf(updated.Message_Count__c),
            'Message_Count__c should have updated');
        System.assertEquals(true, updated.Mentor_Requested__c,
            'Mentor_Requested__c should have updated');
    }

    // ── Test 3: Missing sessionKey (null) — must return success=false ─────
    @isTest
    static void testNullSessionKeyFails() {
        NM_LogConversationAction.Input inp = new NM_LogConversationAction.Input();
        inp.sessionKey   = null;
        inp.messageCount = 1;

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(
                new List<NM_LogConversationAction.Input>{ inp }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success,
            'Null sessionKey must return success=false');
        System.assertNotEquals(null, responses[0].message,
            'Error message must be present');
        System.assertEquals(0,
            [SELECT COUNT() FROM NM_Conversation__c WHERE External_Session_Key__c = null],
            'No record should be created for null sessionKey');
    }

    // ── Test 3b: Blank sessionKey — must also fail ────────────────────────
    @isTest
    static void testBlankSessionKeyFails() {
        NM_LogConversationAction.Input inp = new NM_LogConversationAction.Input();
        inp.sessionKey = '   ';

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(
                new List<NM_LogConversationAction.Input>{ inp }
            );
        Test.stopTest();

        System.assertEquals(false, responses[0].success,
            'Blank sessionKey must return success=false');
    }

    // ── Test 4: Bulk-safe — 25 records created in one call ───────────────
    @isTest
    static void testBulkCreate25Records() {
        List<NM_LogConversationAction.Input> inputs = new List<NM_LogConversationAction.Input>();
        for (Integer i = 0; i < 25; i++) {
            NM_LogConversationAction.Input inp = new NM_LogConversationAction.Input();
            inp.sessionKey   = 'NM-BULK-' + String.valueOf(i).leftPad(3, '0');
            inp.branch       = 'Marines';
            inp.messageCount = i + 1;
            inputs.add(inp);
        }

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(inputs);
        Test.stopTest();

        System.assertEquals(25, responses.size(), 'Expected 25 responses');
        for (NM_LogConversationAction.Response r : responses) {
            System.assertEquals(true, r.success, 'Each bulk record should succeed');
            System.assertNotEquals(null, r.conversationId);
        }

        List<NM_Conversation__c> created = [
            SELECT Started_At__c
            FROM   NM_Conversation__c
            WHERE  External_Session_Key__c LIKE 'NM-BULK-%'
        ];
        System.assertEquals(25, created.size(), '25 NM_Conversation__c records must exist');
        for (NM_Conversation__c c : created) {
            System.assertNotEquals(null, c.Started_At__c,
                'Started_At__c must be set on every bulk-created record');
        }
    }

    // ── Test 5: Mixed batch — valid and invalid in same invocation ────────
    @isTest
    static void testMixedValidAndInvalidBatch() {
        NM_LogConversationAction.Input valid = new NM_LogConversationAction.Input();
        valid.sessionKey = 'NM-MIXED-VALID-001';
        valid.branch     = 'Air Force';

        NM_LogConversationAction.Input invalid = new NM_LogConversationAction.Input();
        invalid.sessionKey = null;

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(
                new List<NM_LogConversationAction.Input>{ valid, invalid }
            );
        Test.stopTest();

        System.assertEquals(2, responses.size());
        System.assertEquals(true,  responses[0].success,
            'Valid input in mixed batch must succeed');
        System.assertEquals(false, responses[1].success,
            'Null sessionKey in mixed batch must fail');
    }

    // ── Test 6: Optional fields — omitted fields must not null out existing values ──
    @isTest
    static void testPartialUpdatePreservesExistingFields() {
        NM_Conversation__c seed = new NM_Conversation__c(
            External_Session_Key__c = 'NM-TEST-PARTIAL-001',
            Started_At__c           = DateTime.now().addHours(-1),
            Branch__c               = 'Navy',
            Specialty_Code__c       = 'CTI',
            Message_Count__c        = 4
        );
        insert seed;

        // Only update messageCount; omit branch and specialtyCode
        NM_LogConversationAction.Input inp = new NM_LogConversationAction.Input();
        inp.sessionKey   = 'NM-TEST-PARTIAL-001';
        inp.messageCount = 9;

        Test.startTest();
        List<NM_LogConversationAction.Response> responses =
            NM_LogConversationAction.logConversation(
                new List<NM_LogConversationAction.Input>{ inp }
            );
        Test.stopTest();

        System.assertEquals(true, responses[0].success);

        NM_Conversation__c result = [
            SELECT Branch__c, Specialty_Code__c, Message_Count__c
            FROM   NM_Conversation__c
            WHERE  External_Session_Key__c = 'NM-TEST-PARTIAL-001'
        ];
        System.assertEquals('Navy', result.Branch__c,
            'Branch__c must be preserved when not included in the update');
        System.assertEquals('CTI',  result.Specialty_Code__c,
            'Specialty_Code__c must be preserved when not included in the update');
        System.assertEquals(9, Integer.valueOf(result.Message_Count__c),
            'Message_Count__c must update to 9');
    }
}
