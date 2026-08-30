/*****************************************************************
Name:          NM_LookupMilitaryCodeActionTest
============================================================
Purpose:       Unit tests for NM_LookupMilitaryCodeAction.
               Custom Metadata records are accessible in Apex tests
               without @SeeAllData; no test data setup is required
               for CMDT queries.

               Coverage target: 90%+
               Test scenarios:
                 1. Happy path — exact match (live CMDT seed record)
                 2. Case-insensitive input (lowercase Branch/Code from CMDT seed)
                 3. Unrecognized code — not-found path
                 4. Bulk-safe — 22 inputs, 11 CMDT-seeded valid pairs + 11 invalid
                 5. Null branch and code — must not throw
============================================================
History
-------
VERSION  AUTHOR              DATE         DETAIL    DESCRIPTION
1.0      Revecast Orch.      2026-08-29   Created   NMDH-5
1.1      Revecast Orch.      2026-08-30   Updated   NMDH-5 — CMDT-driven assertions;
                                                     removed hardcoded Army/Navy pairs
*****************************************************************/
@isTest
public class NM_LookupMilitaryCodeActionTest {

    // ----- 1. Happy path: exact match driven by live CMDT seed -------------

    @isTest
    static void testHappyPath_ExactMatch() {
        // Query one real CMDT record so assertions never depend on hardcoded values.
        NM_Military_Code__mdt seed = [
            SELECT Branch__c, Code_Value__c, Role_Title__c, Cluster_Key__c
            FROM   NM_Military_Code__mdt
            LIMIT  1
        ];

        NM_LookupMilitaryCodeAction.Input inp = new NM_LookupMilitaryCodeAction.Input();
        inp.branch = seed.Branch__c;
        inp.code   = seed.Code_Value__c;

        Test.startTest();
        List<NM_LookupMilitaryCodeAction.Response> results =
            NM_LookupMilitaryCodeAction.lookupCode(
                new List<NM_LookupMilitaryCodeAction.Input>{ inp });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One response expected for one input');
        NM_LookupMilitaryCodeAction.Response r = results[0];
        System.assertEquals(true,                r.found,
            'Expected found=true for seeded CMDT record');
        System.assertEquals(seed.Role_Title__c,  r.roleTitle,
            'Expected roleTitle to match CMDT seed');
        System.assertEquals(seed.Cluster_Key__c, r.clusterKey,
            'Expected clusterKey to match CMDT seed');
        System.assertNotEquals(null,             r.clusterLabel,
            'clusterLabel must be populated on found=true');
        System.assertEquals(null,                r.notFoundMessage,
            'notFoundMessage must be null when found=true');
    }

    // ----- 2. Case-insensitive: lowercase branch and code from CMDT seed ---

    @isTest
    static void testCaseInsensitive_LowercaseInput() {
        // Same CMDT seed; pass branch and code fully lowercased to confirm
        // the normalization (branch.toLowerCase() + '|' + code.toUpperCase()) works.
        NM_Military_Code__mdt seed = [
            SELECT Branch__c, Code_Value__c, Role_Title__c
            FROM   NM_Military_Code__mdt
            LIMIT  1
        ];

        NM_LookupMilitaryCodeAction.Input inp = new NM_LookupMilitaryCodeAction.Input();
        inp.branch = seed.Branch__c.toLowerCase();
        inp.code   = seed.Code_Value__c.toLowerCase();

        Test.startTest();
        List<NM_LookupMilitaryCodeAction.Response> results =
            NM_LookupMilitaryCodeAction.lookupCode(
                new List<NM_LookupMilitaryCodeAction.Input>{ inp });
        Test.stopTest();

        System.assertEquals(true,              results[0].found,
            'Lowercase input should still match');
        System.assertEquals(seed.Role_Title__c, results[0].roleTitle,
            'roleTitle should match regardless of case');
        System.assertNotEquals(null,            results[0].clusterLabel,
            'clusterLabel must be populated');
    }

    // ----- 3. Not-found path: unrecognized code -----------------------------

    @isTest
    static void testUnrecognizedCode_ReturnsNotFound() {
        NM_LookupMilitaryCodeAction.Input inp = new NM_LookupMilitaryCodeAction.Input();
        inp.branch = 'Army';
        inp.code   = 'ZZZZ';

        Test.startTest();
        List<NM_LookupMilitaryCodeAction.Response> results =
            NM_LookupMilitaryCodeAction.lookupCode(
                new List<NM_LookupMilitaryCodeAction.Input>{ inp });
        Test.stopTest();

        NM_LookupMilitaryCodeAction.Response r = results[0];
        System.assertEquals(false,  r.found,
            'Expected found=false for unknown code');
        System.assertNotEquals(null, r.notFoundMessage,
            'notFoundMessage must be populated when not found');
        System.assert(
            r.notFoundMessage.startsWith('I don\'t recognize'),
            'notFoundMessage must match the standard not-found text');
        System.assertEquals(null, r.roleTitle,
            'roleTitle must be null when not found');
        System.assertEquals(null, r.clusterKey,
            'clusterKey must be null when not found');
        System.assertEquals(null, r.clusterLabel,
            'clusterLabel must be null when not found');
    }

    // ----- 4. Bulk-safe: 22 inputs — 11 CMDT-seeded valid + 11 invalid -----

    @isTest
    static void testBulkSafe_22Inputs() {
        // Pull up to 11 real CMDT records; no hardcoded MOS codes.
        List<NM_Military_Code__mdt> seedRecs = [
            SELECT Branch__c, Code_Value__c
            FROM   NM_Military_Code__mdt
            LIMIT  11
        ];

        List<NM_LookupMilitaryCodeAction.Input> inputs =
            new List<NM_LookupMilitaryCodeAction.Input>();

        // Even index i → valid pair from seedRecs[i/2];
        // Odd index i  → deliberately invalid BULK_UNKNOWN_<i>.
        for (Integer i = 0; i < 22; i++) {
            NM_LookupMilitaryCodeAction.Input inp = new NM_LookupMilitaryCodeAction.Input();
            Integer pairIdx = i / 2;
            if (Math.mod(i, 2) == 0 && pairIdx < seedRecs.size()) {
                inp.branch = seedRecs[pairIdx].Branch__c;
                inp.code   = seedRecs[pairIdx].Code_Value__c;
            } else {
                inp.branch = 'Army';
                inp.code   = 'BULK_UNKNOWN_' + String.valueOf(i);
            }
            inputs.add(inp);
        }

        Test.startTest();
        List<NM_LookupMilitaryCodeAction.Response> results =
            NM_LookupMilitaryCodeAction.lookupCode(inputs);
        Test.stopTest();

        System.assertEquals(22, results.size(), 'Expected 22 responses for 22 inputs');

        for (Integer i = 0; i < results.size(); i++) {
            NM_LookupMilitaryCodeAction.Response r = results[i];
            System.assertNotEquals(null, r.found,
                'found must never be null (input index ' + i + ')');

            if (r.found) {
                System.assertNotEquals(null, r.roleTitle,
                    'found=true requires roleTitle (index ' + i + ')');
                System.assertNotEquals(null, r.clusterKey,
                    'found=true requires clusterKey (index ' + i + ')');
            } else {
                System.assertNotEquals(null, r.notFoundMessage,
                    'found=false requires notFoundMessage (index ' + i + ')');
            }
        }
    }

    // ----- 5. Null inputs must not throw ------------------------------------

    @isTest
    static void testNullBranchAndCode_DoesNotThrow() {
        NM_LookupMilitaryCodeAction.Input inp = new NM_LookupMilitaryCodeAction.Input();
        inp.branch = null;
        inp.code   = null;

        Test.startTest();
        List<NM_LookupMilitaryCodeAction.Response> results =
            NM_LookupMilitaryCodeAction.lookupCode(
                new List<NM_LookupMilitaryCodeAction.Input>{ inp });
        Test.stopTest();

        System.assertEquals(false, results[0].found,
            'Null branch and code should return found=false without throwing');
        System.assertNotEquals(null, results[0].notFoundMessage,
            'notFoundMessage must be populated when input is null');
    }
}
