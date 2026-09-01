/*****************************************************************
Name:          NM_FindMentorActionTest
============================================================
Purpose:       Unit tests for NM_FindMentorAction.
               Covers: exact-branch match, any-branch fallback,
               not-found path, blank clusterKey guard.
               Coverage target: 90%+.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-8
*****************************************************************/
@isTest
private class NM_FindMentorActionTest {

    @TestSetup
    static void makeData() {
        List<NM_Mentor__c> mentors = new List<NM_Mentor__c>{
            new NM_Mentor__c(
                Name               = 'Alex Rivera',
                Specialty_Cluster__c = 'healthcare',
                Branch__c          = 'Army',
                Civilian_Role__c   = 'Emergency Medical Technician',
                Employer__c        = 'Metro Health System',
                Bio__c             = 'Eight years as a 68W combat medic. Now working acute care triage.',
                Active__c          = true
            ),
            new NM_Mentor__c(
                Name               = 'Jordan Kim',
                Specialty_Cluster__c = 'logistics',
                Branch__c          = 'Navy',
                Civilian_Role__c   = 'Supply Chain Analyst',
                Employer__c        = 'Global Freight Partners',
                Bio__c             = 'Six years as a Navy Logistics Specialist. Now managing freight flows.',
                Active__c          = true
            ),
            new NM_Mentor__c(
                Name               = 'Inactive Mentor',
                Specialty_Cluster__c = 'healthcare',
                Branch__c          = 'Navy',
                Civilian_Role__c   = 'Nurse',
                Employer__c        = 'City Hospital',
                Bio__c             = 'Should never be returned.',
                Active__c          = false
            )
        };
        insert mentors;
    }

    @isTest
    static void testExactBranchMatch() {
        // Arrange
        NM_FindMentorAction.Request req = new NM_FindMentorAction.Request();
        req.clusterKey = 'healthcare';
        req.branch     = 'Army';

        // Act
        Test.startTest();
        List<NM_FindMentorAction.Response> results = NM_FindMentorAction.findMentor(
            new List<NM_FindMentorAction.Request>{ req }
        );
        Test.stopTest();

        // Assert
        System.assertEquals(1, results.size(), 'Expected exactly one response');
        NM_FindMentorAction.Response res = results[0];
        System.assertEquals(true, res.found,                          'found should be true');
        System.assertEquals('Alex Rivera', res.mentorName,            'mentorName should match');
        System.assertEquals('Emergency Medical Technician', res.mentorCivilianRole, 'civilianRole should match');
        System.assertEquals('Metro Health System', res.mentorEmployer,'employer should match');
        System.assertNotEquals(null, res.mentorBio,                   'bio should be populated');
        System.assertNotEquals(null, res.mentorId,                    'mentorId should be set');
        // mentorId is now a String; confirm it is text that still holds a valid
        // 18-char NM_Mentor__c Id so the downstream action can re-parse it.
        System.assertEquals(18, res.mentorId.length(),                'mentorId should be an 18-char Id string');
        System.assertNotEquals(null, Id.valueOf(res.mentorId),        'mentorId string should parse back to an Id');
    }

    @isTest
    static void testAnyBranchFallback() {
        // Arrange: Air Force has no healthcare mentor — should fall back to Army mentor
        NM_FindMentorAction.Request req = new NM_FindMentorAction.Request();
        req.clusterKey = 'healthcare';
        req.branch     = 'Air Force';

        // Act
        Test.startTest();
        List<NM_FindMentorAction.Response> results = NM_FindMentorAction.findMentor(
            new List<NM_FindMentorAction.Request>{ req }
        );
        Test.stopTest();

        // Assert: fallback should return the active Army mentor (inactive one excluded)
        NM_FindMentorAction.Response res = results[0];
        System.assertEquals(true, res.found, 'fallback should still find a mentor');
        System.assertEquals('Alex Rivera', res.mentorName, 'should return the active Army mentor');
    }

    @isTest
    static void testNoBranchReturnsAnyMatch() {
        // Arrange: no branch provided — should return first active mentor
        NM_FindMentorAction.Request req = new NM_FindMentorAction.Request();
        req.clusterKey = 'logistics';

        // Act
        Test.startTest();
        List<NM_FindMentorAction.Response> results = NM_FindMentorAction.findMentor(
            new List<NM_FindMentorAction.Request>{ req }
        );
        Test.stopTest();

        // Assert
        NM_FindMentorAction.Response res = results[0];
        System.assertEquals(true, res.found,             'should find logistics mentor');
        System.assertEquals('Jordan Kim', res.mentorName, 'should return Jordan Kim');
    }

    @isTest
    static void testNotFoundReturnsMessage() {
        // Arrange: no mentor exists for this cluster
        NM_FindMentorAction.Request req = new NM_FindMentorAction.Request();
        req.clusterKey = 'cybersecurity';

        // Act
        Test.startTest();
        List<NM_FindMentorAction.Response> results = NM_FindMentorAction.findMentor(
            new List<NM_FindMentorAction.Request>{ req }
        );
        Test.stopTest();

        // Assert
        NM_FindMentorAction.Response res = results[0];
        System.assertEquals(false, res.found,        'found should be false');
        System.assertNotEquals(null, res.message,    'message should be set');
        System.assert(
            res.message.startsWith('I don\'t have'),
            'message should start with "I don\'t have"'
        );
    }

    @isTest
    static void testBlankClusterKey() {
        // Arrange
        NM_FindMentorAction.Request req = new NM_FindMentorAction.Request();
        req.clusterKey = '';

        // Act
        Test.startTest();
        List<NM_FindMentorAction.Response> results = NM_FindMentorAction.findMentor(
            new List<NM_FindMentorAction.Request>{ req }
        );
        Test.stopTest();

        // Assert
        NM_FindMentorAction.Response res = results[0];
        System.assertEquals(false, res.found,     'found should be false for blank clusterKey');
        System.assertNotEquals(null, res.message, 'message should be populated');
    }

    @isTest
    static void testInactiveMentorExcluded() {
        // Arrange: only an inactive mentor exists in this cluster — should not be returned
        // The inactive mentor is in healthcare / Navy but Active__c = false
        // Combine with branch=Navy to ensure both paths avoid it
        NM_FindMentorAction.Request req = new NM_FindMentorAction.Request();
        req.clusterKey = 'healthcare';
        req.branch     = 'Navy';

        // Act
        Test.startTest();
        List<NM_FindMentorAction.Response> results = NM_FindMentorAction.findMentor(
            new List<NM_FindMentorAction.Request>{ req }
        );
        Test.stopTest();

        // Assert: exact-branch finds no active Navy healthcare mentor;
        // fallback finds the active Army mentor
        NM_FindMentorAction.Response res = results[0];
        System.assertEquals(true, res.found,              'fallback should find active Army mentor');
        System.assertEquals('Alex Rivera', res.mentorName, 'inactive Navy mentor must not be returned');
    }
}
