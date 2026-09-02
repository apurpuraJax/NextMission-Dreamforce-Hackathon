/*****************************************************************
Name:          NM_MentorCorpusActionTest
============================================================
Purpose:       Cover NM_MentorCorpusAction. The behaviour that matters
               is not "does it return a string" but the two properties
               the design depends on: the shortlist is CAPPED, and it
               always leaves room for mentors outside the veteran's own
               career area.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-01  Created   NMDH-24 corpus cap
*****************************************************************/
@isTest
private class NM_MentorCorpusActionTest {

    @TestSetup
    static void makeData() {
        List<NM_Mentor__c> ms = new List<NM_Mentor__c>();
        // 20 in one area and 20 in another, comfortably over both caps.
        for (Integer i = 0; i < 20; i++) {
            ms.add(new NM_Mentor__c(Name = 'Aviation ' + String.valueOf(100 + i),
                Branch__c = 'Air Force', Specialty_Cluster__c = 'Aviation',
                Civilian_Role__c = 'Aircraft Mechanic', Employer__c = 'Skybridge',
                Bio__c = 'Maintained airframes.', Active__c = true));
            ms.add(new NM_Mentor__c(Name = 'Logistics ' + String.valueOf(100 + i),
                Branch__c = 'Army', Specialty_Cluster__c = 'Logistics',
                Civilian_Role__c = 'Supply Chain Analyst', Employer__c = 'Verity',
                Bio__c = 'Ran a supply activity.', Active__c = true));
        }
        // An inactive mentor must never appear.
        ms.add(new NM_Mentor__c(Name = 'Retired One', Branch__c = 'Navy',
            Specialty_Cluster__c = 'Aviation', Civilian_Role__c = 'Pilot',
            Employer__c = 'Nowhere', Bio__c = 'Inactive.', Active__c = false));
        insert ms;
    }

    private static NM_MentorCorpusAction.Response run(String key) {
        return run(key, null);
    }

    private static NM_MentorCorpusAction.Response run(String key, String description) {
        NM_MentorCorpusAction.Request r = new NM_MentorCorpusAction.Request();
        r.clusterKey = key;
        r.description = description;
        return NM_MentorCorpusAction.buildCorpus(
            new List<NM_MentorCorpusAction.Request>{ r })[0];
    }

    @isTest
    static void testShortlistIsCapped() {
        Test.startTest();
        NM_MentorCorpusAction.Response res = run('Aviation');
        Test.stopTest();

        System.assertEquals(15, res.candidateCount,
            'Shortlist must be capped at MAX_TOTAL, not the whole roster');
        System.assertEquals(40, res.rosterSize,
            'Roster size should report every ACTIVE mentor');
        System.assertEquals(15, res.corpus.split('\n').size(),
            'One line per shortlisted mentor');
    }

    @isTest
    static void testCrossAreaMatchesRemainPossible() {
        Test.startTest();
        NM_MentorCorpusAction.Response res = run('Aviation');
        Test.stopTest();

        // The whole point of NMDH-24: cluster is a tie-breaker, never a hard
        // filter. If the shortlist were all Aviation, a veteran whose best
        // match sits elsewhere could never reach them.
        System.assert(res.corpus.contains('Logistics '),
            'Shortlist must include mentors from OTHER career areas');
        Integer aviationLines = 0;
        for (String line : res.corpus.split('\n')) {
            if (line.contains('Aviation ')) aviationLines++;
        }
        System.assertEquals(10, aviationLines,
            'At most MAX_IN_CLUSTER may come from the veteran own area');
    }

    @isTest
    static void testInactiveMentorsAreExcluded() {
        Test.startTest();
        NM_MentorCorpusAction.Response res = run('Aviation');
        Test.stopTest();
        System.assert(!res.corpus.contains('Retired One'),
            'An inactive mentor must never be offered');
    }

    @isTest
    static void testBlankClusterStillReturnsAShortlist() {
        Test.startTest();
        NM_MentorCorpusAction.Response res = run(null);
        Test.stopTest();
        System.assertEquals(15, res.candidateCount,
            'A veteran with no cluster still gets a shortlist, drawn from the whole roster');
    }

    /*
     * The regression this was written for: with a BLANK clusterKey every mentor
     * falls into the "others" pool, and before ranking that pool was filled in
     * Name order. A combat medic was matched to a supply chain manager purely
     * because Alex sorts before Cameron. The shortlist must be driven by what
     * the veteran said, not by the alphabet.
     */
    @isTest
    static void testBlankClusterRanksByWhatTheVeteranSaid() {
        insert new NM_Mentor__c(Name = 'Zulu Last', Branch__c = 'Navy',
            Specialty_Cluster__c = 'Healthcare', Civilian_Role__c = 'Paramedic',
            Employer__c = 'County EMS', Active__c = true,
            Bio__c = 'Ran emergency medical care and trauma response on ambulances.');

        Test.startTest();
        NM_MentorCorpusAction.Response res =
            run(null, 'combat medic, emergency trauma care, wants paramedic work');
        Test.stopTest();

        // Sorts dead last by Name, so it can only appear if ranking put it there.
        System.assert(res.corpus.contains('Zulu Last'),
            'The relevant mentor must make the shortlist even when it sorts last alphabetically');
    }

    @isTest
    static void testDescriptionOfOnlyStopwordsDoesNotBreakRanking() {
        Test.startTest();
        NM_MentorCorpusAction.Response res = run(null, 'i was in the and of a');
        Test.stopTest();
        System.assertEquals(15, res.candidateCount,
            'A description carrying no real words must fall back to an unranked shortlist, not fail');
    }

    @isTest
    static void testSmallRosterReturnsEveryone() {
        delete [SELECT Id FROM NM_Mentor__c WHERE Name LIKE 'Logistics%'];
        delete [SELECT Id FROM NM_Mentor__c WHERE Name LIKE 'Aviation 1%' LIMIT 17];
        Test.startTest();
        NM_MentorCorpusAction.Response res = run('Aviation');
        Test.stopTest();
        System.assert(res.candidateCount <= 15 && res.candidateCount > 0,
            'A roster smaller than the cap must return everyone, not fail');
    }
}
