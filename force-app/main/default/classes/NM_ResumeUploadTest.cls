/*****************************************************************
Name:          NM_ResumeUploadTest
============================================================
Purpose:       Cover the resume upload path on NM_AgentController.

               The file itself never reaches Salesforce; the browser
               extracts text and sends only that. So what is worth
               testing here is the text handling: that empty input
               fails honestly instead of sending the agent nothing,
               that a runaway file cannot blow the request, and that
               ragged PDF whitespace is normalised before it wastes
               the agent's attention on layout.
============================================================
History
-------
VERSION  AUTHOR   DATE        DETAIL    DESCRIPTION
1.0      Claude   2026-09-02  Created   NMDH-31
*****************************************************************/
@IsTest
private class NM_ResumeUploadTest {

    @IsTest
    static void blankResumeFailsWithoutCallingTheAgent() {
        // No callout mock is set. If this tried to reach the agent the test
        // would fail with an unmocked-callout error, which is the point:
        // an empty file must be rejected before we spend a round trip.
        for (String bad : new List<String>{ null, '', '   ', '\n\n\n' }) {
            NM_AgentController.SendMessageResult res =
                NM_AgentController.sendResume('sess-1', bad, 'resume.pdf', 'https://x');
            System.assertEquals(false, res.success, 'Blank input must not succeed');
            System.assert(String.isNotBlank(res.errorMessage),
                'The veteran must be told why nothing happened');
            System.assert(res.errorMessage.containsIgnoreCase('text'),
                'The message should point at the real problem, which is unreadable text');
        }
    }

    @IsTest
    static void raggedWhitespaceIsNormalised() {
        String ragged = 'JAMES  CALDWELL\r\n\r\n\r\n\r\n'
            + 'Wheeled   Vehicle\t\tMechanic\n\n\n\n'
            + 'Supervised   a  12 soldier   section   \n';
        String cleaned = NM_AgentController.cleanResumeText(ragged);

        System.assert(!cleaned.contains('\r'), 'Carriage returns must be gone');
        System.assert(!cleaned.contains('  '), 'Runs of spaces must collapse');
        System.assert(!cleaned.contains('\n\n\n'), 'Runs of blank lines must collapse');
        System.assert(!cleaned.contains(''), 'Form feeds must become newlines');
        System.assert(cleaned.startsWith('JAMES CALDWELL'), 'Leading content survives');
        System.assert(cleaned.contains('12 soldier'), 'Actual content is not damaged');
        System.assertEquals(cleaned.trim(), cleaned, 'No leading or trailing whitespace');
    }

    @IsTest
    static void oversizeResumeIsCappedNotRejected() {
        // Someone pasting a 40 page document should still get help, just from
        // the first part of it. Failing them outright would be worse.
        String huge = 'Wheeled Vehicle Mechanic. '.repeat(2000);
        System.assert(huge.length() > NM_AgentController.MAX_RESUME_CHARS,
            'Sanity: the fixture must exceed the cap');

        String cleaned = NM_AgentController.cleanResumeText(huge);
        System.assertEquals(NM_AgentController.MAX_RESUME_CHARS, cleaned.length(),
            'Text must be capped at the documented limit');
    }

    @IsTest
    static void textAtTheLimitIsUntouched() {
        String exact = 'a'.repeat(NM_AgentController.MAX_RESUME_CHARS);
        System.assertEquals(NM_AgentController.MAX_RESUME_CHARS,
            NM_AgentController.cleanResumeText(exact).length(),
            'Text exactly at the cap must not be trimmed');
    }

    @IsTest
    static void realisticResumeSurvivesCleaning() {
        String resume =
            'JAMES R. CALDWELL\n'
          + 'UNITED STATES ARMY  2014-2023\n'
          + 'Sergeant First Class (E-7), MOS 91B Wheeled Vehicle Mechanic\n\n'
          + '- Supervised a 12-soldier maintenance section.\n'
          + '- Managed a $2.4M parts inventory using SAMS-E.\n';
        String cleaned = NM_AgentController.cleanResumeText(resume);

        // The details that make the match good must all still be there.
        for (String needle : new List<String>{
                '91B', 'Wheeled Vehicle Mechanic', '12-soldier', '$2.4M', 'SAMS-E' }) {
            System.assert(cleaned.contains(needle),
                'Cleaning must not drop content the match depends on: ' + needle);
        }
    }

    /* ---------------------------------------------------------------------
     * The distress safety net. This exists because the PLATFORM refuses a
     * veteran who says they are drinking too much, before our instructions are
     * consulted. Measured 5 times in 5 with an explicit instruction forbidding
     * exactly that reply. These tests guard the replacement.
     * ------------------------------------------------------------------- */
    @IsTest
    static void distressIsRecognisedInTheVeteransOwnWords() {
        for (String said : new List<String>{
                'honestly I have been out two years and I cant hold a job, Im drinking too much',
                'i am struggling since I got out and feel pretty hopeless',
                'I can\'t cope with civilian life',
                'nothing matters anymore' }) {
            System.assert(NM_AgentController.signalsDistress(said),
                'Must be recognised as distress: ' + said);
        }
    }

    @IsTest
    static void ordinaryCareerTalkIsNotTreatedAsDistress() {
        // Firing on normal conversation would bury a real disclosure in noise
        // and patronise everyone else.
        for (String said : new List<String>{
                'what jobs fit my background', 'the transition has been hard work',
                'that job sounds stressful', 'I was a combat medic',
                'which one pays the best?', null, '' }) {
            System.assert(!NM_AgentController.signalsDistress(said),
                'Must NOT be treated as distress: ' + said);
        }
    }

    @IsTest
    static void aPlatformRefusalIsReplaced() {
        String refusal = 'Sorry, I can\'t assist with that. I can help you connect your '
                       + 'military experience to civilian careers.';
        String out = NM_AgentController.applyDistressNet('Im drinking too much', refusal);

        System.assert(out.contains('988'), 'The crisis line must reach them');
        System.assert(!out.containsIgnoreCase('assist with that'),
            'The refusal must be REPLACED, not appended. An apostrophe-sensitive '
          + 'match missed this once and shipped the refusal underneath the help.');
    }

    @IsTest
    static void aCareerAnswerThatIgnoredThemGetsTheCrisisLineFirst() {
        String ignored = 'Here are civilian roles that match your Army 11B background: '
                       + 'Police Officer, Security Operations Manager.';
        String out = NM_AgentController.applyDistressNet('I feel hopeless', ignored);

        System.assert(out.startsWith('That sounds genuinely hard'),
            'The person comes before the career answer');
        System.assert(out.contains('Police Officer'),
            'The career answer is kept, not thrown away');
    }

    @IsTest
    static void anAgentThatAlreadyHandledItIsLeftAlone() {
        String good = 'The Veterans Crisis Line is free and confidential, dial 988 then press 1.';
        System.assertEquals(good,
            NM_AgentController.applyDistressNet('I feel hopeless', good),
            'Never double up on a reply that already did the right thing');
    }

    @IsTest
    static void ordinaryRepliesArePassedThroughUntouched() {
        String normal = 'Your Army 68W is Combat Medic Specialist.';
        System.assertEquals(normal,
            NM_AgentController.applyDistressNet('Army 68W', normal),
            'The net must be invisible on every ordinary turn');
    }

    /* ---------------------------------------------------------------------
     * The wage verification net. The agent was told to present the finished
     * wage lines verbatim and did not: it rewrote them and generated its own
     * BLS-looking numbers. Warehouse Operations Manager came back at $98,560
     * against a stored $102,010. Every figure in that reply was invented and
     * it read perfectly, which is exactly why this is checked in code.
     * ------------------------------------------------------------------- */
    @IsTest
    static void everyDollarFigureIsExtracted() {
        Set<Decimal> f = NM_AgentController.figuresIn(
            'median $102,010 a year, most earn between $61,200 and $180,590');
        System.assertEquals(3, f.size(), 'All three figures must be seen');
        System.assert(f.contains(102010) && f.contains(61200) && f.contains(180590));
    }

    @IsTest
    static void textWithoutFiguresIsUntouched() {
        String plain = 'Your Army 68W is Combat Medic Specialist.';
        System.assert(NM_AgentController.figuresIn(plain).isEmpty(),
            'No figures means nothing to verify');
        System.assertEquals(plain, NM_AgentController.applyWageNet(plain),
            'A reply with no money in it must pass through untouched');
    }

    @IsTest
    static void aFigureWeDoNotHoldIsNeverPassedThrough() {
        insert new NM_Wage__c(Name='Paramedics', ONET_Code__c='29-2043.00',
            Median_Annual__c=58410, Pct10_Annual__c=40130, Pct90_Annual__c=82420,
            Total_Employment__c=99530, Wage_SOC_Code__c='29-2043',
            Is_Broad_Group__c=false, Source__c='BLS OEWS May 2024');

        String fabricated = 'Paramedics: median $67,190 a year, according to the '
                          + 'Bureau of Labor Statistics.';
        String out = NM_AgentController.applyWageNet(fabricated);
        System.assert(!out.contains('67,190'),
            'A number we do not hold must never reach a veteran, however plausible');
    }

    @IsTest
    static void aRealFigureSurvives() {
        insert new NM_Wage__c(Name='Paramedics', ONET_Code__c='29-2043.00',
            Median_Annual__c=58410, Pct10_Annual__c=40130, Pct90_Annual__c=82420,
            Total_Employment__c=99530, Wage_SOC_Code__c='29-2043',
            Is_Broad_Group__c=false, Source__c='BLS OEWS May 2024');

        String honest = 'Paramedics: median $58,410 a year, most earn between '
                      + '$40,130 and $82,420.';
        System.assertEquals(honest, NM_AgentController.applyWageNet(honest),
            'A correct reply must not be rewritten. The net is a floor, not an editor.');
    }

    @IsTest
    static void theNetNeverBreaksTheConversation() {
        // A net that throws is worse than no net. With no wage data at all, a
        // reply containing a figure must still return something usable.
        String out = NM_AgentController.applyWageNet('Paramedics earn $58,410 a year.');
        System.assert(String.isNotBlank(out), 'Something must always come back');
        System.assert(!out.contains('58,410'),
            'With nothing to verify against, the figure must not be passed through');
    }
}
