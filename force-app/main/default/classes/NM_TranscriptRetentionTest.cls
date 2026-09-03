/*****************************************************************
Name:          NM_TranscriptRetentionTest
============================================================
Purpose:       Cover NM_TranscriptRetention. The two things that
               matter: text older than the window is actually gone,
               and the anonymous analytics fields survive, because a
               retention job that quietly destroys the reporting is
               one somebody will switch off.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-03  Created   RAI reflection, privacy
*****************************************************************/
@IsTest
private class NM_TranscriptRetentionTest {

    private static NM_Conversation__c aged(String key, Integer daysOld) {
        NM_Conversation__c c = new NM_Conversation__c(
            External_Session_Key__c = key,
            Transcript__c = 'You: Army 68W\nAgent: Your background maps to Paramedics.',
            Summary__c    = 'Veteran explored healthcare roles.',
            Branch__c     = 'Army',
            Specialty_Code__c = '68W',
            Message_Count__c  = 4,
            QA_Score__c       = 9
        );
        insert c;
        if (daysOld > 0) {
            Test.setCreatedDate(c.Id, DateTime.now().addDays(-daysOld));
        }
        return c;
    }

    @IsTest
    static void textOlderThanTheWindowIsScrubbed() {
        NM_Conversation__c old = aged('old-1', NM_TranscriptRetention.RETAIN_DAYS + 5);

        Test.startTest();
        Database.executeBatch(new NM_TranscriptRetention(), 50);
        Test.stopTest();

        NM_Conversation__c after = [
            SELECT Transcript__c, Summary__c FROM NM_Conversation__c WHERE Id = :old.Id ];
        System.assertEquals(null, after.Transcript__c,
            'A transcript past the retention window must not still be here');
        System.assertEquals(null, after.Summary__c,
            'The generated summary is the same content in fewer words');
    }

    @IsTest
    static void theAnonymousShapeOfTheConversationSurvives() {
        NM_Conversation__c old = aged('old-2', NM_TranscriptRetention.RETAIN_DAYS + 5);

        Test.startTest();
        Database.executeBatch(new NM_TranscriptRetention(), 50);
        Test.stopTest();

        NM_Conversation__c after = [
            SELECT Branch__c, Specialty_Code__c, Message_Count__c, QA_Score__c
            FROM NM_Conversation__c WHERE Id = :old.Id ];
        System.assertEquals('Army', after.Branch__c, 'Branch is not personal data');
        System.assertEquals('68W', after.Specialty_Code__c);
        System.assertEquals(4, after.Message_Count__c);
        System.assertEquals(9, after.QA_Score__c,
            'Scrubbing must not destroy the QA record the grader produced');
    }

    @IsTest
    static void recentConversationsAreLeftAlone() {
        NM_Conversation__c fresh = aged('fresh-1', 3);

        Test.startTest();
        Database.executeBatch(new NM_TranscriptRetention(), 50);
        Test.stopTest();

        NM_Conversation__c after = [
            SELECT Transcript__c FROM NM_Conversation__c WHERE Id = :fresh.Id ];
        System.assertNotEquals(null, after.Transcript__c,
            'Inside the window the transcript is still needed');
    }

    @IsTest
    static void theScheduleRuns() {
        Test.startTest();
        String jobId = System.schedule('NM Retention Test',
            '0 0 3 * * ?', new NM_TranscriptRetention());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'The job must be schedulable');
    }
}
