/*****************************************************************
Name:          NM_RequestMentorIntroAction
============================================================
Purpose:       @InvocableMethod for Agentforce. Creates a
               NM_Mentor_Introduction__c record linking the current
               session to the chosen mentor, and marks the session's
               NM_Conversation__c as mentor-requested.
               Guards against duplicate introductions.
               Validates email format before inserting.
               Created by NMDH-8.
============================================================
History
-------
VERSION  AUTHOR       DATE         DETAIL    DESCRIPTION
1.0      Orchestrate  2026-08-30   Created   NMDH-8
*****************************************************************/
public with sharing class NM_RequestMentorIntroAction {

    // RFC 5321-compliant email pattern (simplified, avoids unicode edge cases)
    private static final String EMAIL_REGEX =
        '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$';

    /*****************************************************************
    Purpose:       Input schema consumed by the Agentforce planner.
    *****************************************************************/
    public class Request {
        @InvocableVariable(
            label='Mentor Id'
            description='Id of the NM_Mentor__c record — returned by NM_FindMentorAction.'
            required=true
        )
        public Id mentorId;

        @InvocableVariable(
            label='Requester Email'
            description='Email address the veteran provided for the introduction.'
            required=true
        )
        public String requesterEmail;

        @InvocableVariable(
            label='Conversation Key'
            description='External_Session_Key__c of the current NM_Conversation__c session — used to link the intro record and guard against duplicates.'
            required=true
        )
        public String conversationKey;
    }

    /*****************************************************************
    Purpose:       Output schema returned to the Agentforce planner.
    *****************************************************************/
    public class Response {
        @InvocableVariable(label='Success' description='True when the intro was created or already existed.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Human-readable result for the agent to relay.')
        public String message;
    }

    /*****************************************************************
    Purpose:       Validates the email, looks up the conversation,
                   guards against duplicate intros, then creates the
                   NM_Mentor_Introduction__c record and marks
                   NM_Conversation__c.Mentor_Requested__c = true.
    Parameters:    requests — single-element list (planner wraps it)
    Returns:       single-element list of Response
    *****************************************************************/
    @InvocableMethod(
        label='Request Mentor Introduction'
        description='Creates an introduction record linking this session to the chosen mentor. Call ONLY after visitor explicitly says yes and provides their email. After success, do not re-prompt for another intro this session.'
        callout=false
    )
    public static List<Response> requestIntro(List<Request> requests) {
        System.debug('Entering NM_RequestMentorIntroAction.requestIntro');

        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            // Validate email format
            if (String.isBlank(req.requesterEmail) || !Pattern.matches(EMAIL_REGEX, req.requesterEmail)) {
                res.success = false;
                res.message = 'That email address doesn\'t look right. Could you double-check it and try again?';
                results.add(res);
                continue;
            }

            // Look up the conversation record by session key
            List<NM_Conversation__c> convs = [
                SELECT Id
                FROM NM_Conversation__c
                WHERE External_Session_Key__c = :req.conversationKey
                LIMIT 1
            ];

            if (convs.isEmpty()) {
                res.success = false;
                res.message = 'I wasn\'t able to locate your session. Please try again.';
                results.add(res);
                continue;
            }

            Id conversationId = convs[0].Id;

            // Duplicate guard: check for an existing intro for this session + mentor pair
            List<NM_Mentor_Introduction__c> existing = [
                SELECT Id
                FROM NM_Mentor_Introduction__c
                WHERE Conversation__c = :conversationId
                AND Mentor__c         = :req.mentorId
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                // Already requested this session — return success without a second record
                System.debug('NM_RequestMentorIntroAction: duplicate intro guard triggered');
                res.success = true;
                res.message = 'I\'ve already sent that introduction request for this session.';
                results.add(res);
                continue;
            }

            // Create the introduction audit record
            NM_Mentor_Introduction__c intro = new NM_Mentor_Introduction__c(
                Conversation__c    = conversationId,
                Mentor__c          = req.mentorId,
                Requester_Email__c = req.requesterEmail,
                Status__c          = 'Pending',
                Introduced_At__c   = DateTime.now()
            );
            insert intro;

            // Mark the conversation as mentor-requested
            NM_Conversation__c upd = new NM_Conversation__c(
                Id = conversationId,
                Mentor_Requested__c = true
            );
            update upd;

            res.success = true;
            res.message = 'Done. I\'ve queued the introduction and someone will reach out soon.';
            results.add(res);
        }

        System.debug('Exiting NM_RequestMentorIntroAction.requestIntro: results=' + results.size());
        return results;
    }
}
