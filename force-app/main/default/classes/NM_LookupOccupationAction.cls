/*****************************************************************
Name:          NM_LookupOccupationAction
============================================================
Purpose:       Invocable action for the Next Mission agent.
               Resolves a military specialty code to the civilian
               O*NET occupations it maps to, using the O*NET
               Military Crosswalk loaded into NM_Military_Code_V2__c
               and NM_Occupation__c.

               Replaces the cluster-based lookup for job matching.
               NM_LookupMilitaryCodeAction and the CMDT path remain
               in place until the cutover (NMDH-22).

               Two codes that previously shared a cluster now return
               different occupation sets. 68W returns Paramedics;
               68G returns medical records roles.

               Bulkification: two SOQL queries run outside any loop.
               Per-input resolution is done in memory against maps.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-01  Created   NMDH-22
*****************************************************************/
public with sharing class NM_LookupOccupationAction {

    private static final Integer MAX_OCCUPATIONS = 5;

    /*
     * Purpose:    Input wrapper for the @InvocableMethod.
     * Parameters: branch — military branch as the veteran stated it
     *             code   — specialty code (MOS, AFSC, Rating, NEC)
     */
    public class Request {
        @InvocableVariable(
            required=true
            label='Military Branch'
            description='Branch as stated by the veteran. Normalise to Army, Navy, Air Force, Marine Corps, Coast Guard or Space Force before calling.')
        public String branch;

        @InvocableVariable(
            required=true
            label='Specialty Code'
            description='Military specialty code exactly as stated (MOS, AFSC, Rating, NEC).')
        public String code;
    }

    /*
     * Purpose: Output wrapper returned to the calling agent.
     */
    public class Response {
        @InvocableVariable(
            label='Found'
            description='True when the code resolved to at least one civilian occupation.')
        public Boolean found;

        @InvocableVariable(
            label='Role Title'
            description='Military role title for the matched code, e.g. Combat Medic Specialist.')
        public String roleTitle;

        @InvocableVariable(
            label='Occupations'
            description='Civilian occupations this code maps to. Each entry is Title :: Description. Present these verbatim; never invent occupations.')
        public String occupations;

        @InvocableVariable(
            label='Adjacent Occupations'
            description='Grounded occupations ADJACENT to the direct match, offered when the crosswalk row is thin. Each entry is Title :: Description. NEVER present these as what the code maps to; they are a wider set, and saying otherwise misrepresents the federal crosswalk.')
        public String adjacentOccupations;

        @InvocableVariable(
            label='Suggested Cluster'
            description='Career area to place this veteran in when their code maps only to a military occupation. Set it on the session. Without it the conversation has a role title and nothing else, and the agent falls back to the greeting and repeats what it just said.')
        public String suggestedCluster;

        @InvocableVariable(
            label='Adjacent Count'
            description='How many adjacent occupations were returned. Zero when the direct match is already rich enough.')
        public Integer adjacentCount;

        @InvocableVariable(
            label='Occupation Count'
            description='How many civilian occupations were returned.')
        public Integer occupationCount;

        // A cap of five was applied silently, so a code mapping to nine
        // occupations showed five and the veteran had no way to know four had
        // been dropped. There is no relevance score behind the ordering, it is
        // the order O*NET publishes in, so this cannot honestly be called a
        // "top five". These outputs make the truncation visible instead of
        // dressing an arbitrary cut up as a selection.
        @InvocableVariable(
            label='Total Mapped'
            description='How many civilian occupations this code maps to in total, before any cap.')
        public Integer totalMapped;

        @InvocableVariable(
            label='Not Shown'
            description='Occupation titles this code maps to that were NOT listed, separated by semicolons. If this is set you MUST tell the veteran the list is partial and offer these, because the ones shown are not ranked and are not better.')
        public String notShown;

        // A near miss is offered, never assumed. Sending a veteran down the
        // wrong career path silently is worse than asking one short question.
        @InvocableVariable(
            label='Resolved Code'
            description='The code as the crosswalk stores it, normalised from whatever was typed. Say THIS back, not the spacing the veteran used.')
        public String resolvedCode;

        @InvocableVariable(
            label='Did You Mean'
            description='A real code that is one character away from what they typed. When this is set, ASK whether they meant it. Never look it up as though they had typed it.')
        public String didYouMean;

        @InvocableVariable(
            label='Did You Mean Title'
            description='The role title of the suggested code, so the question names the job rather than just a code.')
        public String didYouMeanTitle;

        @InvocableVariable(
            label='Message'
            description='Populated when found=false or militaryOnly=true. Surface it as context, never as an accusation that the veteran got their code wrong.')
        public String message;

        @InvocableVariable(
            label='Military Only'
            description='True when the code resolves ONLY to military-specific SOC codes with no civilian equivalent. The role title is still valid; there is simply no civilian occupation to name. Never present the military role as a civilian job.')
        public Boolean militaryOnly;
    }

    // Surfaced when a code is not in the crosswalk. The crosswalk is large but
    // not exhaustive, so a miss is usually our gap, not the veteran's error.
    private static final String NOT_FOUND_MSG =
        'That code is not in the crosswalk I have. That is a gap on my side, not a mistake on yours.';

    // 1,001 of 8,179 codes map ONLY to the 55-xx military SOC family. Those are
    // military job classifications, not civilian occupations. Returning
    // "Infantry: operate weapons and equipment in ground combat operations" as
    // somebody's civilian match is worse than returning nothing, because it
    // reads as an answer and cannot be applied for anywhere.
    private static final String MILITARY_ONLY_MSG =
        'That code maps only to a military job classification, so there is no single civilian occupation to point at. That is normal for combat roles and it does not mean the experience does not transfer. Work from what they actually did instead.';

    /*
     * Purpose:    Bulk-safe entry point. Resolves one or many (branch, code)
     *             pairs using two SOQL queries outside any loop.
     * Parameters: requests — list of Request; each carries branch and code
     * Returns:    list of Response, in the same order as requests
     */
    @InvocableMethod(
        label='Look Up Civilian Occupations For A Military Code'
        description='Resolve a military specialty code to the civilian O*NET occupations it maps to. Returns the role title and up to five occupations with their descriptions. Pass branch normalised to one of the six service names.'
        callout=false)
    public static List<Response> lookupOccupations(List<Request> requests) {
        System.debug('Entering NM_LookupOccupationAction.lookupOccupations: requests=' + requests.size());

        // --- Build the keys we need. For each request we may try two: the code
        //     exactly as given, and for an Army MOS carrying a skill-level suffix
        //     (68W10), the base MOS (68W). Both go into one query.
        //     Deliberately NOT general prefix truncation: shortening an Air Force
        //     AFSC or a Navy NEC can land on a different valid code in a different
        //     cluster and return a confident wrong answer.
        Set<String> keys = new Set<String>();
        for (Request req : requests) {
            String k = buildKey(req.branch, req.code);
            if (k != null) keys.add(k);
            String b = baseArmyKey(req.branch, req.code);
            if (b != null) keys.add(b);
            String n = baseNavyRatingKey(req.branch, req.code);
            if (n != null) keys.add(n);
            for (String x : afscSkillLevelKeys(req.branch, req.code)) keys.add(x);
            String pm = paddedMosKey(req.branch, req.code);
            if (pm != null) keys.add(pm);
            for (String ax : afscLevelSwapKeys(req.branch, req.code)) keys.add(ax);
        }

        // --- Query 1: the military codes ------------------------------------
        Map<String, NM_Military_Code_V2__c> codeByKey = new Map<String, NM_Military_Code_V2__c>();
        Set<String> onetCodes = new Set<String>();
        if (!keys.isEmpty()) {
            for (NM_Military_Code_V2__c mc : [
                SELECT External_Key__c, Role_Title__c, ONET_Codes__c
                FROM   NM_Military_Code_V2__c
                WHERE  External_Key__c IN :keys
            ]) {
                codeByKey.put(mc.External_Key__c, mc);
                if (String.isNotBlank(mc.ONET_Codes__c)) {
                    for (String c : mc.ONET_Codes__c.split(';')) {
                        if (String.isNotBlank(c)) onetCodes.add(c.trim());
                    }
                }
            }
        }

        // --- Supplements: widen a thin crosswalk row without overwriting it ---
        //     Keyed either by SOC code (covers every military code whose only
        //     match is that residual bucket) or by BRANCH:CODE for a single code.
        //     The O*NET row stays the authoritative direct match; these are only
        //     ever offered as adjacent. See NMDH-37.
        Map<String, NM_Occupation_Supplement__mdt> supByKey =
            new Map<String, NM_Occupation_Supplement__mdt>();
        // getAll(), NOT SOQL. SOQL on a custom metadata type is subject to the
        // running user's access, and the Experience Cloud GUEST user has none on
        // this type, so every coded lookup failed for real visitors while working
        // perfectly when run as an admin. getAll() bypasses that. It does not
        // populate Long Text Area fields on every type, so verify the field you
        // need actually arrives rather than assuming either way.
        for (NM_Occupation_Supplement__mdt sup : NM_Occupation_Supplement__mdt.getAll().values()) {
            if (String.isNotBlank(sup.Match_Key__c)) {
                supByKey.put(sup.Match_Key__c.toUpperCase().trim(), sup);
            }
        }
        for (Request req : requests) {
            NM_Occupation_Supplement__mdt s1 = supByKey.get(supplementKey(req.branch, req.code));
            if (s1 != null) onetCodes.addAll(splitCodes(s1.Adjacent_ONET_Codes__c));
        }
        for (String c : new Set<String>(onetCodes)) {
            NM_Occupation_Supplement__mdt s2 = supByKey.get(c.toUpperCase());
            if (s2 != null) onetCodes.addAll(splitCodes(s2.Adjacent_ONET_Codes__c));
        }

        // --- Query 2: the occupations those codes point at --------------------
        Map<String, NM_Occupation__c> occByCode = new Map<String, NM_Occupation__c>();
        if (!onetCodes.isEmpty()) {
            for (NM_Occupation__c o : [
                SELECT Name, ONET_Code__c, Description__c
                FROM   NM_Occupation__c
                WHERE  ONET_Code__c IN :onetCodes
            ]) {
                occByCode.put(o.ONET_Code__c, o);
            }
        }

        // --- Near misses: one query, only for codes that did not resolve -----
        //     Somebody typing 88N when they meant 88M should be asked, not told
        //     their service does not exist. Prefix-filtered on the first
        //     character so this stays a handful of rows, never the whole branch.
        Map<String, NM_Military_Code_V2__c> nearByRequestKey =
            new Map<String, NM_Military_Code_V2__c>();
        List<String> prefixes = new List<String>();
        Set<String> missBranches = new Set<String>();
        for (Request req : requests) {
            String k = buildKey(req.branch, req.code);
            if (k == null || codeByKey.containsKey(k)) continue;
            String c = normaliseCode(req.code);
            if (c.length() < 2) continue;
            prefixes.add(c.substring(0, 1) + '%');
            missBranches.add(normaliseBranch(req.branch));
        }

        List<NM_Military_Code_V2__c> candidates = new List<NM_Military_Code_V2__c>();
        if (!prefixes.isEmpty()) {
            candidates = [
                SELECT Code_Value__c, Branch__c, Role_Title__c, External_Key__c, ONET_Codes__c
                FROM   NM_Military_Code_V2__c
                WHERE  Branch__c IN :missBranches
                AND    Code_Value__c LIKE :prefixes
                LIMIT  2000
            ];
        }

        for (Request req : requests) {
            String k = buildKey(req.branch, req.code);
            if (k == null || codeByKey.containsKey(k)) continue;
            String typed = normaliseCode(req.code);
            NM_Military_Code_V2__c best = null;
            Integer bestDist = 99;
            for (NM_Military_Code_V2__c cand : candidates) {
                if (cand.Branch__c != normaliseBranch(req.branch)) continue;
                String have = normaliseCode(cand.Code_Value__c);
                if (Math.abs(have.length() - typed.length()) > 1) continue;
                Integer d = editDistance(typed, have, 1);
                if (d >= 0 && d < bestDist) { bestDist = d; best = cand; }
            }
            // Exactly one character out. Two is a different code, not a typo.
            if (best != null && bestDist == 1) nearByRequestKey.put(k, best);
        }

        // --- Resolve each request in memory, no further SOQL ------------------
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            String key = buildKey(req.branch, req.code);
            if (key != null && !codeByKey.containsKey(key)) {
                // exact miss: fall back to the base Army MOS if this looked like one
                String fallback = baseArmyKey(req.branch, req.code);
                if (fallback == null || !codeByKey.containsKey(fallback)) {
                    fallback = baseNavyRatingKey(req.branch, req.code);
                }
                if (fallback == null || !codeByKey.containsKey(fallback)) {
                    fallback = null;
                    for (String x : afscSkillLevelKeys(req.branch, req.code)) {
                        if (codeByKey.containsKey(x)) { fallback = x; break; }
                    }
                }
                if (fallback == null || !codeByKey.containsKey(fallback)) {
                    fallback = paddedMosKey(req.branch, req.code);
                }
                if (fallback == null || !codeByKey.containsKey(fallback)) {
                    for (String ax : afscLevelSwapKeys(req.branch, req.code)) {
                        if (codeByKey.containsKey(ax)) { fallback = ax; break; }
                    }
                }
                if (fallback != null && codeByKey.containsKey(fallback)) key = fallback;
            }

            if (key == null || !codeByKey.containsKey(key)) {
                res.found = false;
                res.militaryOnly = false;
                res.occupationCount = 0;
                res.message = NOT_FOUND_MSG;

                NM_Military_Code_V2__c near = nearByRequestKey.get(buildKey(req.branch, req.code));
                if (near != null) {
                    res.didYouMean      = near.Code_Value__c;
                    res.didYouMeanTitle = near.Role_Title__c;
                    // Hand the agent the finished question, not two fields to
                    // compose one from. Told only that a near match existed, it
                    // ignored the suggestion and invented a whole background for
                    // a code that does not exist, which is the worst outcome
                    // available: confident, plausible, and about nobody.
                    res.message =
                        'I do not have ' + normaliseCode(req.code) + ' for the '
                      + normaliseBranch(req.branch) + ', but I do have '
                      + near.Code_Value__c
                      + (String.isBlank(near.Role_Title__c)
                            ? '' : ', ' + near.Role_Title__c)
                      + '. Is that the one you meant?';
                }
                results.add(res);
                continue;
            }

            NM_Military_Code_V2__c mc = codeByKey.get(key);
            res.resolvedCode = normaliseCode(req.code);
            List<String> parts = new List<String>();
            List<String> heldBack = new List<String>();
            Boolean sawMilitaryOnly = false;
            if (String.isNotBlank(mc.ONET_Codes__c)) {
                for (String c : mc.ONET_Codes__c.split(';')) {
                    NM_Occupation__c o = occByCode.get(c.trim());
                    if (o == null) continue;
                    // Never surface a military SOC as a civilian occupation.
                    if (isMilitaryOnlyONET(o.ONET_Code__c)) { sawMilitaryOnly = true; continue; }
                    // Past the cap we keep counting rather than stopping, so we
                    // can say honestly how many there are and name the rest.
                    if (parts.size() >= MAX_OCCUPATIONS) { heldBack.add(o.Name); continue; }
                    parts.add(o.Name + ' :: ' + (o.Description__c == null ? '' : o.Description__c));
                }
            }
            res.totalMapped = parts.size() + heldBack.size();
            res.notShown    = heldBack.isEmpty() ? null : String.join(heldBack, '; ');

            if (parts.isEmpty() && sawMilitaryOnly) {
                // The code IS in the crosswalk and the role title is real. There
                // is simply no civilian occupation to name. This is a different
                // situation from an unknown code and must not be reported as one.
                res.found          = true;
                res.militaryOnly   = true;
                res.occupationCount = 0;
                res.roleTitle      = mc.Role_Title__c;
                res.message        = MILITARY_ONLY_MSG;

                // NMDH-33 stopped us passing a 55-xx SOC off as a civilian job.
                // It did not give the veteran anywhere to go, and the agent
                // stalled: it asked them to describe a job it had just named,
                // then repeated itself when they pushed. Adjacent civilian roles
                // give it something true to say. These are never presented as
                // what the code maps to, which is the distinction that matters.
                if (String.isNotBlank(mc.ONET_Codes__c)) {
                    NM_Occupation_Supplement__mdt msup = null;
                    for (String c : mc.ONET_Codes__c.split(';')) {
                        msup = supByKey.get(c.trim().toUpperCase());
                        if (msup != null) break;
                    }
                    if (msup != null) {
                        List<String> madj = new List<String>();
                        for (String c : splitCodes(msup.Adjacent_ONET_Codes__c)) {
                            if (madj.size() >= MAX_OCCUPATIONS) break;
                            NM_Occupation__c o = occByCode.get(c);
                            if (o == null || isMilitaryOnlyONET(o.ONET_Code__c)) continue;
                            madj.add(o.Name + ' :: ' +
                                (o.Description__c == null ? '' : o.Description__c));
                        }
                        if (!madj.isEmpty()) {
                            res.adjacentOccupations = String.join(madj, '\n\n');
                            res.adjacentCount = madj.size();
                        }
                        // Place them. Set ONLY on the military-only path; a coded
                        // veteran with real occupations must keep an empty cluster
                        // so job matching shows their coded roles, not a cluster's.
                        res.suggestedCluster = msup.Cluster_Key__c;
                        // Place them. A military-only code otherwise leaves the
                        // session with a role title and nothing else, and the
                        // router can fall back to the greeting and repeat itself.
                    }
                }
            } else if (parts.isEmpty()) {
                res.found = false;
                res.militaryOnly = false;
                res.occupationCount = 0;
                res.roleTitle = mc.Role_Title__c;
                res.message = NOT_FOUND_MSG;
            } else {
                res.found = true;
                res.militaryOnly = false;
                res.roleTitle = mc.Role_Title__c;
                res.occupations = String.join(parts, '\n\n');
                res.occupationCount = parts.size();

                // A code-specific supplement wins over a bucket-level one: it was
                // written about THIS code, so it knows more than the bucket does.
                NM_Occupation_Supplement__mdt sup =
                    supByKey.get(supplementKey(req.branch, req.code));
                if (sup == null && String.isNotBlank(mc.ONET_Codes__c)) {
                    for (String c : mc.ONET_Codes__c.split(';')) {
                        sup = supByKey.get(c.trim().toUpperCase());
                        if (sup != null) break;
                    }
                }
                if (sup != null) {
                    Set<String> already = new Set<String>(parts);
                    List<String> adj = new List<String>();
                    for (String c : splitCodes(sup.Adjacent_ONET_Codes__c)) {
                        if (adj.size() >= MAX_OCCUPATIONS) break;
                        NM_Occupation__c o = occByCode.get(c);
                        if (o == null || isMilitaryOnlyONET(o.ONET_Code__c)) continue;
                        String entry = o.Name + ' :: ' +
                            (o.Description__c == null ? '' : o.Description__c);
                        if (already.contains(entry)) continue;
                        adj.add(entry);
                    }
                    if (!adj.isEmpty()) {
                        res.adjacentOccupations = String.join(adj, '\n\n');
                        res.adjacentCount = adj.size();
                    }
                }
            }
            if (res.adjacentCount == null) res.adjacentCount = 0;
            results.add(res);
        }

        System.debug('Exiting NM_LookupOccupationAction.lookupOccupations: results=' + results.size());
        return results;
    }

    /*
     * Purpose:    Key for a code-specific supplement: BRANCH:CODE, uppercased.
     *             Returns a non-matching sentinel rather than null so callers do
     *             not have to null-check before every map lookup.
     */
    /*
     * Purpose:    Strip a user-typed code down to what the crosswalk stores.
     *             trim() only removes the ends, so "88 m" became "88 M" and
     *             matched nothing while telling the veteran their code did not
     *             exist. People type "88 m", "88-M", "88m." and "88M " and mean
     *             the same MOS every time. Codes are alphanumeric, so anything
     *             else a person typed is punctuation or spacing, not signal.
     */
    /*
     * Purpose:    Edit distance between two short codes, abandoned once it
     *             exceeds maxDist. Returns -1 when it is further than that.
     *             Codes are at most a handful of characters, so this is cheap.
     */
    @TestVisible
    private static Integer editDistance(String a, String b, Integer maxDist) {
        if (a == b) return 0;
        if (Math.abs(a.length() - b.length()) > maxDist) return -1;
        List<Integer> prev = new List<Integer>();
        for (Integer j = 0; j <= b.length(); j++) prev.add(j);
        for (Integer i = 1; i <= a.length(); i++) {
            List<Integer> cur = new List<Integer>{ i };
            Integer rowBest = i;
            for (Integer j = 1; j <= b.length(); j++) {
                Integer cost = a.substring(i - 1, i) == b.substring(j - 1, j) ? 0 : 1;
                Integer v = Math.min(Math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
                cur.add(v);
                if (v < rowBest) rowBest = v;
            }
            if (rowBest > maxDist) return -1;
            prev = cur;
        }
        Integer d = prev[b.length()];
        return d > maxDist ? -1 : d;
    }

    /*
     * Purpose:    Turn whatever a person calls their service into the five names
     *             the crosswalk stores.
     *
     *             The agent is INSTRUCTED to pass a canonical branch, and an
     *             instruction is a preference. Measured: "Marines", "USMC",
     *             "US Army", "USN", "USAF" and "USCG" all resolved to nothing
     *             and told the veteran their code did not exist. Most Marines
     *             say "Marines". This is not an edge case.
     */
    @TestVisible
    private static String normaliseBranch(String branch) {
        if (String.isBlank(branch)) return '';
        String b = branch.toLowerCase().replaceAll('[^a-z ]', ' ').replaceAll(' +', ' ').trim();
        // Drop the noise people put in front of a service name.
        for (String lead : new List<String>{ 'the ', 'u s ', 'us ' }) {
            while (b.startsWith(lead)) b = b.substring(lead.length()).trim();
        }
        if (b.contains('marine') || b == 'usmc')            return 'Marine Corps';
        if (b.contains('coast')  || b == 'uscg')            return 'Coast Guard';
        if (b.contains('air')    || b == 'usaf')            return 'Air Force';
        if (b.contains('navy')   || b == 'usn')             return 'Navy';
        if (b.contains('army')   || b == 'usa')             return 'Army';
        if (b.contains('space'))                            return 'Space Force';
        return branch.trim();
    }

    @TestVisible
    private static String normaliseCode(String code) {
        if (String.isBlank(code)) return '';
        return code.toUpperCase().replaceAll('[^A-Z0-9]', '');
    }

    @TestVisible
    private static String supplementKey(String branch, String code) {
        if (String.isBlank(branch) || String.isBlank(code)) return '~none~';
        return normaliseBranch(branch).toUpperCase() + ':' + normaliseCode(code);
    }

    /*
     * Purpose:    Split a semicolon-separated SOC list, trimming and dropping blanks.
     */
    @TestVisible
    private static List<String> splitCodes(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) return out;
        for (String c : raw.split(';')) {
            if (String.isNotBlank(c)) out.add(c.trim());
        }
        return out;
    }

    /*
     * Purpose:    Build the external key used at load time: BRANCH|CODE, both
     *             uppercased and trimmed. Returns null when either side is blank.
     */
    private static String buildKey(String branch, String code) {
        if (String.isBlank(branch) || String.isBlank(code)) return null;
        return normaliseBranch(branch).toUpperCase() + '|' + normaliseCode(code);
    }

    /*
     * Purpose:    Army MOS codes carry a two-digit skill level, so 68W10, 68W20 and
     *             68W30 are all the MOS 68W. The crosswalk holds only the base code.
     *             Returns the base key, or null when the pattern does not match.
     * Note:       Army only, and only for the exact shape NNXNN. Other services
     *             encode skill level inside the code itself (2A512E, 2A532E and
     *             2A552E are three distinct crosswalk rows) and must never be
     *             shortened.
     */
    /*
     * Purpose:    A Navy rating is written with the sailor's paygrade attached, so
     *             an IT2 is an Information Systems Technician at E-5. The crosswalk
     *             holds the rating itself ("IT"), not the paygrade form, so "IT2"
     *             missed entirely and sent the veteran down the describe path.
     * Returns:    the rating key, or null when the pattern does not match.
     * Note:       Deliberately narrow: two or three LETTERS followed by ONE digit
     *             1 to 9. Navy NECs are alphanumeric (V25C, 841A, 4599) and must
     *             never be shortened, since trimming 4599 to 459 lands on a
     *             different real code and returns a confident wrong answer.
     */
    private static String baseNavyRatingKey(String branch, String code) {
        if (String.isBlank(branch) || String.isBlank(code)) return null;
        String b = normaliseBranch(branch).toUpperCase();
        // The Coast Guard uses the same rating plus paygrade convention as the
        // Navy, so ME2, BM2 and MK1 were all missing until this included it.
        if (b != 'NAVY' && b != 'COAST GUARD') return null;
        String c = normaliseCode(code);
        if (!Pattern.matches('^[A-Z]{2,3}[1-9]$', c)) return null;
        return b + '|' + c.substring(0, c.length() - 1);
    }

    /*
     * Purpose:    Air Force specialty codes are conventionally WRITTEN with an X
     *             standing in for the skill level, as in 1B4X1, but the crosswalk
     *             stores the concrete levels (1B431, 1B451, 1B471). Almost every
     *             Air Force veteran types the X form, so without this the largest
     *             branch in our data missed on its most common input.
     * Returns:    candidate keys, journeyman (5) first because it is the most
     *             commonly held level, then craftsman, apprentice, helper, chief.
     * Note:       Space Force is included because the USSF adopted the Air Force
     *             specialty code system, and we hold no Space Force rows at all.
     *             A Guardian typing their code otherwise gets nothing.
     */
    private static List<String> afscSkillLevelKeys(String branch, String code) {
        List<String> out = new List<String>();
        if (String.isBlank(branch) || String.isBlank(code)) return out;
        String b = normaliseBranch(branch).toUpperCase();
        if (b != 'AIR FORCE' && b != 'SPACE FORCE') return out;
        String c = normaliseCode(code);
        String prefix = 'AIR FORCE|';      // Space Force resolves against AF codes
        if (c.contains('X')) {
            for (String lvl : new List<String>{'5','7','3','1','9'}) {
                out.add(prefix + c.replace('X', lvl));
            }
        } else if (b == 'SPACE FORCE') {
            out.add(prefix + c);
        }
        return out;
    }

    /*
     * Purpose:    Marine Corps MOS are four digits and people drop the leading
     *             zero, so "311" is 0311 and not a typo. Edit distance treated
     *             it as one and offered 3101, a completely different job.
     *             A structural rule beats fuzzy matching every time it applies.
     */
    @TestVisible
    private static String paddedMosKey(String branch, String code) {
        if (normaliseBranch(branch).toUpperCase() != 'MARINE CORPS') return null;
        String c = normaliseCode(code);
        if (c.length() != 3 || !c.isNumeric()) return null;
        return 'MARINE CORPS|0' + c;
    }

    /*
     * Purpose:    An AFSC carries its skill level as the fourth character.
     *             The crosswalk is uneven about which levels it stores bare:
     *             2A571 (craftsman) exists on its own, while 2A551 (journeyman)
     *             exists only with an airframe suffix, 2A551A through 2A551D.
     *             Same aircraft, same civilian occupations, different level.
     *
     *             So when a levelled AFSC misses, try its siblings at the other
     *             levels rather than falling through to edit distance, which
     *             once offered 2A251, a different career entirely. VERIFIED
     *             against the loaded data, not assumed: an earlier version
     *             built an X-form key here and the crosswalk does not store
     *             X forms at all, only expansions.
     */
    @TestVisible
    private static List<String> afscLevelSwapKeys(String branch, String code) {
        List<String> out = new List<String>();
        String b = normaliseBranch(branch).toUpperCase();
        if (b != 'AIR FORCE' && b != 'SPACE FORCE') return out;
        String c = normaliseCode(code);
        if (c.length() < 5 || c.contains('X')) return out;
        String lvl = c.substring(3, 4);
        if (!lvl.isNumeric()) return out;
        for (String other : new List<String>{'7','5','3','1','9'}) {
            if (other == lvl) continue;
            out.add('AIR FORCE|' + c.substring(0, 3) + other + c.substring(4));
        }
        return out;
    }

    /*
     * Purpose:    Is this O*NET code a military-only classification?
     * Note:       The 55-xx SOC family is military job classifications, not
     *             civilian occupations. 19 such rows are loaded and 1,001 of the
     *             8,179 military codes map to nothing else, so this is 12% of
     *             coded lookups, not an edge case.
     */
    @TestVisible
    private static Boolean isMilitaryOnlyONET(String onetCode) {
        return String.isNotBlank(onetCode) && onetCode.startsWith('55-');
    }

    private static String baseArmyKey(String branch, String code) {
        if (String.isBlank(branch) || String.isBlank(code)) return null;
        if (normaliseBranch(branch).toUpperCase() != 'ARMY') return null;
        String c = normaliseCode(code);
        if (!Pattern.matches('^[0-9]{2}[A-Z][0-9]{2}$', c)) return null;
        return 'ARMY|' + c.substring(0, 3);
    }
}
