/*****************************************************************
Name:    NM_AgentControllerTest
Purpose: Unit tests for NM_AgentController — covers startSession,
         sendMessage, logTurn, and extractReplyText. Uses HttpCalloutMock
         to avoid real API calls. All tests are independent and bulk-safe.
History
-------
VERSION  AUTHOR          DATE        DETAIL
1.0      Orchestrate     2026-08-31  NMDH-16 initial test coverage
2.0      Orchestrate     2026-08-31  NMDH-15/S14 — align mocks + assertions to
                                     the ai-agent/v1 shapes: session response now
                                     returns "sessionId"; extractReplyText
                                     concatenates every chunk's text; chunkText
                                     tolerates nested-Map, String-message, and
                                     top-level-text shapes.
*****************************************************************/
@isTest
private class NM_AgentControllerTest {

    // ── Mocks ───────────────────────────────────────────────────────────────

    private class MockAgentSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse resp = new HTTPResponse();
            resp.setStatusCode(200);
            if (req.getEndpoint().contains('/sessions/') && req.getEndpoint().contains('/messages')) {
                resp.setBody(JSON.serialize(new Map<String, Object>{
                    'messages' => new List<Object>{
                        new Map<String, Object>{
                            'type' => 'Inform',
                            'message' => new Map<String, Object>{
                                'type' => 'Text',
                                'text' => 'Here is some information for you.'
                            }
                        }
                    },
                    'isLastMessage' => true
                }));
            } else {
                // ai-agent/v1 session creation returns "sessionId" (NMDH-16 used the
                // older Copilot "clientSessionId"; NMDH-15/S14 repoints to ai-agent/v1).
                resp.setBody(JSON.serialize(new Map<String, Object>{
                    'sessionId' => 'test-session-id-12345'
                }));
            }
            return resp;
        }
    }

    private class MockAgentFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse resp = new HTTPResponse();
            resp.setStatusCode(500);
            resp.setBody('{"error":"internal server error"}');
            return resp;
        }
    }

    // ── Test data factory ───────────────────────────────────────────────────

    private static NM_Conversation__c makeConversation(String sessionKey) {
        NM_Conversation__c c = new NM_Conversation__c(
            External_Session_Key__c = sessionKey,
            Started_At__c           = DateTime.now()
        );
        insert c;
        return c;
    }

    // ── startSession ────────────────────────────────────────────────────────

    @isTest
    static void testStartSession() {
        Test.setMock(HttpCalloutMock.class, new MockAgentSuccess());
        Test.startTest();
        NM_AgentController.StartSessionResult result = NM_AgentController.startSession('https://example.com');
        Test.stopTest();
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('test-session-id-12345', result.sessionId, 'SessionId should match mock');
        System.assert(result.sessionKey.startsWith('nm-'), 'SessionKey should start with nm-');
    }

    @isTest
    static void testStartSessionNullSourceUrl() {
        Test.setMock(HttpCalloutMock.class, new MockAgentSuccess());
        Test.startTest();
        NM_AgentController.StartSessionResult result = NM_AgentController.startSession(null);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Null sourceUrl should be handled gracefully');
        System.assertEquals('test-session-id-12345', result.sessionId, 'SessionId should match mock');
    }

    @isTest
    static void testStartSessionFailure() {
        Test.setMock(HttpCalloutMock.class, new MockAgentFailure());
        Test.startTest();
        Boolean threwException = false;
        try {
            NM_AgentController.startSession('https://example.com');
        } catch (AuraHandledException e) {
            threwException = true;
            // AuraHandledException.getMessage() returns 'Script-thrown exception' in tests —
            // Salesforce quirk. We verify only that the exception was thrown, not the text.
        }
        Test.stopTest();
        System.assert(threwException, 'Should throw AuraHandledException on 500 response');
    }

    // ── sendMessage ─────────────────────────────────────────────────────────

    @isTest
    static void testSendMessage() {
        Test.setMock(HttpCalloutMock.class, new MockAgentSuccess());
        Test.startTest();
        NM_AgentController.SendMessageResult result =
            NM_AgentController.sendMessage('test-session-id-12345', 'Hello', 'https://example.com');
        Test.stopTest();
        System.assertEquals(true, result.success, 'success should be true');
        System.assertEquals('Here is some information for you.', result.replyText, 'replyText should match mock');
        System.assertEquals(null, result.errorMessage, 'errorMessage should be null on success');
    }

    @isTest
    static void testSendMessageFailure() {
        Test.setMock(HttpCalloutMock.class, new MockAgentFailure());
        Test.startTest();
        NM_AgentController.SendMessageResult result =
            NM_AgentController.sendMessage('test-session-id-12345', 'Hello', 'https://example.com');
        Test.stopTest();
        System.assertEquals(false, result.success, 'success should be false on 500');
        System.assert(result.errorMessage.contains('500'), 'errorMessage should contain status code');
    }

    // ── logTurn ─────────────────────────────────────────────────────────────

    @isTest
    static void testLogTurnCreate() {
        String key = 'nm-testkey-create-001';
        NM_AgentController.LogTurnRequest req = new NM_AgentController.LogTurnRequest();
        req.sessionKey    = key;
        req.transcript    = 'You: Hi\nNext Mission: Hello!';
        req.branch        = 'Army';
        req.specialtyCode = '11B';
        req.messageCount  = 1;

        Test.startTest();
        NM_AgentController.logTurn(req);
        Test.stopTest();

        // Key is suffixed per turn: a guest cannot read or update records, so
        // logging is insert-only and one row is written per turn.
        String prefix = key + '-t';
        List<NM_Conversation__c> convs = [
            SELECT External_Session_Key__c, Transcript__c, Branch__c, Specialty_Code__c, Message_Count__c, Started_At__c
            FROM NM_Conversation__c WHERE External_Session_Key__c LIKE :(prefix + '%')
        ];
        System.assertEquals(1, convs.size(), 'Should create one record for turn 1');
        System.assertEquals(key + '-t1', convs[0].External_Session_Key__c, 'Session key should carry the turn suffix');
        System.assertEquals('Army', convs[0].Branch__c, 'Branch should be set');
        System.assertEquals('11B', convs[0].Specialty_Code__c, 'SpecialtyCode should be set');
        System.assertEquals(1, (Integer) convs[0].Message_Count__c, 'MessageCount should be 1');
        System.assertNotEquals(null, convs[0].Started_At__c, 'Started_At should be set on create');
    }

    /*
     * Two turns of the same conversation produce two rows, and the row with the
     * highest Message_Count__c carries the complete cumulative transcript.
     * This is the contract the QA grader reads. It is not an upsert: a guest
     * user can neither update a record nor query one back, even from a
     * without sharing class, so read-modify-write is unavailable in guest
     * context. See NMDH-19.
     */
    @isTest
    static void testLogTurnWritesOneRowPerTurn() {
        String key = 'nm-testkey-update-002';

        NM_AgentController.LogTurnRequest t1 = new NM_AgentController.LogTurnRequest();
        t1.sessionKey   = key;
        t1.transcript   = 'You: Hi\nNext Mission: Hello!';
        t1.messageCount = 1;

        NM_AgentController.LogTurnRequest t2 = new NM_AgentController.LogTurnRequest();
        t2.sessionKey   = key;
        t2.transcript   = 'You: Hi\nNext Mission: Hello!\nYou: Follow-up\nNext Mission: Sure!';
        t2.messageCount = 2;

        Test.startTest();
        NM_AgentController.logTurn(t1);
        NM_AgentController.logTurn(t2);
        Test.stopTest();

        String prefix = key + '-t';
        List<NM_Conversation__c> convs = [
            SELECT Transcript__c, Message_Count__c
            FROM   NM_Conversation__c
            WHERE  External_Session_Key__c LIKE :(prefix + '%')
            ORDER BY Message_Count__c DESC
        ];
        System.assertEquals(2, convs.size(), 'One row per turn');
        System.assertEquals(2, (Integer) convs[0].Message_Count__c, 'Newest row is turn 2');
        System.assert(convs[0].Transcript__c.contains('Follow-up'),
            'Newest row must carry the cumulative transcript');
        System.assert(convs[0].Transcript__c.contains('Hello!'),
            'Cumulative transcript must still include the earlier turn');
    }

    @isTest
    static void testLogTurnMissingSessionKey() {
        NM_AgentController.LogTurnRequest req = new NM_AgentController.LogTurnRequest();
        req.sessionKey = '';
        req.transcript = 'test';

        Test.startTest();
        Boolean threw = false;
        try {
            NM_AgentController.logTurn(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Blank sessionKey should throw AuraHandledException');
    }

    // ── extractReplyText ────────────────────────────────────────────────────

    @isTest
    static void testExtractReplyTextEmpty() {
        Map<String, Object> parsed = new Map<String, Object>{'messages' => new List<Object>()};
        System.assertEquals('', NM_AgentController.extractReplyText(parsed),
            'Empty messages should return empty string');
        System.assertEquals('', NM_AgentController.extractReplyText(new Map<String, Object>()),
            'Missing messages key should return empty string');
    }

    @isTest
    static void testExtractReplyTextConcatenatesChunks() {
        // ai-agent/v1 may split one reply across several chunks; extractReplyText
        // concatenates every chunk's text so the collated reply comes through whole.
        Map<String, Object> parsed = new Map<String, Object>{
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'Inform',
                    'message' => new Map<String, Object>{'type'=>'Text','text'=>'Hello '}
                },
                new Map<String, Object>{
                    'type' => 'Inform',
                    'message' => new Map<String, Object>{'type'=>'Text','text'=>'there.'}
                }
            }
        };
        System.assertEquals('Hello there.', NM_AgentController.extractReplyText(parsed),
            'Text from every chunk should be concatenated in order');
    }

    @isTest
    static void testExtractReplyTextSkipsTextlessControlChunks() {
        // A control message (SessionEnded etc.) that carries no text contributes
        // nothing; a text-bearing chunk in the same array still comes through.
        Map<String, Object> parsed = new Map<String, Object>{
            'messages' => new List<Object>{
                new Map<String, Object>{ 'type' => 'SessionEnded' },
                new Map<String, Object>{
                    'type' => 'Inform',
                    'message' => new Map<String, Object>{'type'=>'Text','text'=>'Done.'}
                }
            }
        };
        System.assertEquals('Done.', NM_AgentController.extractReplyText(parsed),
            'Text-less control chunks should be skipped, text chunks retained');
    }

    @isTest
    static void testChunkTextShapes() {
        // Nested { message: { text } } shape.
        System.assertEquals('nested', NM_AgentController.chunkText(new Map<String, Object>{
            'message' => new Map<String, Object>{'text' => 'nested'}
        }), 'Nested message.text should be extracted');

        // Flat { message: "..." } String shape.
        System.assertEquals('flat', NM_AgentController.chunkText(new Map<String, Object>{
            'message' => 'flat'
        }), 'String message should be extracted');

        // Top-level { text: "..." } shape.
        System.assertEquals('top', NM_AgentController.chunkText(new Map<String, Object>{
            'text' => 'top'
        }), 'Top-level text should be extracted');

        // No text anywhere, and null → ''.
        System.assertEquals('', NM_AgentController.chunkText(new Map<String, Object>{
            'type' => 'SessionEnded'
        }), 'A chunk with no text should yield empty string');
        System.assertEquals('', NM_AgentController.chunkText(null),
            'Null chunk should yield empty string');
    }

    // ── Bulk test ───────────────────────────────────────────────────────────

    @isTest
    static void testLogTurnBulk() {
        List<NM_AgentController.LogTurnRequest> requests = new List<NM_AgentController.LogTurnRequest>();
        for (Integer i = 0; i < 20; i++) {
            NM_AgentController.LogTurnRequest req = new NM_AgentController.LogTurnRequest();
            req.sessionKey   = 'nm-bulk-test-' + String.valueOf(i).leftPad(3, '0');
            req.transcript   = 'You: Bulk test ' + i + '\nNext Mission: Noted.';
            req.messageCount = i + 1;
            requests.add(req);
        }
        Test.startTest();
        for (NM_AgentController.LogTurnRequest r : requests) {
            NM_AgentController.logTurn(r);
        }
        Test.stopTest();
        Integer count = [SELECT COUNT() FROM NM_Conversation__c WHERE External_Session_Key__c LIKE 'nm-bulk-test-%'];
        System.assertEquals(20, count, 'All 20 bulk records should be created');
    }
}
