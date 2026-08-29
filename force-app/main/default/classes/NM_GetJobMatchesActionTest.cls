/*****************************************************************
Name:          NM_GetJobMatchesActionTest
============================================================
Purpose:       Unit tests for NM_GetJobMatchesAction.
               Custom Metadata records are accessible in Apex tests
               without @SeeAllData; no test data setup is required
               for CMDT queries.

               Coverage target: 90%+
               Test scenarios:
                 1. Happy path — known cluster key (Aviation)
                 2. Unknown cluster key — success=false path
                 3. Null cluster key — must not throw
                 4. Blank cluster key — must not throw
                 5. Malformed JSON — parseClusterData returns success=false
                 6. Blank JSON — parseClusterData returns success=false
                 7. Bulk-safe — 22 inputs, mix of valid and unknown
                 8. Empty JSON array — parseClusterData returns success=false
============================================================
History
-------
VERSION  AUTHOR              DATE         DETAIL    DESCRIPTION
1.0      Revecast Orch.      2026-08-29   Created   NMDH-7
*****************************************************************/
@isTest
public class NM_GetJobMatchesActionTest {

    // ----- 1. Happy path: known cluster Aviation ----------------------------

    @isTest
    static void testHappyPath_KnownCluster() {
        // Aviation is seeded in NM_Specialty_Cluster__mdt with 5 jobs
        NM_GetJobMatchesAction.Input inp = new NM_GetJobMatchesAction.Input();
        inp.clusterKey = 'Aviation';

        Test.startTest();
        List<NM_GetJobMatchesAction.Response> results =
            NM_GetJobMatchesAction.getJobMatches(
                new List<NM_GetJobMatchesAction.Input>{ inp });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one response for one input');
        NM_GetJobMatchesAction.Response r = results[0];
        System.assertEquals(true,  r.success,  'Expected success=true for Aviation cluster');
        System.assertNotEquals(null, r.jobsJson, 'jobsJson must be populated on success=true');
        System.assert(r.jobsJson.startsWith('['), 'jobsJson must be a JSON array');
        System.assertEquals(null, r.message, 'message must be null when success=true');
    }

    // ----- 2. Unknown cluster returns success=false -------------------------

    @isTest
    static void testUnknownCluster_ReturnsNotFound() {
        NM_GetJobMatchesAction.Input inp = new NM_GetJobMatchesAction.Input();
        inp.clusterKey = 'ZZZZ_DOES_NOT_EXIST';

        Test.startTest();
        List<NM_GetJobMatchesAction.Response> results =
            NM_GetJobMatchesAction.getJobMatches(
                new List<NM_GetJobMatchesAction.Input>{ inp });
        Test.stopTest();

        NM_GetJobMatchesAction.Response r = results[0];
        System.assertEquals(false, r.success,  'Unknown cluster must return success=false');
        System.assertNotEquals(null, r.message, 'message must be populated when success=false');
        System.assertEquals(null, r.jobsJson,   'jobsJson must be null when success=false');
    }

    // ----- 3. Null cluster key must not throw -------------------------------

    @isTest
    static void testNullClusterKey_DoesNotThrow() {
        NM_GetJobMatchesAction.Input inp = new NM_GetJobMatchesAction.Input();
        inp.clusterKey = null;

        Test.startTest();
        List<NM_GetJobMatchesAction.Response> results =
            NM_GetJobMatchesAction.getJobMatches(
                new List<NM_GetJobMatchesAction.Input>{ inp });
        Test.stopTest();

        System.assertEquals(1,     results.size(),      'Expected one response');
        System.assertEquals(false, results[0].success,  'Null key must return success=false without throwing');
        System.assertNotEquals(null, results[0].message, 'message must be populated');
    }

    // ----- 4. Blank cluster key must not throw ------------------------------

    @isTest
    static void testBlankClusterKey_DoesNotThrow() {
        NM_GetJobMatchesAction.Input inp = new NM_GetJobMatchesAction.Input();
        inp.clusterKey = '   ';

        Test.startTest();
        List<NM_GetJobMatchesAction.Response> results =
            NM_GetJobMatchesAction.getJobMatches(
                new List<NM_GetJobMatchesAction.Input>{ inp });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Blank key must return success=false');
    }

    // ----- 5. Malformed JSON via parseClusterData ---------------------------

    @isTest
    static void testMalformedJson_DoesNotThrow() {
        Test.startTest();
        NM_GetJobMatchesAction.Response r =
            NM_GetJobMatchesAction.parseClusterData('TestCluster', '{not valid json]');
        Test.stopTest();

        System.assertEquals(false, r.success,
            'Malformed JSON must return success=false');
        System.assertNotEquals(null, r.message,
            'message must be populated when JSON is malformed');
        System.assertEquals(null, r.jobsJson,
            'jobsJson must be null when JSON is malformed');
    }

    // ----- 6. Blank raw JSON via parseClusterData ---------------------------

    @isTest
    static void testBlankJson_ReturnsNotFound() {
        Test.startTest();
        NM_GetJobMatchesAction.Response r =
            NM_GetJobMatchesAction.parseClusterData('TestCluster', '');
        Test.stopTest();

        System.assertEquals(false, r.success,  'Blank JSON must return success=false');
        System.assertNotEquals(null, r.message, 'message must be populated');
    }

    // ----- 7. Bulk-safe: 22 inputs, mix of valid and unknown ----------------

    @isTest
    static void testBulkSafe_22Inputs() {
        List<NM_GetJobMatchesAction.Input> inputs =
            new List<NM_GetJobMatchesAction.Input>();

        // Even-indexed: real Aviation cluster; odd-indexed: unknown
        for (Integer i = 0; i < 22; i++) {
            NM_GetJobMatchesAction.Input inp = new NM_GetJobMatchesAction.Input();
            inp.clusterKey = (Math.mod(i, 2) == 0) ? 'Aviation' : 'BULK_UNKNOWN_' + i;
            inputs.add(inp);
        }

        Test.startTest();
        List<NM_GetJobMatchesAction.Response> results =
            NM_GetJobMatchesAction.getJobMatches(inputs);
        Test.stopTest();

        System.assertEquals(22, results.size(), 'Expected 22 responses for 22 inputs');

        for (Integer i = 0; i < results.size(); i++) {
            NM_GetJobMatchesAction.Response r = results[i];
            System.assertNotEquals(null, r.success,
                'success must never be null (index ' + i + ')');
            if (r.success) {
                System.assertNotEquals(null, r.jobsJson,
                    'jobsJson must be populated when success=true (index ' + i + ')');
                System.assertEquals(null, r.message,
                    'message must be null when success=true (index ' + i + ')');
            } else {
                System.assertNotEquals(null, r.message,
                    'message must be populated when success=false (index ' + i + ')');
            }
        }
    }

    // ----- 8. Empty JSON array via parseClusterData -------------------------

    @isTest
    static void testEmptyJsonArray_ReturnsNotFound() {
        Test.startTest();
        NM_GetJobMatchesAction.Response r =
            NM_GetJobMatchesAction.parseClusterData('TestCluster', '[]');
        Test.stopTest();

        System.assertEquals(false, r.success,  'Empty array must return success=false');
        System.assertNotEquals(null, r.message, 'message must be populated');
    }
}
