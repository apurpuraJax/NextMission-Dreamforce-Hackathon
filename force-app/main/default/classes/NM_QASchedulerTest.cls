/*****************************************************************
Name:          NM_QASchedulerTest
============================================================
Purpose:       Unit tests for NM_QAScheduler.
               Verifies execute() completes without exception and
               that System.schedule() wires up the job correctly.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-29   Created   NMDH-19
*****************************************************************/
@isTest
private class NM_QASchedulerTest {

    @isTest
    static void testSchedulerExecutesWithoutError() {
        // Inject mock so the enqueued NM_QAEvaluator (0 records) does not error
        NM_QAEvaluator.mockResponseJson = null; // no records → nothing to grade

        Test.startTest();
        NM_QAScheduler scheduler = new NM_QAScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // If we reach here, execute() completed without an unhandled exception
        System.assert(true, 'NM_QAScheduler.execute completed without exception');
    }

    @isTest
    static void testSystemScheduleReturnsJobId() {
        Test.startTest();
        String jobId = System.schedule(
            'NM Daily QA Grader Test',
            '0 0 6 * * ?',
            new NM_QAScheduler()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'System.schedule should return a non-null job ID');
        System.assert(jobId.length() > 0, 'Job ID should be a non-empty string');
    }
}
