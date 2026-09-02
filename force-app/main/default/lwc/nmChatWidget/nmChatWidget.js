import { LightningElement, api, track } from 'lwc';
import startSession  from '@salesforce/apex/NM_AgentController.startSession';
import sendMessage   from '@salesforce/apex/NM_AgentController.sendMessage';
import logTurnFlat   from '@salesforce/apex/NM_AgentController.logTurnFlat';

import WIDGET_ARIA   from '@salesforce/label/c.NM_Chat_WidgetAriaLabel';
import LOADING_ARIA  from '@salesforce/label/c.NM_Chat_LoadingAriaLabel';
import INPUT_LABEL   from '@salesforce/label/c.NM_Chat_InputLabel';
import INPUT_ARIA    from '@salesforce/label/c.NM_Chat_InputAriaLabel';
import INPUT_PH      from '@salesforce/label/c.NM_Chat_InputPlaceholder';
import SEND_ARIA     from '@salesforce/label/c.NM_Chat_SendAriaLabel';
import SEND_LABEL    from '@salesforce/label/c.NM_Chat_SendLabel';
import YOU_LABEL     from '@salesforce/label/c.NM_Chat_YouLabel';
import AGENT_LABEL   from '@salesforce/label/c.NM_Chat_AgentLabel';
import ERROR_MSG     from '@salesforce/label/c.NM_Chat_ErrorMessage';
import TITLE         from '@salesforce/label/c.NM_Chat_Title';
import SUBTITLE      from '@salesforce/label/c.NM_Chat_Subtitle';
import GREETING      from '@salesforce/label/c.NM_Chat_Greeting';
import TYPING_ARIA   from '@salesforce/label/c.NM_Chat_TypingAria';
import SCROLL_LABEL  from '@salesforce/label/c.NM_Chat_ScrollRegionLabel';
import STARTERS_LBL  from '@salesforce/label/c.NM_Chat_StartersLabel';
import SUGGEST_LBL   from '@salesforce/label/c.NM_Chat_SuggestionsLabel';
import STARTER_ARIA  from '@salesforce/label/c.NM_Chat_StarterAriaPrefix';
import S1 from '@salesforce/label/c.NM_Chat_Starter1';
import S2 from '@salesforce/label/c.NM_Chat_Starter2';
import S3 from '@salesforce/label/c.NM_Chat_Starter3';
import S4 from '@salesforce/label/c.NM_Chat_Starter4';
import SUG_ROLES  from '@salesforce/label/c.NM_Chat_Sug_ShowRoles';
import SUG_SKILLS from '@salesforce/label/c.NM_Chat_Sug_Skills';
import SUG_MENTOR from '@salesforce/label/c.NM_Chat_Sug_Mentor';
import SUG_YES    from '@salesforce/label/c.NM_Chat_Sug_YesConnect';
import SUG_NO     from '@salesforce/label/c.NM_Chat_Sug_NotNow';
import SUG_RIGHT  from '@salesforce/label/c.NM_Chat_Sug_SoundsRight';
import SUG_ADD    from '@salesforce/label/c.NM_Chat_Sug_AddMore';
import SUG_MORE   from '@salesforce/label/c.NM_Chat_Sug_MoreRoles';
import LICENSE_BADGE from '@salesforce/label/c.NM_Chat_LicenseBadge';
import RESTART_LABEL from '@salesforce/label/c.NM_Chat_RestartLabel';
import RESTART_ARIA  from '@salesforce/label/c.NM_Chat_RestartAria';
import RESTARTED     from '@salesforce/label/c.NM_Chat_RestartedAnnounce';

const SK_SESSION_ID  = 'nm_session_id';
const SK_SESSION_KEY = 'nm_session_key';

const BRANCH_KEYWORDS = [
    { label: 'Army',        patterns: ['army','soldier','infantry','ranger','special forces','green beret','airborne','warrant officer'] },
    { label: 'Navy',        patterns: ['navy','sailor','seabee','seal','naval','ship','fleet'] },
    { label: 'Marines',     patterns: ['marine','marines','usmc','leatherneck','grunt'] },
    { label: 'Air Force',   patterns: ['air force','usaf','airman','pilot','aircraft','aviator'] },
    { label: 'Coast Guard', patterns: ['coast guard','uscg','coastie'] },
    { label: 'Space Force', patterns: ['space force','guardian','ussf'] }
];
const SPECIALTY_CODE_RE = /\b([A-Z]{1,2}[0-9]{1,3}[A-Z0-9]{0,3}|[0-9]{2}[A-Z0-9]{1,3}|[0-9]{4}[A-Z0-9]{0,2})\b/i;

// Icon paths, chosen from the occupation title so a card is recognisable at a glance.
const ICONS = {
    truck:    'M2 7h11v7H2z M13 10h4l3 3v1h-7z M6 17a2 2 0 1 0 0-4 2 2 0 0 0 0 4z M17 17a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
    medical:  'M10 3h4v5h5v4h-5v5h-4v-5H5V8h5z',
    aviation: 'M2 13l20-8-6 16-3-6z',
    tech:     'M4 5h16v10H4z M8 19h8v1H8z M9 9l-2 2 2 2 M15 9l2 2-2 2',
    logistics:'M4 6h9v8H4z M13 9h4l3 3v2h-7z M3 17h18v1H3z',
    security: 'M12 3l7 3v6c0 4-3 7-7 8-4-1-7-4-7-8V6z',
    trade:    'M6 3h6l2 4-3 3 6 6-3 3-6-6-3 3-4-4 3-3z',
    generic:  'M4 6h16v3H4z M4 11h16v3H4z M4 16h10v3H4z'
};
const ICON_RULES = [
    [/truck|driver|transport|haul|delivery/i,             'truck'],
    [/medic|health|nurse|patient|emergency|paramedic/i,   'medical'],
    [/air|avia|flight|aircraft|pilot|traffic control/i,   'aviation'],
    [/comput|network|softw|informat|cyber|data|systems/i, 'tech'],
    [/supply|logist|warehouse|invent|procure|shipping/i,  'logistics'],
    [/police|security|guard|protect|correct|law/i,        'security'],
    [/mechanic|repair|technician|maint|electric|weld/i,   'trade']
];
const LICENSE_RE = /commercial driver|cdl|licen[cs]|certifi|credential|endorsement/i;

const STEP_DEFS = [
    { key: 'bg',     label: 'Background' },
    { key: 'skills', label: 'Skills' },
    { key: 'roles',  label: 'Roles' },
    { key: 'mentor', label: 'Mentor' }
];

let _msgId = 0;
let _uid   = 0;

export default class NmChatWidget extends LightningElement {

    /** Resume upload ships behind this flag until extraction is proven. */
    @api enableResumeUpload = false;

    i18n = {
        widgetAriaLabel: WIDGET_ARIA,
        loadingAriaLabel: LOADING_ARIA,
        inputLabel: INPUT_LABEL,
        inputAriaLabel: INPUT_ARIA,
        inputPlaceholder: INPUT_PH,
        sendAriaLabel: SEND_ARIA,
        sendLabel: SEND_LABEL,
        agentLabel: AGENT_LABEL,
        title: TITLE,
        subtitle: SUBTITLE,
        typingAria: TYPING_ARIA,
        scrollRegionLabel: SCROLL_LABEL,
        stepsAria: 'Your progress through the conversation',
        restartLabel: RESTART_LABEL,
        restartAria: RESTART_ARIA
    };

    @track messages     = [];
    @track isLoading    = false;
    @track errorMessage = null;
    @track inputText    = '';
    @track _stage       = 0;
    @track _suggestions = null;
    @track announcement  = '';

    _sessionId = null;
    _sessionKey = null;
    _transcript = '';
    _branch = null;
    _specialtyCode = null;
    _clusterKey = null;
    _messageCount = 0;
    _mentorReq = false;
    _mentorMatched = false;
    _introSent = false;
    _sourceUrl = '';
    _shouldFocus = false;
    _shouldScroll = false;

    // ── Getters ─────────────────────────────────────────────────────────────

    get isSendDisabled() {
        return this.isLoading || !this.inputText || !this.inputText.trim();
    }

    get showChips() {
        return !this.isLoading && this.chips.length > 0;
    }

    get chipsLabel() {
        return this._messageCount === 0 ? STARTERS_LBL : SUGGEST_LBL;
    }

    get chips() {
        const list = this._messageCount === 0
            ? [S1, S2, S3, S4]
            : (this._suggestions || []);
        return list.map(t => ({ key: 'c' + (++_uid), text: t, aria: STARTER_ARIA + t }));
    }

    get steps() {
        return STEP_DEFS.map((s, i) => {
            const done    = i < this._stage;
            const current = i === this._stage;   // false for every step once complete
            return {
                key: s.key,
                label: s.label,
                done,
                current: current ? 'step' : 'false',
                statusText: done ? (s.label + ', done') : current ? (s.label + ', current step') : (s.label + ', not started'),
                cssClass: 'nm-step' + (done ? ' nm-step--done' : '') + (current ? ' nm-step--current' : '')
            };
        });
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this._sourceUrl = window.location.href;
        // Greet immediately. The panel is never empty, and this does not wait on the network.
        this._appendMessage(GREETING, 'agent');
        const id  = sessionStorage.getItem(SK_SESSION_ID);
        const key = sessionStorage.getItem(SK_SESSION_KEY);
        if (id && key) { this._sessionId = id; this._sessionKey = key; }
        else { this._startNewSession(); }
        this._shouldFocus = true;
        this._shouldScroll = true;
    }

    renderedCallback() {
        // Scroll HERE, not from the handler. LWC renders asynchronously, so
        // calling scrollTop right after setting state scrolled the OLD height
        // and left the newest reply below the fold, which meant scrolling by
        // hand after every single turn.
        if (this._shouldScroll) {
            this._shouldScroll = false;
            const list = this.refs && this.refs.messageList;
            if (list) { list.scrollTop = list.scrollHeight; }
        }
        if (this._shouldFocus) {
            this._shouldFocus = false;
            const el = this.refs && this.refs.input;
            if (el) { el.focus(); }
        }
    }

    /**
     * Only auto-scroll when the reader is already at the bottom. If they have
     * scrolled up to re-read something, yanking them back down mid-sentence is
     * worse than the problem it solves.
     */
    _isNearBottom() {
        const el = this.refs && this.refs.messageList;
        if (!el) { return true; }
        return (el.scrollHeight - el.scrollTop - el.clientHeight) < 120;
    }

    disconnectedCallback() {
        sessionStorage.removeItem(SK_SESSION_ID);
        sessionStorage.removeItem(SK_SESSION_KEY);
    }

    // ── Handlers ────────────────────────────────────────────────────────────

    handleInput(evt) { this.inputText = evt.target.value; }

    handleKeydown(evt) {
        if (evt.key === 'Enter' && !this.isSendDisabled) { this.handleSend(); }
        if (evt.key === 'Escape' && this.inputText) { this.inputText = ''; }
    }

    handleStarter(evt) {
        const text = evt.currentTarget.dataset.text;
        if (text) { this.inputText = text; this.handleSend(); }
    }

    handleUpload() { /* NMDH-31, wired once extraction is proven */ }

    /**
     * Clear everything and open a brand new agent session.
     * A new session is what actually resets the agent: conversation variables
     * live on the session, so clearing the UI alone would keep the old
     * background and the agent would still think it knows their code.
     */
    async handleRestart() {
        if (this.isLoading) { return; }

        this.messages      = [];
        this.errorMessage  = null;
        this.inputText     = '';
        this._suggestions  = null;
        this._stage        = 0;
        this._transcript   = '';
        this._branch       = null;
        this._specialtyCode= null;
        this._clusterKey   = null;
        this._messageCount = 0;
        this._mentorReq    = false;
        this._mentorMatched= false;
        this._introSent    = false;
        this._sessionId    = null;
        this._sessionKey   = null;

        sessionStorage.removeItem(SK_SESSION_ID);
        sessionStorage.removeItem(SK_SESSION_KEY);

        // Announced through the log region, which is already aria-live.
        this._appendMessage(RESTARTED, 'agent');
        this._announce(RESTARTED);
        this._appendMessage(GREETING, 'agent');

        await this._startNewSession();
        this._shouldFocus = true;
        this._scrollToBottom();
    }

    async handleSend() {
        const text = this.inputText.trim();
        if (!text || this.isLoading || !this._sessionId) { return; }

        this.inputText = '';
        this.errorMessage = null;
        this.isLoading = true;
        this._suggestions = null;
        this._messageCount++;

        const wasAtBottom = this._isNearBottom();
        this._appendMessage(text, 'user');
        this._extractConversationData(text);
        // Sending is an explicit act, so always follow the reader down.
        this._scrollToBottom();

        let agentReply = null;
        try {
            const result = await sendMessage({
                sessionId: this._sessionId, text, sourceUrl: this._sourceUrl
            });
            if (result.success) {
                agentReply = result.replyText;
                this._appendMessage(agentReply, 'agent');
                this._announce(agentReply);
                this._extractAgentData(agentReply);
                this._suggestions = this._suggestFor(agentReply);
            } else {
                this.errorMessage = ERROR_MSG;
                this._announce(ERROR_MSG);
            }
        } catch (err) {
            this.errorMessage = ERROR_MSG;
            this._announce(ERROR_MSG);
        } finally {
            this.isLoading = false;
            this._shouldFocus = true;   // keyboard users keep typing without tabbing back
            this._appendTranscript(text, agentReply);
            this._logTurn();
        }
        if (wasAtBottom) { this._scrollToBottom(); }
    }

    // ── Rendering helpers ───────────────────────────────────────────────────

    _appendMessage(text, role) {
        this.messages = [...this.messages, {
            id: ++_msgId,
            rowClass: role === 'user' ? 'nm-row nm-row--user' : 'nm-row nm-row--agent',
            senderLabel: role === 'user' ? YOU_LABEL : AGENT_LABEL,
            blocks: role === 'user'
                ? [{ key: 'b' + (++_uid), segments: this._segments(text) }]
                : this._parseBlocks(text)
        }];
    }

    /** Split **bold** runs so the template can render <strong> without innerHTML. */
    _segments(text) {
        const out = [];
        const re = /\*\*(.+?)\*\*/g;
        let last = 0, m;
        while ((m = re.exec(text)) !== null) {
            if (m.index > last) { out.push({ key: 's' + (++_uid), text: text.slice(last, m.index), bold: false }); }
            out.push({ key: 's' + (++_uid), text: m[1], bold: true });
            last = re.lastIndex;
        }
        if (last < text.length) { out.push({ key: 's' + (++_uid), text: text.slice(last), bold: false }); }
        return out.length ? out : [{ key: 's' + (++_uid), text, bold: false }];
    }

    _iconFor(title) {
        for (const [re, name] of ICON_RULES) { if (re.test(title)) { return ICONS[name]; } }
        return ICONS.generic;
    }

    /**
     * Turn a plain agent reply into renderable blocks: occupation cards,
     * a mentor card, bullet lists, and paragraphs. Every branch degrades to a
     * paragraph, so an unexpected reply shape still reads correctly.
     */
    _parseBlocks(text) {
        if (!text) { return [{ key: 'b' + (++_uid), segments: this._segments('') }]; }
        let chunks = text.split(/\n+/).map(c => c.trim()).filter(Boolean);
        if (chunks.length === 1) {
            chunks = text.split(/\s{2,}/).map(c => c.trim()).filter(Boolean);
        }

        const blocks = [];
        let listBuf = [];
        const flushList = () => {
            if (listBuf.length) {
                blocks.push({ key: 'b' + (++_uid), isList: true, items: listBuf });
                listBuf = [];
            }
        };

        for (const raw of chunks) {
            const bullet = raw.match(/^[-*•]\s+(.*)$/);
            if (bullet) {
                listBuf.push({ key: 'li' + (++_uid), segments: this._segments(bullet[1]) });
                continue;
            }
            flushList();

            const chunk = raw;

            if (/^i (found|have) a mentor/i.test(chunk) || /^here is a mentor/i.test(chunk)) {
                const nameM = chunk.match(/mentor(?: for you)?[:,]?\s+([A-Z][\w.'-]*(?:\s+[A-Z][\w.'-]*)?)/);
                const name = nameM ? nameM[1] : '';
                const initials = name
                    ? name.split(/\s+/).map(w => w[0]).join('').slice(0, 2).toUpperCase()
                    : '★';
                blocks.push({ key: 'b' + (++_uid), isPerson: true, text: chunk, initials });
                continue;
            }

            // "Title :: description" (the O*NET shape) or "Title: long description"
            let title = null, body = null;
            const dbl = chunk.match(/^[-*•]?\s*(.{3,70}?)\s*::\s*(.+)$/);
            if (dbl) {
                title = dbl[1]; body = dbl[2];
            } else {
                const col = chunk.match(/^([A-Z][^:]{2,60}?):\s+(.{40,})$/);
                if (col && !/\.$/.test(col[1])) { title = col[1]; body = col[2]; }
            }

            if (title && body) {
                blocks.push({
                    key: 'b' + (++_uid),
                    isCard: true,
                    title: title.trim(),
                    body: body.trim(),
                    iconPath: this._iconFor(title),
                    hasBadge: LICENSE_RE.test(body),
                    badge: LICENSE_BADGE
                });
                continue;
            }

            blocks.push({ key: 'b' + (++_uid), segments: this._segments(chunk) });
        }
        flushList();
        return blocks;
    }

    /** Contextual quick replies, derived from what the agent just asked. */
    _suggestFor(reply) {
        if (!reply) { return null; }
        const t = reply.toLowerCase();
        if (/introduction request .*(sent|has been)/.test(t)) { return null; }
        if (/(email address|your email)/.test(t)) { return null; }   // they must type it
        if (/introduction request on your behalf/.test(t)) { return [SUG_YES, SUG_NO]; }
        if (/connect with a mentor|talk to a mentor/.test(t)) { return [SUG_YES, SUG_SKILLS]; }
        if (/which (do|would) you (want|like)/.test(t)) { return [SUG_SKILLS, SUG_ROLES]; }
        if (/sound right|sounds right|resonate|anything you want to add/.test(t)) {
            return [SUG_RIGHT, SUG_ADD, SUG_MENTOR];
        }
        if (/\bcivilian (role|job)|truck driver|specialist|technician|manager\b/.test(t)) {
            return [SUG_MENTOR, SUG_SKILLS, SUG_MORE];
        }
        return [SUG_ROLES, SUG_SKILLS, SUG_MENTOR];
    }

    // ── Conversation data ───────────────────────────────────────────────────

    _appendTranscript(userText, agentText) {
        this._transcript += 'You: ' + userText + '\n';
        if (agentText) { this._transcript += AGENT_LABEL + ': ' + agentText + '\n'; }
    }

    _extractConversationData(text) {
        if (!this._branch) {
            const lower = text.toLowerCase();
            for (const e of BRANCH_KEYWORDS) {
                if (e.patterns.some(p => lower.includes(p))) { this._branch = e.label; break; }
            }
        }
        if (!this._specialtyCode) {
            const m = SPECIALTY_CODE_RE.exec(text);
            if (m) { this._specialtyCode = m[1].toUpperCase(); }
        }
    }

    _extractAgentData(reply) {
        if (!reply) { return; }
        const t = reply.toLowerCase();
        if (!this._mentorReq && t.includes('mentor')) { this._mentorReq = true; }
        if (!this._mentorMatched && (t.includes('introduction') || t.includes('connected you'))) {
            this._mentorMatched = true;
        }
        if (/(introduction|request)[^.]*\b(has been sent|was sent|is sent|sent)\b/.test(t)) {
            this._introSent = true;
        }
        // Stepper advances on facts, not on prose matching. An occupation card
        // means roles were actually shown; a person card means a mentor was
        // actually named. Regex over the reply text advanced it too eagerly.
        this._recomputeStage();
    }

    /**
     * Steps: 0 Background, 1 Skills, 2 Roles, 3 Mentor. The value is the INDEX
     * of the current step, so everything before it renders as done. Only ever
     * moves forward.
     */
    _recomputeStage() {
        // Only agent messages that REPLY to something count. The opening
        // greeting is long enough to look like a skills explanation, which used
        // to tick Background and Skills before the visitor had said a word.
        const replies = [];
        let seenUser = false;
        for (const m of this.messages) {
            if (m.senderLabel === YOU_LABEL) { seenUser = true; continue; }
            if (seenUser) { replies.push(m); }
        }
        const blocks = replies.reduce((acc, m) => acc.concat(m.blocks || []), []);

        const sawRoles  = blocks.some(b => b.isCard);
        const sawMentor = blocks.some(b => b.isPerson);
        const sawSkills = replies.some(m =>
            !(m.blocks || []).some(b => b.isCard || b.isPerson) &&
            (m.blocks || []).some(b => (b.segments || []).some(sg => (sg.text || '').length > 120))
        );

        let stage = 0;
        if (replies.length > 0) { stage = 1; }   // background established
        if (sawSkills)          { stage = 2; }
        if (sawRoles)           { stage = 3; }
        if (sawMentor)          { stage = 3; }
        // The journey has to be completable. Without this, Mentor stayed the
        // current step forever, even after an introduction was confirmed.
        if (this._introSent)    { stage = STEP_DEFS.length; }
        this._stage = Math.max(this._stage, stage);
    }

    async _startNewSession() {
        this.isLoading = true;
        try {
            const r = await startSession({ sourceUrl: this._sourceUrl });
            this._sessionId  = r.sessionId;
            this._sessionKey = r.sessionKey;
            sessionStorage.setItem(SK_SESSION_ID, this._sessionId);
            sessionStorage.setItem(SK_SESSION_KEY, this._sessionKey);
        } catch (err) {
            this.errorMessage = ERROR_MSG;
        } finally {
            this.isLoading = false;
        }
    }

    _logTurn() {
        if (!this._sessionKey) { return; }
        // Never silently swallowed. Conversation logging feeds the QA grader, and
        // a swallowed failure here is how transcripts went missing for weeks.
        logTurnFlat({
            sessionKey: this._sessionKey,
            transcript: this._transcript,
            branch: this._branch,
            specialtyCode: this._specialtyCode,
            clusterKey: this._clusterKey,
            sourceUrl: this._sourceUrl,
            messageCount: this._messageCount,
            mentorRequested: this._mentorReq,
            mentorMatched: this._mentorMatched
        }).catch(err => {
            // Deliberately console, not the error banner: a logging failure is
            // ours to fix and must never interrupt the veteran's conversation.
            // eslint-disable-next-line no-console
            console.error('NM logTurn failed', JSON.stringify(err && err.body ? err.body : err));
        });
    }

    /**
     * Push text into the live region. Cleared first so an identical consecutive
     * message still counts as a change; without that, screen readers say nothing
     * when the same text arrives twice.
     */
    _announce(text) {
        if (!text) { return; }
        this.announcement = '';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.announcement = text; }, 60);
    }

    _scrollToBottom() {
        this._shouldScroll = true;
    }
}
