/*****************************************************************
Name:          NM_GetWagesActionTest
============================================================
Purpose:       Cover NM_GetWagesAction. The rule that matters most
               is that a figure never appears unless it is stored,
               so most of these assert on what is ABSENT.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-02  Created   NMDH-23
*****************************************************************/
@IsTest
private class NM_GetWagesActionTest {

    @testSetup
    static void seed() {
        insert new List<NM_Occupation__c>{
            new NM_Occupation__c(Name='Paramedics', ONET_Code__c='29-2043.00',
                Description__c='Emergency medical care.'),
            new NM_Occupation__c(Name='Logisticians', ONET_Code__c='13-1081.00',
                Description__c='Coordinate the flow of goods.'),
            new NM_Occupation__c(Name='Mental Health Counselors', ONET_Code__c='21-1014.00',
                Description__c='Counsel people on mental health.'),
            new NM_Occupation__c(Name='Unpriced Role', ONET_Code__c='99-9999.00',
                Description__c='No BLS figure exists.')
        };
        insert new List<NM_Wage__c>{
            new NM_Wage__c(Name='Paramedics', ONET_Code__c='29-2043.00',
                Median_Annual__c=58410, Pct10_Annual__c=40130, Pct90_Annual__c=82420,
                Total_Employment__c=99530, Wage_SOC_Code__c='29-2043',
                Is_Broad_Group__c=false, Source__c='BLS OEWS May 2024'),
            new NM_Wage__c(Name='Logisticians', ONET_Code__c='13-1081.00',
                Median_Annual__c=80880, Pct10_Annual__c=49260, Pct90_Annual__c=132110,
                Total_Employment__c=225000, Wage_SOC_Code__c='13-1081',
                Is_Broad_Group__c=false, Source__c='BLS OEWS May 2024'),
            // BLS publishes this one only at the wider group level.
            new NM_Wage__c(Name='Counselors, All Other', ONET_Code__c='21-1014.00',
                Median_Annual__c=53710, Pct10_Annual__c=36700, Pct90_Annual__c=89900,
                Total_Employment__c=41000, Wage_SOC_Code__c='21-1010',
                Is_Broad_Group__c=true, Source__c='BLS OEWS May 2024')
        };
    }

    private static NM_GetWagesAction.Response run(String titles) {
        NM_GetWagesAction.Request r = new NM_GetWagesAction.Request();
        r.occupationTitles = titles;
        return NM_GetWagesAction.getWages(new List<NM_GetWagesAction.Request>{r})[0];
    }

    @IsTest
    static void returnsMedianRangeAndEmployment() {
        NM_GetWagesAction.Response res = run('Paramedics');
        System.assert(res.found, 'A stored figure must come back');
        System.assert(res.wages.contains('58,410'), 'Median must appear');
        System.assert(res.wages.contains('40,130') && res.wages.contains('82,420'),
            'The range must appear; a median alone hides the spread');
        System.assert(res.wages.contains('99,530'), 'Employment must appear');
        System.assertEquals('BLS OEWS May 2024', res.source, 'Source must be attributable');
        System.assertEquals(null, res.missing, 'Nothing was missing');
    }

    @IsTest
    static void anUnknownTitleIsReportedMissingNotInvented() {
        NM_GetWagesAction.Response res = run('Paramedics; Chief Vibes Officer');
        System.assert(res.found, 'The known one still resolves');
        System.assert(res.missing.contains('Chief Vibes Officer'),
            'An unknown title must be reported, never guessed at');
        System.assert(!res.wages.contains('Chief Vibes Officer'),
            'A title with no stored figure must never appear with a number beside it');
    }

    @IsTest
    static void occupationWithNoStoredWageIsMissingNotZero() {
        NM_GetWagesAction.Response res = run('Unpriced Role');
        System.assert(!res.found, 'No figure exists for this occupation');
        System.assertEquals(null, res.wages, 'No wage text at all');
        System.assert(res.missing.contains('Unpriced Role'),
            'Reported as missing. A role BLS does not price is not a role that pays nothing');
        System.assert(String.isNotBlank(res.message), 'A reason must come back');
    }

    @IsTest
    static void broadGroupFigureIsDisclosed() {
        NM_GetWagesAction.Response res = run('Mental Health Counselors');
        System.assert(res.found);
        System.assert(res.wages.contains('wider'),
            'A figure covering a broader group must say so, or it reads as this role s pay');
        System.assert(res.wages.contains('Counselors, All Other'),
            'Name the group the figure actually covers');
    }

    @IsTest
    static void titlesAreMatchedCaseInsensitivelyAndDeduped() {
        NM_GetWagesAction.Response res = run('paramedics; PARAMEDICS; Paramedics');
        System.assert(res.found);
        System.assertEquals(1, res.wages.split('\n').size(),
            'The same role asked for three ways is still one line');
    }

    @IsTest
    static void acceptsOurOwnTitleDoubleColonDescriptionFormat() {
        // The model sometimes passes the list back exactly as we printed it.
        NM_GetWagesAction.Response res = run('Paramedics :: Emergency medical care.');
        System.assert(res.found, 'A Title :: Description entry must still resolve');
        System.assert(res.wages.contains('58,410'));
    }

    @IsTest
    static void blankAndNullInputDoNotThrow() {
        System.assert(!run(null).found, 'Null input is handled');
        System.assert(!run('   ').found, 'Blank input is handled');
        System.assert(!run(';;;').found, 'Separators only is handled');
    }

    @IsTest
    static void bulkRequestsUseConstantQueries() {
        List<NM_GetWagesAction.Request> reqs = new List<NM_GetWagesAction.Request>();
        for (Integer i = 0; i < 50; i++) {
            NM_GetWagesAction.Request r = new NM_GetWagesAction.Request();
            r.occupationTitles = 'Paramedics; Logisticians';
            reqs.add(r);
        }
        Test.startTest();
        List<NM_GetWagesAction.Response> res = NM_GetWagesAction.getWages(reqs);
        Test.stopTest();
        System.assertEquals(50, res.size());
        System.assert(Limits.getQueries() <= 4,
            'Must not query per request. Used ' + Limits.getQueries());
        System.assert(res[49].found, 'The last one resolves like the first');
    }

    @IsTest
    static void titleListIsCappedSoAPromptCannotFanOut() {
        List<String> many = new List<String>();
        for (Integer i = 0; i < 40; i++) many.add('Role ' + i);
        NM_GetWagesAction.Response res = run(String.join(many, ';'));
        System.assert(res.missing.split('; ').size() <= 8,
            'The action caps how many titles it will process');
    }
}
