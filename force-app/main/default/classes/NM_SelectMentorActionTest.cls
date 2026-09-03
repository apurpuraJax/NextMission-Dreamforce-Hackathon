/*****************************************************************
Name:          NM_SelectMentorActionTest
============================================================
Purpose:       Cover NM_SelectMentorAction.

               The rule that matters is that an unclear answer is
               never resolved into a guess. Introducing a veteran to
               the wrong person is not a small error, and it reads
               perfectly when it happens, so most of these assert
               that resolution did NOT occur.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, human-in-the-loop
*****************************************************************/
@IsTest
private class NM_SelectMentorActionTest {

    @testSetup
    static void seed() {
        insert new List<NM_Mentor__c>{
            new NM_Mentor__c(Name='Alex Rivera', Specialty_Cluster__c='healthcare',
                Branch__c='Army', Civilian_Role__c='Emergency Medical Technician',
                Employer__c='Metro Health System', Active__c=true),
            new NM_Mentor__c(Name='Dana Okafor', Specialty_Cluster__c='healthcare',
                Branch__c='Navy', Civilian_Role__c='Clinical Coordinator',
                Employer__c='Harbor Care', Active__c=true),
            new NM_Mentor__c(Name='Sam Whitfield', Specialty_Cluster__c='healthcare',
                Branch__c='Army', Civilian_Role__c='Paramedic',
                Employer__c='County EMS', Active__c=true)
        };
    }

    private static String idsOf(List<NM_Mentor__c> ms) {
        List<String> out = new List<String>();
        for (NM_Mentor__c m : ms) out.add(String.valueOf(m.Id));
        return String.join(out, ';');
    }

    private static List<NM_Mentor__c> three() {
        return [ SELECT Id, Name FROM NM_Mentor__c ORDER BY Name ];
    }

    private static NM_SelectMentorAction.Response run(String ids, String choice) {
        NM_SelectMentorAction.Request r = new NM_SelectMentorAction.Request();
        r.mentorOptionIds = ids;
        r.choice          = choice;
        return NM_SelectMentorAction.selectMentor(
            new List<NM_SelectMentorAction.Request>{ r })[0];
    }

    @IsTest
    static void anOrdinalResolvesHoweverItIsPhrased() {
        List<NM_Mentor__c> ms = three();
        String ids = idsOf(ms);
        for (String said : new List<String>{ '2', 'the second one', 'number two please', '2nd' }) {
            NM_SelectMentorAction.Response res = run(ids, said);
            System.assert(res.resolved, 'Must resolve: ' + said);
            System.assertEquals(ms[1].Id, (Id) res.mentorId,
                'Must be the SECOND mentor for: ' + said);
        }
    }

    @IsTest
    static void lastResolvesToTheEndOfTheShortlist() {
        List<NM_Mentor__c> ms = three();
        NM_SelectMentorAction.Response res = run(idsOf(ms), 'the last one');
        System.assert(res.resolved);
        System.assertEquals(ms[2].Id, (Id) res.mentorId);
    }

    @IsTest
    static void aFirstNameResolves() {
        List<NM_Mentor__c> ms = three();
        NM_SelectMentorAction.Response res = run(idsOf(ms), 'can you introduce me to Dana');
        System.assert(res.resolved, 'A first name must be enough');
        System.assertEquals('Dana Okafor', res.mentorName);
    }

    @IsTest
    static void anOutOfRangeNumberIsNotResolved() {
        // "7" against a list of three is a misread, not a choice.
        NM_SelectMentorAction.Response res = run(idsOf(three()), '7');
        System.assert(!res.resolved, 'Out of range must not resolve');
        System.assert(String.isNotBlank(res.message), 'They must be asked again');
    }

    @IsTest
    static void anAmbiguousNameIsNeverGuessed() {
        insert new NM_Mentor__c(Name='Alex Turner', Specialty_Cluster__c='healthcare',
            Branch__c='Army', Civilian_Role__c='Fleet Supervisor', Active__c=true);
        List<NM_Mentor__c> ms = [ SELECT Id, Name FROM NM_Mentor__c ORDER BY Name ];

        NM_SelectMentorAction.Response res = run(idsOf(ms), 'Alex');
        System.assert(!res.resolved,
            'Two people called Alex must never be silently narrowed to one');
        System.assert(res.message.containsIgnoreCase('more than one'),
            'The reason must be given so they can answer usefully');
    }

    @IsTest
    static void somethingUnrecognisableIsNotResolved() {
        for (String said : new List<String>{ 'yes please', 'whichever', '', null }) {
            System.assert(!run(idsOf(three()), said).resolved,
                'Must not resolve: ' + said);
        }
    }

    @IsTest
    static void aNameContainingNoNumberIsNeverReadAsOne() {
        // Guards ordinalIn: a name must not be parsed into a position.
        NM_SelectMentorAction.Response res = run(idsOf(three()), 'Whitfield');
        System.assert(res.resolved, 'A surname should still match');
        System.assertEquals('Sam Whitfield', res.mentorName);
    }

    @IsTest
    static void aLostShortlistAsksToLookAgain() {
        NM_SelectMentorAction.Response res = run('', '2');
        System.assert(!res.resolved);
        System.assert(String.isNotBlank(res.message));
    }

    @IsTest
    static void garbageIdsDoNotThrow() {
        NM_SelectMentorAction.Response res = run('not-an-id;also-not', '1');
        System.assert(!res.resolved, 'Nothing resolvable came back');
    }

    @IsTest
    static void bulkRequestsUseConstantQueries() {
        String ids = idsOf(three());
        List<NM_SelectMentorAction.Request> reqs = new List<NM_SelectMentorAction.Request>();
        for (Integer i = 0; i < 50; i++) {
            NM_SelectMentorAction.Request r = new NM_SelectMentorAction.Request();
            r.mentorOptionIds = ids;
            r.choice          = '1';
            reqs.add(r);
        }
        Test.startTest();
        List<NM_SelectMentorAction.Response> res = NM_SelectMentorAction.selectMentor(reqs);
        Test.stopTest();
        System.assertEquals(50, res.size());
        System.assert(Limits.getQueries() <= 3,
            'Must not query per request. Used ' + Limits.getQueries());
    }

    @IsTest
    static void findMentorReturnsAShortlistNotOneName() {
        NM_FindMentorAction.Request r = new NM_FindMentorAction.Request();
        r.clusterKey = 'healthcare';
        r.branch     = 'Army';
        NM_FindMentorAction.Response res =
            NM_FindMentorAction.findMentor(new List<NM_FindMentorAction.Request>{ r })[0];

        System.assert(res.found, 'A mentor exists for this cluster');
        System.assert(res.mentorOptionCount >= 2,
            'The veteran must be given a choice, not one name. Got ' + res.mentorOptionCount);
        System.assertEquals(res.mentorOptionCount, res.mentorOptionIds.split(';').size(),
            'Every option must carry an Id, or the choice cannot be honoured');
        System.assertEquals(res.mentorOptionCount, res.mentorOptions.split('\n').size(),
            'One line per option');
        System.assert(res.mentorOptions.startsWith('1. '),
            'Numbered, so someone can answer with a number');
    }

    @IsTest
    static void theShortlistIsCapped() {
        List<NM_Mentor__c> more = new List<NM_Mentor__c>();
        for (Integer i = 0; i < 6; i++) {
            more.add(new NM_Mentor__c(Name='Extra ' + i, Specialty_Cluster__c='healthcare',
                Branch__c='Army', Civilian_Role__c='Role', Active__c=true));
        }
        insert more;

        NM_FindMentorAction.Request r = new NM_FindMentorAction.Request();
        r.clusterKey = 'healthcare';
        r.branch     = 'Army';
        NM_FindMentorAction.Response res =
            NM_FindMentorAction.findMentor(new List<NM_FindMentorAction.Request>{ r })[0];

        System.assert(res.mentorOptionCount <= 3,
            'Three is the cap. A longer list is its own cognitive load problem.');
    }

    @IsTest
    static void theChoiceOfferedIsTheChoiceHonoured() {
        // End to end: whatever Find Mentor offered as option 2 is exactly what
        // Select Mentor returns for "the second one". This is the guarantee.
        NM_FindMentorAction.Request fr = new NM_FindMentorAction.Request();
        fr.clusterKey = 'healthcare';
        NM_FindMentorAction.Response found =
            NM_FindMentorAction.findMentor(new List<NM_FindMentorAction.Request>{ fr })[0];

        String secondId = found.mentorOptionIds.split(';')[1];
        NM_SelectMentorAction.Response picked = run(found.mentorOptionIds, 'the second one');

        System.assert(picked.resolved);
        System.assertEquals(secondId, picked.mentorId,
            'The mentor introduced must be the one they actually chose');
    }
}
