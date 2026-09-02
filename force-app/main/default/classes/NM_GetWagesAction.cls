/*****************************************************************
Name:          NM_GetWagesAction
============================================================
Purpose:       Return BLS wage figures for occupations the agent
               has already shown the veteran.

               Pay is one of the first things someone asks when
               deciding whether a career move is survivable, and
               until now the agent could only decline. It declines
               no longer, but it still never guesses: every figure
               here is a stored BLS number or it is absent.

               Matched on occupation TITLE rather than SOC code
               because the agent knows what it printed, not what
               the codes behind them were. Titles resolve from two
               places: NM_Occupation__c names on the coded path, and
               the plain-English cluster role titles on the
               description path, each of which stores the O*NET code
               it stands for.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-02  Created   NMDH-23
*****************************************************************/
public with sharing class NM_GetWagesAction {

    private static final Integer MAX_TITLES = 8;

    private static final String NONE_MSG =
        'No wage figures are held for those roles.';

    public class Request {
        @InvocableVariable(
            label='Occupation Titles'
            description='The occupation titles you have shown this veteran, separated by semicolons. Pass them exactly as they were printed. Do not invent titles and do not abbreviate them.'
            required=true)
        public String occupationTitles;
    }

    public class Response {
        @InvocableVariable(
            label='Found'
            description='True when at least one figure came back.')
        public Boolean found;

        @InvocableVariable(
            label='Wages'
            description='One line per role, already formatted for reading aloud. Present these verbatim. Never add a figure that is not here and never convert or estimate one.')
        public String wages;

        @InvocableVariable(
            label='Missing'
            description='Titles that have no published figure. Say plainly that BLS does not publish one for these rather than implying the role pays nothing.')
        public String missing;

        @InvocableVariable(
            label='Source'
            description='Which BLS release these came from. Name it to the veteran.')
        public String source;

        @InvocableVariable(
            label='Message'
            description='Set only when nothing was found.')
        public String message;
    }

    /*
     * Purpose:    Look up stored BLS figures for a list of occupation titles.
     * Parameters: requests — each carrying a semicolon-separated title list
     * Returns:    list of Response, in the same order as requests
     */
    @InvocableMethod(
        label='Get Wage Data'
        description='Return BLS national wage figures for occupations already shown to this veteran. Pass the exact titles. Returns a median, a 10th to 90th percentile range and how many people hold the job. Every number comes from stored BLS data; the agent must never state a figure this action did not return.')
    public static List<Response> getWages(List<Request> requests) {
        System.debug('Entering NM_GetWagesAction.getWages: requests=' + requests.size());

        // --- Collect every title across the batch for one query ---------------
        List<List<String>> perRequest = new List<List<String>>();
        Set<String> allTitles = new Set<String>();
        for (Request req : requests) {
            List<String> titles = splitTitles(req == null ? null : req.occupationTitles);
            perRequest.add(titles);
            allTitles.addAll(titles);
        }

        // --- Query: occupations, then the wages attached to their codes -------
        //     SOQL string comparison is case-insensitive, so the titles go in as
        //     given; the map is keyed lowercase for the lookup below.
        Map<String, String> codeByTitle = new Map<String, String>();
        if (!allTitles.isEmpty()) {
            for (NM_Occupation__c o : [
                SELECT Name, ONET_Code__c
                FROM   NM_Occupation__c
                WHERE  Name IN :allTitles
            ]) {
                String k = o.Name.toLowerCase();
                if (!codeByTitle.containsKey(k)) codeByTitle.put(k, o.ONET_Code__c);
            }
        }

        // Cluster roles carry plain-English titles ("Police Officer") rather than
        // O*NET's formal ones ("Police and Sheriff's Patrol Officers"), because
        // the formal name is not what a veteran searches for. Each one stores the
        // O*NET code it stands for, so pay resolves on the cluster path too.
        // Without this, a veteran placed by description gets no wages at all.
        for (String k : clusterRoleCodes().keySet()) {
            if (!codeByTitle.containsKey(k)) codeByTitle.put(k, clusterRoleCodes().get(k));
        }

        Map<String, NM_Wage__c> wageByCode = new Map<String, NM_Wage__c>();
        if (!codeByTitle.isEmpty()) {
            Set<String> codes = new Set<String>(codeByTitle.values());
            for (NM_Wage__c w : [
                SELECT Name, ONET_Code__c, Median_Annual__c, Pct10_Annual__c,
                       Pct90_Annual__c, Total_Employment__c, Is_Broad_Group__c, Source__c
                FROM   NM_Wage__c
                WHERE  ONET_Code__c IN :codes
            ]) {
                wageByCode.put(w.ONET_Code__c, w);
            }
        }

        // --- Build each response in memory ------------------------------------
        List<Response> results = new List<Response>();
        for (Integer n = 0; n < requests.size(); n++) {
            Response res = new Response();
            List<String> lines = new List<String>();
            List<String> absent = new List<String>();

            for (String title : perRequest[n]) {
                String code = codeByTitle.get(title.toLowerCase());
                NM_Wage__c w = code == null ? null : wageByCode.get(code);
                if (w == null || w.Median_Annual__c == null) {
                    absent.add(title);
                    continue;
                }
                lines.add(formatLine(title, w));
                if (String.isBlank(res.source)) res.source = w.Source__c;
            }

            res.found   = !lines.isEmpty();
            res.wages   = lines.isEmpty()  ? null : String.join(lines, '\n');
            res.missing = absent.isEmpty() ? null : String.join(absent, '; ');
            if (!res.found) res.message = NONE_MSG;
            results.add(res);
        }

        System.debug('Exiting NM_GetWagesAction.getWages: results=' + results.size());
        return results;
    }

    private static Map<String, String> clusterCodeCache;

    /*
     * Purpose:    Map every cluster role title, lowercased, to the O*NET code it
     *             stands for. Cached because getWages consults it per request.
     * Returns:    lowercase title -> O*NET code
     */
    @TestVisible
    private static Map<String, String> clusterRoleCodes() {
        if (clusterCodeCache != null) return clusterCodeCache;
        clusterCodeCache = new Map<String, String>();
        // SOQL, not getAll(): getAll() does not populate Long Text Area fields,
        // so Job_Descriptions__c comes back null and every title silently misses.
        // Custom metadata SOQL does not count against query governor limits.
        for (NM_Specialty_Cluster__mdt c : [
                SELECT Cluster_Key__c, Job_Descriptions__c
                FROM   NM_Specialty_Cluster__mdt
        ]) {
            if (String.isBlank(c.Job_Descriptions__c)) continue;
            try {
                for (Object o : (List<Object>) JSON.deserializeUntyped(c.Job_Descriptions__c)) {
                    Map<String, Object> row = (Map<String, Object>) o;
                    String t = (String) row.get('title');
                    String code = (String) row.get('onet');
                    if (String.isNotBlank(t) && String.isNotBlank(code)) {
                        clusterCodeCache.put(t.toLowerCase(), code);
                    }
                }
            } catch (Exception e) {
                // A malformed cluster must not take pay down for every other one.
                System.debug(LoggingLevel.WARN,
                    'Could not read job descriptions for cluster ' + c.Cluster_Key__c +
                    ': ' + e.getMessage());
            }
        }
        return clusterCodeCache;
    }

    /*
     * Purpose:    Turn one wage record into a line the agent can read out.
     *             Leads with the median because a mean is pulled upward by a
     *             long tail, and a veteran comparing paths would be misled by it.
     *             Carries the range because the median alone hides how wide
     *             the spread is, and the entry point is what matters to someone
     *             starting over.
     */
    @TestVisible
    private static String formatLine(String title, NM_Wage__c w) {
        String s = title + ': median ' + money(w.Median_Annual__c) + ' a year';
        if (w.Pct10_Annual__c != null && w.Pct90_Annual__c != null) {
            s += ', most earn between ' + money(w.Pct10_Annual__c) +
                 ' and ' + money(w.Pct90_Annual__c);
        }
        if (w.Total_Employment__c != null) {
            s += ', about ' + plain(w.Total_Employment__c) + ' people do this work nationally';
        }
        if (w.Is_Broad_Group__c == true) {
            // Never let a broader figure pass as this exact role's pay.
            s += ' (this figure covers the wider ' + w.Name + ' group, not that role alone)';
        }
        return s;
    }

    @TestVisible
    private static String money(Decimal d) {
        return '$' + plain(d);
    }

    /*
     * Purpose:    Thousands separators. Apex format() on a Decimal honours the
     *             running user's locale, which is what we want for a figure a
     *             person reads.
     */
    @TestVisible
    private static String plain(Decimal d) {
        return d == null ? '' : d.setScale(0).format();
    }

    /*
     * Purpose:    Split the agent's title list. Accepts semicolons, and newlines
     *             because the model sometimes passes the list as it printed it.
     *             Capped so a runaway prompt cannot fan out the query.
     */
    @TestVisible
    private static List<String> splitTitles(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) return out;
        // Dedupe case-insensitively. The match downstream ignores case, so
        // treating 'Paramedics' and 'paramedics' as distinct would print the
        // same role twice with the same figure beside it.
        Set<String> seen = new Set<String>();
        for (String t : raw.replace('\n', ';').split(';')) {
            String v = t.trim();
            if (String.isBlank(v)) continue;
            // Tolerate "Title :: Description" if the model echoes our own format.
            if (v.contains(' :: ')) v = v.substringBefore(' :: ').trim();
            if (String.isBlank(v) || !seen.add(v.toLowerCase())) continue;
            out.add(v);
            if (out.size() >= MAX_TITLES) break;
        }
        return out;
    }
}
