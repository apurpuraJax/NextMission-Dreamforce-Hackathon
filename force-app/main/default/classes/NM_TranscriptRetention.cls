/*****************************************************************
Name:          NM_TranscriptRetention
============================================================
Purpose:       Put a limit on how long a veteran's words are kept.

               The site has no login and stores nothing that names
               a person, and that led to describing it as if nothing
               were kept at all. It is not: the widget sends a
               cumulative transcript every turn, so conversations sat
               in the org indefinitely. Anonymous is not ephemeral,
               and unbounded retention is a decision even when nobody
               makes it on purpose.

               This SCRUBS rather than deletes. The free text and the
               generated summary go; the anonymous shape of the
               conversation stays, so branch, specialty, message count
               and QA score remain available for the reporting they
               were collected for. Keeping the aggregate costs nobody
               anything. Keeping the narrative does.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, privacy
*****************************************************************/
public with sharing class NM_TranscriptRetention
        implements Database.Batchable<SObject>, Schedulable {

    // Ninety days. Long enough for the QA evaluator to review a conversation
    // and for a pattern to show up across a quarter; short enough that a
    // disclosure someone made in passing does not sit here for years.
    // Changing this number is a governance decision, not a tuning knob.
    @TestVisible
    public static final Integer RETAIN_DAYS = 90;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoff = DateTime.now().addDays(-RETAIN_DAYS);
        return Database.getQueryLocator([
            SELECT Id, Transcript__c, Summary__c
            FROM   NM_Conversation__c
            WHERE  CreatedDate < :cutoff
        ]);
        // No "Transcript__c != null" filter: a Long Text Area cannot be
        // filtered in SOQL. Already-scrubbed rows are skipped in execute.
    }

    public void execute(Database.BatchableContext bc, List<NM_Conversation__c> scope) {
        List<NM_Conversation__c> toScrub = new List<NM_Conversation__c>();
        for (NM_Conversation__c c : scope) {
            if (c.Transcript__c == null && c.Summary__c == null) continue;
            c.Transcript__c = null;
            c.Summary__c    = null;
            toScrub.add(c);
        }
        if (toScrub.isEmpty()) return;
        // allOrNone false: one bad row must not strand the rest of the batch
        // still holding text that is past its retention window.
        Database.update(toScrub, false);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('NM_TranscriptRetention finished for cutoff of '
            + RETAIN_DAYS + ' days');
    }

    /*
     * Purpose:    Daily entry point. Small batch size because the transcript
     *             is a long text field and the rows are heavy.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new NM_TranscriptRetention(), 50);
    }
}
