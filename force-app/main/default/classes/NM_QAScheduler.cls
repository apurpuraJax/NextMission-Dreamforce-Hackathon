/*****************************************************************
Name:          NM_QAScheduler
============================================================
Purpose:       Schedulable Apex that fires the daily QA grader.
               Enqueues NM_QAEvaluator at each scheduled run.
               Deploy then schedule via anonymous Apex:
               System.schedule('NM Daily QA Grader', '0 0 6 * * ?', new NM_QAScheduler());
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-29   Created   NMDH-19
*****************************************************************/
public class NM_QAScheduler implements Schedulable {

    /*****************************************************************
    Purpose:       Called by the platform at each scheduled interval.
                   Enqueues NM_QAEvaluator to begin grading.
    Parameters:    context — provided by the platform
    *****************************************************************/
    public void execute(SchedulableContext context) {
        System.debug('Entering NM_QAScheduler.execute: enqueueing NM_QAEvaluator');
        System.enqueueJob(new NM_QAEvaluator());
        System.debug('Exiting NM_QAScheduler.execute');
    }
}
