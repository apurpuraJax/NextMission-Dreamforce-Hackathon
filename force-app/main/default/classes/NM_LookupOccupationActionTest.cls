/*****************************************************************
Name:          NM_LookupOccupationActionTest
Purpose:       Tests for NM_LookupOccupationAction (NMDH-22).
               Seeds its own data so it does not depend on the
               loaded crosswalk.
*****************************************************************/
@isTest
private class NM_LookupOccupationActionTest {

    @testSetup
    static void seed() {
        insert new List<NM_Occupation__c>{
            new NM_Occupation__c(Name='Paramedics', ONET_Code__c='29-2043.00',
                Description__c='Administer basic or advanced emergency medical care.'),
            new NM_Occupation__c(Name='Medical Records Specialists', ONET_Code__c='29-2072.00',
                Description__c='Compile, process, and maintain medical records.'),
            // A military-only SOC. Loaded in the org, but never a civilian answer.
            new NM_Occupation__c(Name='Infantry', ONET_Code__c='55-3016.00',
                Description__c='Operate weapons and equipment in ground combat operations.'),
            new NM_Occupation__c(Name='Heavy and Tractor-Trailer Truck Drivers', ONET_Code__c='53-3032.00',
                Description__c='Drive a tractor-trailer combination or a truck.')
        };
        insert new List<NM_Military_Code_V2__c>{
            new NM_Military_Code_V2__c(Name='68W', External_Key__c='ARMY|68W', Branch__c='Army',
                Code_Value__c='68W', Role_Title__c='Combat Medic Specialist', ONET_Codes__c='29-2043.00'),
            new NM_Military_Code_V2__c(Name='68G', External_Key__c='ARMY|68G', Branch__c='Army',
                Code_Value__c='68G', Role_Title__c='Patient Administration Specialist', ONET_Codes__c='29-2072.00'),
            new NM_Military_Code_V2__c(Name='99Z', External_Key__c='ARMY|99Z', Branch__c='Army',
                Code_Value__c='99Z', Role_Title__c='Orphaned Code', ONET_Codes__c='00-0000.00'),
            // Maps ONLY to a military SOC, like 1,001 of the 8,179 real codes.
            new NM_Military_Code_V2__c(Name='11B', External_Key__c='ARMY|11B', Branch__c='Army',
                Code_Value__c='11B', Role_Title__c='Infantryman', ONET_Codes__c='55-3016.00'),
            new NM_Military_Code_V2__c(Name='88M', External_Key__c='ARMY|88M', Branch__c='Army',
                Code_Value__c='88M', Role_Title__c='Motor Transport Operator', ONET_Codes__c='53-3032.00'),
            // Mixed: one military SOC and one real civilian occupation. The
            // military one must be dropped and the civilian one kept.
            new NM_Military_Code_V2__c(Name='MIX1', External_Key__c='ARMY|MIX1', Branch__c='Army',
                Code_Value__c='MIX1', Role_Title__c='Mixed Mapping', ONET_Codes__c='55-3016.00;53-3032.00')
        };
    }

    private static NM_LookupOccupationAction.Request req(String b, String c) {
        NM_LookupOccupationAction.Request r = new NM_LookupOccupationAction.Request();
        r.branch = b; r.code = c; return r;
    }

    @isTest
    static void twoCodesInOneOldClusterReturnDifferentOccupations() {
        Test.startTest();
        List<NM_LookupOccupationAction.Response> res = NM_LookupOccupationAction.lookupOccupations(
            new List<NM_LookupOccupationAction.Request>{ req('Army','68W'), req('Army','68G') });
        Test.stopTest();
        System.assertEquals(true, res[0].found, '68W should resolve');
        System.assertEquals(true, res[1].found, '68G should resolve');
        System.assertEquals('Combat Medic Specialist', res[0].roleTitle);
        System.assertEquals('Patient Administration Specialist', res[1].roleTitle);
        System.assertNotEquals(res[0].occupations, res[1].occupations,
            'This is the point of NMDH-22: two codes that shared a cluster must differ');
    }

    @isTest
    static void caseAndWhitespaceAreNormalised() {
        Test.startTest();
        List<NM_LookupOccupationAction.Response> res = NM_LookupOccupationAction.lookupOccupations(
            new List<NM_LookupOccupationAction.Request>{ req(' army ',' 68w ') });
        Test.stopTest();
        System.assertEquals(true, res[0].found, 'lowercase and padded input should still resolve');
    }

    @isTest
    static void unknownCodeDoesNotBlameTheVeteran() {
        Test.startTest();
        List<NM_LookupOccupationAction.Response> res = NM_LookupOccupationAction.lookupOccupations(
            new List<NM_LookupOccupationAction.Request>{ req('Army','ZZZ9') });
        Test.stopTest();
        System.assertEquals(false, res[0].found);
        System.assertEquals(0, res[0].occupationCount);
        System.assert(!res[0].message.containsIgnoreCase('recognize'),
            'Message must not imply the veteran typed it wrong');
    }

    @isTest
    static void codeWithNoResolvableOccupationReturnsNotFound() {
        Test.startTest();
        List<NM_LookupOccupationAction.Response> res = NM_LookupOccupationAction.lookupOccupations(
            new List<NM_LookupOccupationAction.Request>{ req('Army','99Z') });
        Test.stopTest();
        System.assertEquals(false, res[0].found, 'orphaned ONET code should not report success');
    }

    @isTest
    static void blankInputIsHandled() {
        Test.startTest();
        List<NM_LookupOccupationAction.Response> res = NM_LookupOccupationAction.lookupOccupations(
            new List<NM_LookupOccupationAction.Request>{ req(null,'68W'), req('Army',null) });
        Test.stopTest();
        System.assertEquals(false, res[0].found);
        System.assertEquals(false, res[1].found);
    }

    @isTest
    static void bulkRequestsUseConstantQueries() {
        List<NM_LookupOccupationAction.Request> reqs = new List<NM_LookupOccupationAction.Request>();
        for (Integer i = 0; i < 200; i++) reqs.add(req('Army', Math.mod(i,2)==0 ? '68W' : '68G'));
        Test.startTest();
        List<NM_LookupOccupationAction.Response> res = NM_LookupOccupationAction.lookupOccupations(reqs);
        Test.stopTest();
        System.assertEquals(200, res.size());
        System.assert(Limits.getQueries() <= 4, 'Must stay bulk safe; queries used: ' + Limits.getQueries());
    }

    /*
     * NMDH-33. 1,001 of 8,179 codes map ONLY to the 55-xx military SOC family.
     * Returning "Infantry" as somebody's civilian match is worse than returning
     * nothing, because it reads as an answer and cannot be applied for.
     *
     * The distinction that matters: the code IS found and the role title IS
     * real. Only the civilian occupation is absent. Reporting that as an
     * unknown code would be a different lie.
     */
    @isTest
    static void testMilitaryOnlyCodeIsNotPresentedAsCivilian() {
        NM_LookupOccupationAction.Request r = new NM_LookupOccupationAction.Request();
        r.branch = 'Army';
        r.code   = '11B';

        Test.startTest();
        NM_LookupOccupationAction.Response res =
            NM_LookupOccupationAction.lookupOccupations(
                new List<NM_LookupOccupationAction.Request>{ r })[0];
        Test.stopTest();

        System.assertEquals(true, res.militaryOnly,
            '11B maps only to 55-3016.00 and must be flagged as military-only');
        System.assertEquals(true, res.found,
            'The code IS in the crosswalk; this is not an unknown code');
        System.assertNotEquals(null, res.roleTitle,
            'The military role title is still real and should be named');
        System.assertEquals(0, res.occupationCount,
            'No civilian occupation may be returned for a military-only code');
        System.assert(String.isBlank(res.occupations),
            'Infantry must never appear as a civilian occupation');
    }

    @isTest
    static void testCivilianCodeIsUnaffectedByTheGuard() {
        NM_LookupOccupationAction.Request r = new NM_LookupOccupationAction.Request();
        r.branch = 'Army';
        r.code   = '88M';

        Test.startTest();
        NM_LookupOccupationAction.Response res =
            NM_LookupOccupationAction.lookupOccupations(
                new List<NM_LookupOccupationAction.Request>{ r })[0];
        Test.stopTest();

        System.assertEquals(false, res.militaryOnly,
            '88M has a real civilian occupation and must not be flagged');
        System.assert(res.occupationCount > 0,
            'The guard must not strip civilian occupations');
    }

    @isTest
    static void testGuardRecognisesTheMilitarySOCFamily() {
        System.assertEquals(true,  NM_LookupOccupationAction.isMilitaryOnlyONET('55-3016.00'));
        System.assertEquals(true,  NM_LookupOccupationAction.isMilitaryOnlyONET('55-3019.00'));
        System.assertEquals(false, NM_LookupOccupationAction.isMilitaryOnlyONET('53-3032.00'));
        System.assertEquals(false, NM_LookupOccupationAction.isMilitaryOnlyONET('29-2043.00'));
        System.assertEquals(false, NM_LookupOccupationAction.isMilitaryOnlyONET(null));
    }

    @isTest
    static void testMixedMappingKeepsTheCivilianHalf() {
        Test.startTest();
        NM_LookupOccupationAction.Response res =
            NM_LookupOccupationAction.lookupOccupations(
                new List<NM_LookupOccupationAction.Request>{ req('Army', 'MIX1') })[0];
        Test.stopTest();

        System.assertEquals(false, res.militaryOnly,
            'A code with any civilian occupation is not military-only');
        System.assertEquals(1, res.occupationCount,
            'The military SOC is dropped and the civilian occupation kept');
        System.assert(res.occupations.contains('Truck Drivers'),
            'The civilian occupation must survive the guard');
        System.assert(!res.occupations.contains('Infantry'),
            'The military SOC must never appear');
    }
}
