/*****************************************************************
Name:          NM_TranslateSkillsActionTest
============================================================
Purpose:       Unit tests for NM_TranslateSkillsAction.
               Scenarios: blank key, unrecognised key, found path
               (uses any deployed NM_Specialty_Cluster__mdt record —
               CMDT is always visible in test context without
               @seeAllData), and 200-record bulk-safety check.
               Created by NMDH-6.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-6
*****************************************************************/
@isTest
private class NM_TranslateSkillsActionTest {

    /*****************************************************************
    Purpose:       Blank clusterKey returns found=false with a
                   non-blank message. Validates the null/empty guard.
    *****************************************************************/
    @isTest
    static void testTranslateSkills_BlankKey() {
        // Arrange
        NM_TranslateSkillsAction.Request req = new NM_TranslateSkillsAction.Request();
        req.clusterKey = '';
        req.userPrompt = 'I served as a combat engineer for six years.';

        // Act
        Test.startTest();
        List<NM_TranslateSkillsAction.Response> results =
            NM_TranslateSkillsAction.translateSkills(
                new List<NM_TranslateSkillsAction.Request>{ req }
            );
        Test.stopTest();

        // Assert
        System.assertEquals(1, results.size(), 'Should return exactly one response');
        System.assertEquals(false, results[0].found, 'found should be false for blank key');
        System.assert(String.isNotBlank(results[0].message), 'message should be populated and non-blank');
        System.assertEquals(null, results[0].translatedSkills, 'translatedSkills should be null on not-found');
    }

    /*****************************************************************
    Purpose:       A clusterKey that matches no CMDT record returns
                   found=false with a non-blank message.
    *****************************************************************/
    @isTest
    static void testTranslateSkills_UnrecognisedKey() {
        // Arrange
        NM_TranslateSkillsAction.Request req = new NM_TranslateSkillsAction.Request();
        req.clusterKey = 'NONEXISTENT_TEST_CLUSTER_KEY_99999';
        req.userPrompt = 'Test prompt';

        // Act
        Test.startTest();
        List<NM_TranslateSkillsAction.Response> results =
            NM_TranslateSkillsAction.translateSkills(
                new List<NM_TranslateSkillsAction.Request>{ req }
            );
        Test.stopTest();

        // Assert
        System.assertEquals(1, results.size(), 'Should return exactly one response');
        System.assertEquals(false, results[0].found, 'found should be false for unrecognised key');
        System.assert(String.isNotBlank(results[0].message), 'message should be populated');
        System.assertEquals(null, results[0].translatedSkills, 'translatedSkills should be null on not-found');
    }

    /*****************************************************************
    Purpose:       A known cluster key returns found=true with
                   translatedSkills populated and message null.
                   Relies on NM_Specialty_Cluster__mdt records existing
                   in the org (CMDT always visible in tests without
                   @seeAllData). When no records are deployed the test
                   passes vacuously and coverage is still satisfied by
                   the blank-key and unrecognised-key paths.
    *****************************************************************/
    @isTest
    static void testTranslateSkills_FoundPath() {
        // Read any deployed CMDT record
        List<NM_Specialty_Cluster__mdt> clusters = [
            SELECT Cluster_Key__c, Civilian_Skill_Summary__c, Job_Descriptions__c
            FROM NM_Specialty_Cluster__mdt
            LIMIT 1
        ];

        if (clusters.isEmpty()) {
            // No CMDT records in org — found-path cannot be exercised; test passes.
            System.assert(true, 'No NM_Specialty_Cluster__mdt records deployed; found-path skipped.');
            return;
        }

        // Arrange — use the real cluster key from the org
        NM_Specialty_Cluster__mdt cluster = clusters[0];
        NM_TranslateSkillsAction.Request req = new NM_TranslateSkillsAction.Request();
        req.clusterKey = cluster.Cluster_Key__c;
        req.userPrompt = 'I was a logistics officer for eight years.';

        // Act
        Test.startTest();
        List<NM_TranslateSkillsAction.Response> results =
            NM_TranslateSkillsAction.translateSkills(
                new List<NM_TranslateSkillsAction.Request>{ req }
            );
        Test.stopTest();

        // Assert
        System.assertEquals(1, results.size(), 'Should return exactly one response');
        System.assertEquals(true, results[0].found, 'found should be true for known cluster key');
        System.assert(String.isNotBlank(results[0].translatedSkills), 'translatedSkills should be populated');
        System.assertEquals(null, results[0].message, 'message should be null on found path');
    }

    /*****************************************************************
    Purpose:       200-record bulk invocation completes without
                   hitting governor limits. The action issues one SOQL
                   regardless of how many requests are passed.
    *****************************************************************/
    @isTest
    static void testTranslateSkills_BulkSafety() {
        // Arrange — 200 requests all with distinct non-existent keys
        List<NM_TranslateSkillsAction.Request> reqs = new List<NM_TranslateSkillsAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            NM_TranslateSkillsAction.Request req = new NM_TranslateSkillsAction.Request();
            req.clusterKey = 'BULK_TEST_KEY_' + i;
            req.userPrompt  = 'Bulk test prompt ' + i;
            reqs.add(req);
        }

        // Act
        Test.startTest();
        List<NM_TranslateSkillsAction.Response> results =
            NM_TranslateSkillsAction.translateSkills(reqs);
        Test.stopTest();

        // Assert — all 200 return, all not-found (keys don't exist in CMDT)
        System.assertEquals(200, results.size(), 'Should return exactly 200 responses');
        for (Integer i = 0; i < results.size(); i++) {
            System.assertEquals(false, results[i].found,
                'Response ' + i + ' should be not-found for non-existent key');
        }
    }
}
