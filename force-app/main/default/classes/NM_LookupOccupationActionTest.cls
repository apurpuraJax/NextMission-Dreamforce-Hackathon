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
                Description__c='Compile, process, and maintain medical records.')
        };
        insert new List<NM_Military_Code_V2__c>{
            new NM_Military_Code_V2__c(Name='68W', External_Key__c='ARMY|68W', Branch__c='Army',
                Code_Value__c='68W', Role_Title__c='Combat Medic Specialist', ONET_Codes__c='29-2043.00'),
            new NM_Military_Code_V2__c(Name='68G', External_Key__c='ARMY|68G', Branch__c='Army',
                Code_Value__c='68G', Role_Title__c='Patient Administration Specialist', ONET_Codes__c='29-2072.00'),
            new NM_Military_Code_V2__c(Name='99Z', External_Key__c='ARMY|99Z', Branch__c='Army',
                Code_Value__c='99Z', Role_Title__c='Orphaned Code', ONET_Codes__c='00-0000.00')
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
}
