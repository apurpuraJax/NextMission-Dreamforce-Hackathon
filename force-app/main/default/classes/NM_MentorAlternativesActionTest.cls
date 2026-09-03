/*****************************************************************
Name:          NM_MentorAlternativesActionTest
============================================================
Purpose:       Cover NM_MentorAlternativesAction. The guarantee is
               that the recommended mentor stays in position 1 and
               that a veteran is never shown a "choice" of one
               without being told that is all there is.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, human-in-the-loop
*****************************************************************/
@IsTest
private class NM_MentorAlternativesActionTest {

    @testSetup
    static void seed() {
        insert new List<NM_Mentor__c>{
            new NM_Mentor__c(Name='Alex Rivera', Specialty_Cluster__c='healthcare',
                Branch__c='Army', Civilian_Role__c='EMT', Employer__c='Metro', Active__c=true),
            new NM_Mentor__c(Name='Dana Okafor', Specialty_Cluster__c='healthcare',
                Branch__c='Army', Civilian_Role__c='Coordinator', Employer__c='Harbor', Active__c=true),
            new NM_Mentor__c(Name='Sam Whitfield', Specialty_Cluster__c='healthcare',
                Branch__c='Navy', Civilian_Role__c='Paramedic', Employer__c='County', Active__c=true),
            new NM_Mentor__c(Name='Casey Lyn', Specialty_Cluster__c='logistics',
                Branch__c='Army', Civilian_Role__c='Planner', Employer__c='Freight', Active__c=true),
            new NM_Mentor__c(Name='Retired Rob', Specialty_Cluster__c='healthcare',
                Branch__c='Army', Civilian_Role__c='Retired', Employer__c='None', Active__c=false)
        };
    }

    private static NM_MentorAlternativesAction.Response run(Id rec, String cluster, String branch) {
        NM_MentorAlternativesAction.Request r = new NM_MentorAlternativesAction.Request();
        r.recommendedMentorId = String.valueOf(rec);
        r.clusterKey          = cluster;
        r.branch              = branch;
        return NM_MentorAlternativesAction.getAlternatives(
            new List<NM_MentorAlternativesAction.Request>{ r })[0];
    }

    private static NM_Mentor__c named(String n) {
        return [ SELECT Id, Name FROM NM_Mentor__c WHERE Name = :n LIMIT 1 ];
    }

    @IsTest
    static void theRecommendationStaysInPositionOne() {
        NM_Mentor__c rec = named('Sam Whitfield');
        NM_MentorAlternativesAction.Response res = run(rec.Id, 'healthcare', 'Navy');

        System.assert(res.found);
        System.assert(res.mentorOptions.startsWith('1. Sam Whitfield'),
            'The semantic match must remain the recommendation, not get reshuffled');
        System.assertEquals(String.valueOf(rec.Id), res.mentorOptionIds.split(';')[0]);
    }

    @IsTest
    static void aVeteranIsGivenRealAlternatives() {
        NM_Mentor__c rec = named('Alex Rivera');
        NM_MentorAlternativesAction.Response res = run(rec.Id, 'healthcare', 'Army');

        System.assertEquals(3, res.mentorOptionCount, 'Three options where three exist');
        System.assert(res.hasAlternatives, 'There is a genuine choice here');
        System.assertEquals(3, res.mentorOptionIds.split(';').size(),
            'Every option needs an Id or the choice cannot be honoured');
    }

    @IsTest
    static void inactiveMentorsAreNeverOffered() {
        NM_Mentor__c rec = named('Alex Rivera');
        NM_MentorAlternativesAction.Response res = run(rec.Id, 'healthcare', 'Army');
        System.assert(!res.mentorOptions.contains('Retired Rob'),
            'An inactive mentor must never be offered to a veteran');
    }

    @IsTest
    static void aSoleMentorIsReportedAsSuchNotPaddedOut() {
        delete [ SELECT Id FROM NM_Mentor__c WHERE Name != 'Alex Rivera' ];
        NM_Mentor__c rec = named('Alex Rivera');
        NM_MentorAlternativesAction.Response res = run(rec.Id, 'healthcare', 'Army');

        System.assertEquals(1, res.mentorOptionCount);
        System.assert(!res.hasAlternatives,
            'One option is not a choice, and the agent must be told so it can say so');
    }

    @IsTest
    static void anUnknownRecommendationReturnsNotFound() {
        NM_MentorAlternativesAction.Response res = run(null, 'healthcare', 'Army');
        System.assert(!res.found, 'Without a recommendation there is nothing to build around');
    }

    @IsTest
    static void garbageIdDoesNotThrow() {
        NM_MentorAlternativesAction.Request r = new NM_MentorAlternativesAction.Request();
        r.recommendedMentorId = 'not-an-id';
        r.clusterKey = 'healthcare';
        NM_MentorAlternativesAction.Response res =
            NM_MentorAlternativesAction.getAlternatives(
                new List<NM_MentorAlternativesAction.Request>{ r })[0];
        System.assert(!res.found);
    }

    @IsTest
    static void bulkRequestsUseConstantQueries() {
        NM_Mentor__c rec = named('Alex Rivera');
        List<NM_MentorAlternativesAction.Request> reqs =
            new List<NM_MentorAlternativesAction.Request>();
        for (Integer i = 0; i < 50; i++) {
            NM_MentorAlternativesAction.Request r = new NM_MentorAlternativesAction.Request();
            r.recommendedMentorId = String.valueOf(rec.Id);
            r.clusterKey = 'healthcare';
            r.branch     = 'Army';
            reqs.add(r);
        }
        Test.startTest();
        List<NM_MentorAlternativesAction.Response> res =
            NM_MentorAlternativesAction.getAlternatives(reqs);
        Test.stopTest();
        System.assertEquals(50, res.size());
        System.assert(Limits.getQueries() <= 3,
            'Must not query per request. Used ' + Limits.getQueries());
    }

    @IsTest
    static void theShortlistFeedsSelectMentorCleanly() {
        // The whole point: what was offered is what can be chosen.
        NM_Mentor__c rec = named('Alex Rivera');
        NM_MentorAlternativesAction.Response opts = run(rec.Id, 'healthcare', 'Army');

        NM_SelectMentorAction.Request sr = new NM_SelectMentorAction.Request();
        sr.mentorOptionIds = opts.mentorOptionIds;
        sr.choice          = 'the third one';
        NM_SelectMentorAction.Response picked =
            NM_SelectMentorAction.selectMentor(new List<NM_SelectMentorAction.Request>{ sr })[0];

        System.assert(picked.resolved);
        System.assertEquals(opts.mentorOptionIds.split(';')[2], picked.mentorId,
            'Choosing the third must introduce them to the third');
    }
}
