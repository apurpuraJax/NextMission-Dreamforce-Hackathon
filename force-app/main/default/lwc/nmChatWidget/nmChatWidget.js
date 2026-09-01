import { LightningElement, track } from 'lwc';
import startSession  from '@salesforce/apex/NM_AgentController.startSession';
import sendMessage   from '@salesforce/apex/NM_AgentController.sendMessage';
import logTurn       from '@salesforce/apex/NM_AgentController.logTurn';

// Custom labels (accessibility + i18n)
import WIDGET_ARIA    from '@salesforce/label/c.NM_Chat_WidgetAriaLabel';
import MESSAGES_ARIA  from '@salesforce/label/c.NM_Chat_MessagesAriaLabel';
import LOADING_ARIA   from '@salesforce/label/c.NM_Chat_LoadingAriaLabel';
import LOADING_TEXT   from '@salesforce/label/c.NM_Chat_LoadingText';
import INPUT_LABEL    from '@salesforce/label/c.NM_Chat_InputLabel';
import INPUT_ARIA     from '@salesforce/label/c.NM_Chat_InputAriaLabel';
import INPUT_PH       from '@salesforce/label/c.NM_Chat_InputPlaceholder';
import SEND_ARIA      from '@salesforce/label/c.NM_Chat_SendAriaLabel';
import SEND_LABEL     from '@salesforce/label/c.NM_Chat_SendLabel';
import YOU_LABEL      from '@salesforce/label/c.NM_Chat_YouLabel';
import AGENT_LABEL    from '@salesforce/label/c.NM_Chat_AgentLabel';
import ERROR_MSG      from '@salesforce/label/c.NM_Chat_ErrorMessage';

// sessionStorage keys
const SK_SESSION_ID  = 'nm_session_id';
const SK_SESSION_KEY = 'nm_session_key';

// Branch detection keywords (case-insensitive)
const BRANCH_KEYWORDS = [
    { label: 'Army',         patterns: ['army', 'soldier', 'infantry', 'ranger', 'special forces', 'green beret', 'airborne', 'warrant officer'] },
    { label: 'Navy',         patterns: ['navy', 'sailor', 'seabee', 'seal', 'naval', 'ship', 'fleet'] },
    { label: 'Marines',      patterns: ['marine', 'marines', 'usmc', 'leatherneck', 'grunt'] },
    { label: 'Air Force',    patterns: ['air force', 'usaf', 'airman', 'pilot', 'aircraft', 'aviator'] },
    { label: 'Coast Guard',  patterns: ['coast guard', 'uscg', 'coastie'] },
    { label: 'Space Force',  patterns: ['space force', 'guardian', 'ussf'] }
];

// MOS / AFSC / rate code — e.g. 11B, 0311, 6F0X1, IT2
const SPECIALTY_CODE_RE = /\b([A-Z]{1,2}[0-9]{1,3}[A-Z0-9]{0,3}|[0-9]{2}[A-Z0-9]{1,3}|[0-9]{4}[A-Z0-9]{0,2})\b/i;

let _msgId = 0;

export default class NmChatWidget extends LightningElement {

    i18n = {
        widgetAriaLabel:  WIDGET_ARIA,
        messagesAriaLabel:MESSAGES_ARIA,
        loadingAriaLabel: LOADING_ARIA,
        loadingText:      LOADING_TEXT,
        inputLabel:       INPUT_LABEL,
        inputAriaLabel:   INPUT_ARIA,
        inputPlaceholder: INPUT_PH,
        sendAriaLabel:    SEND_ARIA,
        sendLabel:        SEND_LABEL,
    };

    @track messages      = [];
    @track isLoading     = false;
    @track errorMessage  = null;
    @track inputText     = '';

    // Internal state — not reactive (don't need template re-render)
    _sessionId    = null;
    _sessionKey   = null;
    _transcript   = '';
    _branch       = null;
    _specialtyCode= null;
    _clusterKey   = null;
    _messageCount = 0;
    _mentorReq    = false;
    _mentorMatched= false;
    _sourceUrl    = '';
    _pendingInputFocus = false;   // set after a send; consumed in renderedCallback

    get isSendDisabled() {
        return this.isLoading || !this.inputText || !this.inputText.trim();
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this._sourceUrl = window.location.href;
        const storedId  = sessionStorage.getItem(SK_SESSION_ID);
        const storedKey = sessionStorage.getItem(SK_SESSION_KEY);
        if (storedId && storedKey) {
            this._sessionId  = storedId;
            this._sessionKey = storedKey;
        } else {
            this._startNewSession();
        }
    }

    disconnectedCallback() {
        sessionStorage.removeItem(SK_SESSION_ID);
        sessionStorage.removeItem(SK_SESSION_KEY);
    }

    // ── Event handlers ──────────────────────────────────────────────────────

    handleInput(evt) {
        this.inputText = evt.target.value;
    }

    handleKeydown(evt) {
        if (evt.key === 'Enter' && !this.isSendDisabled) {
            this.handleSend();
        }
    }

    async handleSend() {
        const text = this.inputText.trim();
        if (!text || this.isLoading || !this._sessionId) { return; }

        this.inputText    = '';
        this.errorMessage = null;
        this.isLoading    = true;
        this._messageCount++;

        this._appendMessage(text, 'user');
        this._extractConversationData(text);

        let agentReply = null;
        try {
            const result = await sendMessage({
                sessionId: this._sessionId,
                text:      text,
                sourceUrl: this._sourceUrl
            });
            if (result.success) {
                agentReply = result.replyText;
                this._appendMessage(agentReply, 'agent');
                this._extractAgentData(agentReply);
            } else {
                this.errorMessage = ERROR_MSG;
            }
        } catch (err) {
            this.errorMessage = ERROR_MSG;
        } finally {
            this.isLoading = false;
            this._appendTranscript(text, agentReply);
            this._logTurn(); // unconditional — fires even on error
            // Return focus to the input so a keyboard user can keep typing without
            // tabbing back. The input is disabled while isLoading is true, so we
            // can't focus it here — set a flag and focus in renderedCallback once
            // the re-render has re-enabled it.
            this._pendingInputFocus = true;
        }

        this._scrollToBottom();
    }

    renderedCallback() {
        if (this._pendingInputFocus) {
            const input = this.template.querySelector('.nm-input');
            if (input && !input.disabled) {
                this._pendingInputFocus = false;
                input.focus();
            }
        }
    }

    // ── Private helpers ─────────────────────────────────────────────────────

    async _startNewSession() {
        this.isLoading = true;
        try {
            const result = await startSession({ sourceUrl: this._sourceUrl });
            this._sessionId  = result.sessionId;
            this._sessionKey = result.sessionKey;
            sessionStorage.setItem(SK_SESSION_ID,  this._sessionId);
            sessionStorage.setItem(SK_SESSION_KEY, this._sessionKey);
        } catch (err) {
            this.errorMessage = ERROR_MSG;
        } finally {
            this.isLoading = false;
        }
    }

    _appendMessage(text, role) {
        this.messages = [...this.messages, {
            id:          ++_msgId,
            text:        text,
            cssClass:    role === 'user' ? 'nm-msg nm-msg--user' : 'nm-msg nm-msg--agent',
            senderLabel: role === 'user' ? YOU_LABEL : AGENT_LABEL
        }];
    }

    _appendTranscript(userText, agentText) {
        this._transcript += 'You: ' + userText + '\n';
        if (agentText) {
            this._transcript += AGENT_LABEL + ': ' + agentText + '\n';
        }
    }

    _extractConversationData(text) {
        // Branch detection
        if (!this._branch) {
            const lower = text.toLowerCase();
            for (const entry of BRANCH_KEYWORDS) {
                if (entry.patterns.some(p => lower.includes(p))) {
                    this._branch = entry.label;
                    break;
                }
            }
        }
        // Specialty code detection (MOS / AFSC / rate)
        if (!this._specialtyCode) {
            const match = SPECIALTY_CODE_RE.exec(text);
            if (match) { this._specialtyCode = match[1].toUpperCase(); }
        }
    }

    _extractAgentData(agentText) {
        if (!agentText) { return; }
        const lower = agentText.toLowerCase();
        // Simple heuristic: if the agent mentions mentor matching, record it
        if (!this._mentorReq && lower.includes('mentor')) {
            this._mentorReq = true;
        }
        if (!this._mentorMatched && (lower.includes('introduction') || lower.includes('connected you'))) {
            this._mentorMatched = true;
        }
    }

    _logTurn() {
        if (!this._sessionKey) { return; }
        const req = {
            sessionKey:     this._sessionKey,
            transcript:     this._transcript,
            branch:         this._branch,
            specialtyCode:  this._specialtyCode,
            clusterKey:     this._clusterKey,
            sourceUrl:      this._sourceUrl,
            messageCount:   this._messageCount,
            mentorRequested:this._mentorReq,
            mentorMatched:  this._mentorMatched
        };
        logTurn({ req }).catch(() => { /* silent — conversation logging must never surface to user */ });
    }

    _scrollToBottom() {
        const el = this.refs && this.refs.messageList;
        if (el) { el.scrollTop = el.scrollHeight; }
    }
}
