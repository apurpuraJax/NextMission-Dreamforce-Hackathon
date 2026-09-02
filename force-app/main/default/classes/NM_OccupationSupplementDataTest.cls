/*****************************************************************
Name:          NM_OccupationSupplementDataTest
============================================================
Purpose:       Guards the one rule NMDH-37 must never break: every
               adjacent occupation a veteran is shown has to be a
               real O*NET row.

               A typo in NM_Occupation_Supplement__mdt would not
               throw. It would silently drop that role and show a
               shorter list, which looks like a thin mapping rather
               than like a bug. This turns that into a failure.

               SeeAllData is required and deliberate: the supplement
               records ARE the fix, and a mocked version of this
               check would pass even if nothing were deployed. It is
               read-only and asserts on data, so it does not create
               the usual SeeAllData fragility.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-02  Created   NMDH-37
*****************************************************************/
@IsTest(SeeAllData=true)
private class NM_OccupationSupplementDataTest {

    @IsTest
    static void everyAdjacentCodeResolvesToARealOccupation() {
        Set<String> wanted = new Set<String>();
        for (NM_Occupation_Supplement__mdt sup :
                NM_Occupation_Supplement__mdt.getAll().values()) {
            wanted.addAll(NM_LookupOccupationAction.splitCodes(sup.Adjacent_ONET_Codes__c));
        }
        System.assert(!wanted.isEmpty(),
            'Supplement records must be deployed for this fix to do anything');

        Set<String> found = new Set<String>();
        for (NM_Occupation__c o : [
                SELECT ONET_Code__c FROM NM_Occupation__c
                WHERE  ONET_Code__c IN :wanted]) {
            found.add(o.ONET_Code__c);
        }
        wanted.removeAll(found);
        System.assert(wanted.isEmpty(),
            'Every adjacent SOC must resolve to a real occupation. Ungrounded: ' + wanted);
    }

    @IsTest
    static void noSupplementOffersAMilitaryOnlySOC() {
        // NMDH-33 closed the door on presenting a 55-xx military SOC as a civilian
        // job. A supplement must not reopen it.
        for (NM_Occupation_Supplement__mdt sup :
                NM_Occupation_Supplement__mdt.getAll().values()) {
            for (String c : NM_LookupOccupationAction.splitCodes(sup.Adjacent_ONET_Codes__c)) {
                System.assert(!c.startsWith('55-'),
                    'Supplement ' + sup.Match_Key__c + ' offers a military-only SOC: ' + c);
            }
        }
    }
}
