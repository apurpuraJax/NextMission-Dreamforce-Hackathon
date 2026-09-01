/*****************************************************************
Name:          NM_QAScheduler
============================================================
Purpose:       Schedulable Apex that fires the QA grader.
               Enqueues NM_QAEvaluator at each scheduled run.

               RUNS HOURLY. Deploy then schedule via anonymous Apex:
               System.schedule('NM Daily QA Grader', '0 0 * * * ?', new NM_QAScheduler());

               Hourly is the intended cadence, decided 2026-09-01. The
               registered job name still says "Daily" because it is the
               name already in the org and in CONTEXT.md; the name is
               historical, the expression is correct. Do not "fix" the
               cadence back to daily.

               Deploying this class, or NM_QAEvaluator, fails while the job
               is scheduled ("This schedulable class has jobs pending or in
               progress"). Abort, deploy, then reschedule with the SAME
               expression above.

               Note: System.schedule uses the SCHEDULING USER'S timezone,
               not GMT. Confirm with a CronTrigger query afterwards.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-29   Created   NMDH-19
1.1      Claude       2026-09-01   Updated   Document hourly cadence (NMDH-19)
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
