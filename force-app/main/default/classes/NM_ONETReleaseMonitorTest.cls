@isTest
private class NM_ONETReleaseMonitorTest {

    private class PageMock implements HttpCalloutMock {
        private Integer code; private String body;
        PageMock(Integer c, String b) { code = c; body = b; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code);
            r.setBody(body);
            return r;
        }
    }

    @isTest
    static void detectsANewerReleaseThanTheOneLoaded() {
        insert new NM_Data_Config__c(SetupOwnerId = UserInfo.getOrganizationId(),
                                     Loaded_ONET_Release__c = 'db_29_1');
        Test.setMock(HttpCalloutMock.class, new PageMock(200,
            '<a href="/dl_files/database/db_31_0_text.zip">O*NET 31.0 Database</a>'));
        Test.startTest();
        String latest = NM_ONETReleaseMonitor.checkForNewRelease();
        Test.stopTest();

        System.assertEquals('db_31_0', latest);
        NM_Data_Config__c cfg = NM_Data_Config__c.getOrgDefaults();
        System.assertEquals(true, cfg.Refresh_Needed__c, 'stale data must be flagged');
        System.assertNotEquals(null, cfg.Last_Checked__c);
    }

    @isTest
    static void doesNotFlagWhenAlreadyCurrent() {
        insert new NM_Data_Config__c(SetupOwnerId = UserInfo.getOrganizationId(),
                                     Loaded_ONET_Release__c = 'db_31_0');
        Test.setMock(HttpCalloutMock.class, new PageMock(200, 'db_31_0 current'));
        Test.startTest();
        NM_ONETReleaseMonitor.checkForNewRelease();
        Test.stopTest();
        System.assertEquals(false, NM_Data_Config__c.getOrgDefaults().Refresh_Needed__c);
    }

    @isTest
    static void picksTheHighestReleaseNotTheFirstMentioned() {
        System.assertEquals('db_31_0',
            NM_ONETReleaseMonitor.extractRelease('older db_28_3 and db_29_1 then db_31_0 newest'));
        System.assertEquals('db_31_0',
            NM_ONETReleaseMonitor.extractRelease('db_31_0 then db_29_1'));
    }

    @isTest
    static void survivesAnUnreachablePage() {
        insert new NM_Data_Config__c(SetupOwnerId = UserInfo.getOrganizationId(),
                                     Loaded_ONET_Release__c = 'db_29_1');
        Test.setMock(HttpCalloutMock.class, new PageMock(503, 'unavailable'));
        Test.startTest();
        String latest = NM_ONETReleaseMonitor.checkForNewRelease();
        Test.stopTest();
        System.assertEquals(null, latest, 'a broken page must not throw');
        System.assertNotEquals(null, NM_Data_Config__c.getOrgDefaults().Last_Checked__c,
            'the check should still be recorded');
    }

    @isTest
    static void handlesAPageWithNoReleaseToken() {
        System.assertEquals(null, NM_ONETReleaseMonitor.extractRelease('nothing here'));
        System.assertEquals(null, NM_ONETReleaseMonitor.extractRelease(null));
    }

    @isTest
    static void schedulesAndIsQueryable() {
        Test.setMock(HttpCalloutMock.class, new PageMock(200, 'db_31_0'));
        Test.startTest();
        String jobId = NM_ONETReleaseMonitor.scheduleWeekly();
        Test.stopTest();
        CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 3 ? * SUN', ct.CronExpression);
    }
}
