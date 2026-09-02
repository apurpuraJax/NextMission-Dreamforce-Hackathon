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
}
