/*****************************************************************
Name:          NM_ONETReleaseMonitor
============================================================
Purpose:       Scheduled check for a newer O*NET database release
               than the one currently loaded into NM_Occupation__c
               and NM_Military_Code_V2__c.

               It does NOT reload the data. The O*NET database is a
               12 MB zip and the military crosswalk is 4 MB; Apex
               has a 6 MB callout limit and cannot unzip. The reload
               is done outside the org with
               scripts/data/build_onet_load_files.py followed by a
               bulk upsert on the external ids.

               This job's job is to make sure a stale grounding
               layer is noticed rather than silently drifting.

               Callout first, then DML. Never the other way round —
               a DML before a callout throws "uncommitted work
               pending".
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-01  Created   NMDH-22
*****************************************************************/
public with sharing class NM_ONETReleaseMonitor implements Schedulable {

    private static final String  RELEASE_PAGE = 'https://www.onetcenter.org/database.html';
    private static final Integer TIMEOUT_MS   = 30000;

    // Matches the release token O*NET publishes on its database page, e.g. db_31_0.
    private static final String RELEASE_PATTERN = 'db_([0-9]+)_([0-9]+)';

    public void execute(SchedulableContext ctx) {
        checkForNewRelease();
    }

    /*
     * Purpose:    Read the published release token, compare it to what we have
     *             loaded, and record whether a refresh is needed.
     * Returns:    the latest release token, or null when it could not be read.
     */
    public static String checkForNewRelease() {
        System.debug('Entering NM_ONETReleaseMonitor.checkForNewRelease');

        // --- Callout FIRST. No DML before this point. ---------------------
        String latest = fetchLatestRelease();

        NM_Data_Config__c cfg = NM_Data_Config__c.getOrgDefaults();
        if (cfg == null) cfg = new NM_Data_Config__c();

        cfg.Last_Checked__c = System.now();
        if (String.isNotBlank(latest)) {
            cfg.Latest_ONET_Release__c = latest;
            cfg.Refresh_Needed__c =
                String.isBlank(cfg.Loaded_ONET_Release__c) ||
                !latest.equalsIgnoreCase(cfg.Loaded_ONET_Release__c);
        }

        upsert cfg;

        if (cfg.Refresh_Needed__c == true) {
            // Deliberately a debug rather than an email. Wire this into whatever
            // alerting the org uses; do not let it fail the job.
            System.debug(LoggingLevel.WARN,
                'O*NET grounding data is stale. Loaded=' + cfg.Loaded_ONET_Release__c +
                ' Latest=' + latest + '. Reload with scripts/data/build_onet_load_files.py.');
        }

        System.debug('Exiting NM_ONETReleaseMonitor.checkForNewRelease: latest=' + latest);
        return latest;
    }

    /*
     * Purpose:    Fetch the O*NET database page and pull the release token out.
     * Returns:    e.g. "db_31_0", or null when the page is unreachable or the
     *             token is absent. Never throws — a monitor that breaks the
     *             scheduler is worse than one that reports nothing.
     */
    @TestVisible
    private static String fetchLatestRelease() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(RELEASE_PAGE);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MS);
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.WARN,
                    'O*NET release page returned ' + res.getStatusCode());
                return null;
            }
            return extractRelease(res.getBody());

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Could not reach the O*NET release page: ' + e.getMessage());
            return null;
        }
    }

    /*
     * Purpose:    Pull the highest release token out of the page body. The page
     *             mentions older releases too, so take the greatest rather than
     *             the first one encountered.
     */
    @TestVisible
    private static String extractRelease(String body) {
        if (String.isBlank(body)) return null;
        Matcher m = Pattern.compile(RELEASE_PATTERN).matcher(body);
        Integer bestMajor = -1, bestMinor = -1;
        String best = null;
        while (m.find()) {
            Integer major = Integer.valueOf(m.group(1));
            Integer minor = Integer.valueOf(m.group(2));
            if (major > bestMajor || (major == bestMajor && minor > bestMinor)) {
                bestMajor = major;
                bestMinor = minor;
                best = m.group(0);
            }
        }
        return best;
    }

    /*
     * Purpose:    Convenience for scheduling. Runs weekly on Sunday at 03:00.
     * Note:       System.schedule uses the SCHEDULING USER'S timezone, not GMT.
     *             Confirm with a CronTrigger query after calling this; a deployed
     *             class is not a scheduled job.
     */
    @TestVisible
    private static final String JOB_NAME = 'NM ONET Release Monitor';

    @TestVisible
    private static final String WEEKLY_CRON = '0 0 3 ? * SUN';

    public static String scheduleWeekly() {
        // Idempotent on purpose. Calling this twice used to throw, which meant
        // a redeploy or a second admin running the setup step got an exception
        // for asking for a state the org was already in. Return the existing
        // job instead; scheduling something already scheduled is not an error.
        List<CronTrigger> existing = [
            SELECT Id FROM CronTrigger
            WHERE  CronJobDetail.Name = :JOB_NAME
            LIMIT  1
        ];
        if (!existing.isEmpty()) return String.valueOf(existing[0].Id);

        return System.schedule(JOB_NAME, WEEKLY_CRON, new NM_ONETReleaseMonitor());
    }
}
