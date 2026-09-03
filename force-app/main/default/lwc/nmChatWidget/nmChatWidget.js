import { LightningElement, api, track } from 'lwc';
import startSession  from '@salesforce/apex/NM_AgentController.startSession';
import sendMessage   from '@salesforce/apex/NM_AgentController.sendMessage';
import logTurnFlat   from '@salesforce/apex/NM_AgentController.logTurnFlat';
import sendResume    from '@salesforce/apex/NM_AgentController.sendResume';

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
import SUG_PAY       from '@salesforce/label/c.NM_Chat_Sug_Pay';
import SUG_RESUME    from '@salesforce/label/c.NM_Chat_Sug_ResumeHelp';
import SUG_RECAP     from '@salesforce/label/c.NM_Chat_Sug_Recap';
import DL_LABEL      from '@salesforce/label/c.NM_Chat_ResumeDownload';
import DL_BUILDING   from '@salesforce/label/c.NM_Chat_ResumeBuilding';
import DL_READY      from '@salesforce/label/c.NM_Chat_ResumeReady';
import DL_FAILED     from '@salesforce/label/c.NM_Chat_ResumeDocFailed';
import ATTACH_ARIA   from '@salesforce/label/c.NM_Chat_AttachAria';
import RES_READING   from '@salesforce/label/c.NM_Chat_ResumeReading';
import RES_SENT      from '@salesforce/label/c.NM_Chat_ResumeSent';
import RES_TOOBIG    from '@salesforce/label/c.NM_Chat_ResumeTooBig';
import RES_WRONGTYPE from '@salesforce/label/c.NM_Chat_ResumeWrongType';
import RES_NOTEXT    from '@salesforce/label/c.NM_Chat_ResumeNoText';
import RES_FAILED    from '@salesforce/label/c.NM_Chat_ResumeFailed';
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

// Roles shown before the rest collapse behind a button. A reply carrying five
// roles with pay is fifteen figures in one screen-reader announcement.
const CARD_PREVIEW = 3;

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
        attachAria: ATTACH_ARIA,
        downloadLabel: DL_LABEL,
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

        // Greet immediately so the panel is never empty and this does not wait
        // on the network.
        this._appendMessage(GREETING, 'agent');

        // ALWAYS start a new agent session. Do not restore a stored one.
        //
        // The widget renders a fresh greeting on every load, so restoring the
        // previous session put the screen and the agent into different states:
        // the visitor saw a blank conversation while the agent still held their
        // previous background. Someone who had been looking at construction
        // roles, reloaded, and typed "Army 88M" got construction jobs back,
        // because the router still saw an established cluster and skipped the
        // code lookup entirely. The reply looked confident and was wrong.
        //
        // Whatever is on screen and whatever the agent remembers must be the
        // same conversation. A reload starts over, which is what the greeting
        // already implies.
        sessionStorage.removeItem(SK_SESSION_ID);
        sessionStorage.removeItem(SK_SESSION_KEY);
        this._startNewSession();

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

    // ── Resume document ─────────────────────────────────────────────────────

    // The button appears only once there is something to build a resume FROM.
    // Offering it before that produces an empty document and wastes their time.
    @track _canBuildResume = false;

    // OFF until the download path actually works end to end in a browser.
    // Reading the resume and rewriting it both work; turning that into a file
    // does not, and a button that always fails is worse than no button. See
    // CONTEXT.md for what was tried and what is left.
    _resumeDownloadReady = false;

    get showResumeDownload() {
        return this._resumeDownloadReady && this._canBuildResume && !this.isLoading;
    }

    /*
     * Ask the agent for the resume in a strict labelled format, turn it into a
     * Word-compatible document and hand it over.
     *
     * Word, not PDF. A resume they cannot edit is not much use: they will want
     * to fix a word, add a job, tailor it per application. Word-flavoured HTML
     * opens cleanly in Word, Google Docs and Pages and stays editable.
     */
    async handleDownloadResume() {
        if (this.isLoading || !this._sessionId) { return; }
        this.errorMessage = null;
        this.isLoading = true;
        this._announce(DL_BUILDING);
        try {
            // Ask twice if the first answer comes back as prose. The strict
            // format is a contract the model can drift off, and a veteran who
            // clicked download should not be told to copy the text by hand
            // because of one bad turn.
            let parsed = null;
            for (const attempt of [1, 2]) {
                const prompt = attempt === 1
                    ? '[RESUME_DOC] Build the complete resume now.'
                    : '[RESUME_DOC] Output ONLY the labelled lines, starting with NAME:. '
                      + 'No preamble and no questions.';
                // eslint-disable-next-line no-await-in-loop
                const result = await sendMessage({
                    sessionId: this._sessionId, text: prompt, sourceUrl: this._sourceUrl
                });
                parsed = result && result.success
                    ? this._parseResume(result.replyText) : null;
                if (parsed && parsed.bullets.length) { break; }
                parsed = null;
            }
            // Last resort: build from what is already on screen. Asking the
            // model for a strict format and parsing it with a regex is fragile,
            // and a veteran who clicked download should get a document rather
            // than an apology. The rewritten lines are already in the
            // transcript; use those.
            if (!parsed) { parsed = this._resumeFromTranscript(); }
            if (!parsed) {
                this.errorMessage = DL_FAILED;
                this._announce(DL_FAILED);
                return;
            }
            this._downloadDoc(parsed);
            // Say it downloaded AND that they must check it. This is their name
            // on a document going to employers; it is not ours to finalise.
            this._appendMessage(DL_READY, 'agent');
            this._announce(DL_READY);
        } catch (err) {
            this.errorMessage = DL_FAILED;
            this._announce(DL_FAILED);
        } finally {
            this.isLoading = false;
            this._shouldFocus = true;
            this._scrollToBottom();
        }
    }

    /*
     * Build a resume from the conversation itself when the labelled format did
     * not come back. Takes the most recent agent turn that reads like rewritten
     * resume content and uses its lines as the bullets.
     */
    _resumeFromTranscript() {
        for (let i = this.messages.length - 1; i >= 0; i--) {
            const m = this.messages[i];
            if (m.senderLabel === YOU_LABEL) { continue; }
            const text = m.raw || '';
            let lines = text.split('\n')
                .map(l => l.replace(/^[\s\-•*]+/, '').trim())
                .filter(l => l.length > 35 && !l.endsWith('?'));
            // Replies often arrive as one unbroken paragraph, so fall back to
            // sentences. Requiring separate lines meant this safety net never
            // fired on exactly the replies it existed for.
            if (lines.length < 3) {
                lines = text.replace(/\s+/g, ' ').split(/(?<=\.)\s+/)
                    .map(l => l.trim())
                    .filter(l => l.length > 35 && !l.endsWith('?'));
            }
            if (lines.length >= 3) {
                return {
                    name: 'Your Name',
                    headline: '',
                    summary: '',
                    experience: '',
                    bullets: lines.slice(0, 8),
                    skills: '',
                    clearance: ''
                };
            }
        }
        return null;
    }

    /*
     * Parse the labelled resume block.
     *
     * Split on the LABELS, not on newlines. The reply arrives with its line
     * breaks stripped, so "NAME: Jane HEADLINE: Diesel Mechanic BULLET: ..."
     * comes through as one line and a line-based parser found only the first
     * field and quietly produced an empty document.
     */
    _parseResume(text) {
        if (!text) { return null; }
        const clean = text.replace(/[*_`>]/g, ' ').replace(/\s+/g, ' ').trim();
        const label = /(NAME|HEADLINE|SUMMARY|EXPERIENCE|BULLET|SKILLS|CLEARANCE)\s*:\s*/g;

        const hits = [];
        let m;
        while ((m = label.exec(clean)) !== null) {
            hits.push({ key: m[1], from: m.index + m[0].length });
        }
        if (!hits.length) { return null; }

        const out = { name: 'Your Name', headline: '', summary: '',
                      experience: '', bullets: [], skills: '', clearance: '' };
        hits.forEach((h, n) => {
            const to = n + 1 < hits.length
                ? clean.lastIndexOf(hits[n + 1].key, hits[n + 1].from)
                : clean.length;
            const value = clean.slice(h.from, to).trim().replace(/[-–|]+$/, '').trim();
            if (!value) { return; }
            switch (h.key) {
                case 'NAME':       out.name = value; break;
                case 'HEADLINE':   out.headline = value; break;
                case 'SUMMARY':    out.summary = value; break;
                case 'EXPERIENCE': out.experience = value; break;
                case 'BULLET':     out.bullets.push(value); break;
                case 'SKILLS':     out.skills = value; break;
                case 'CLEARANCE':  out.clearance = value; break;
                default: break;
            }
        });
        return out;
    }

    _esc(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    _downloadDoc(r) {
        const section = (title, inner) => inner
            ? '<h2 style="font-size:11pt;text-transform:uppercase;letter-spacing:1px;'
            + 'border-bottom:1px solid #999;padding-bottom:2pt;margin:14pt 0 6pt;">'
            + this._esc(title) + '</h2>' + inner : '';

        const html =
            '<html xmlns:o="urn:schemas-microsoft-com:office:office" '
          + 'xmlns:w="urn:schemas-microsoft-com:office:word" '
          + 'xmlns="http://www.w3.org/TR/REC-html40"><head><meta charset="utf-8">'
          + '<title>' + this._esc(r.name) + '</title></head>'
          + '<body style="font-family:Calibri,Arial,sans-serif;font-size:11pt;color:#000;">'
          + '<h1 style="font-size:20pt;margin:0;">' + this._esc(r.name) + '</h1>'
          + (r.headline ? '<p style="margin:2pt 0 0;font-size:12pt;color:#333;">'
              + this._esc(r.headline) + '</p>' : '')
          + section('Summary', r.summary
              ? '<p style="margin:0;">' + this._esc(r.summary) + '</p>' : '')
          + section('Experience', r.experience
              ? '<p style="margin:0 0 4pt;font-weight:bold;">'
                + this._esc(r.experience) + '</p>'
                + '<ul style="margin:0 0 0 18pt;padding:0;">'
                + r.bullets.map(b => '<li style="margin-bottom:3pt;">'
                    + this._esc(b) + '</li>').join('')
                + '</ul>'
              : '<ul style="margin:0 0 0 18pt;padding:0;">'
                + r.bullets.map(b => '<li>' + this._esc(b) + '</li>').join('') + '</ul>')
          + section('Skills', r.skills
              ? '<p style="margin:0;">' + this._esc(r.skills) + '</p>' : '')
          + section('Clearance', r.clearance
              ? '<p style="margin:0;">' + this._esc(r.clearance) + '</p>' : '')
          + '</body></html>';

        const blob = new Blob(['\ufeff', html], { type: 'application/msword' });
        const url  = URL.createObjectURL(blob);
        const a    = this.refs.dlAnchor;
        a.href = url;
        a.download = (r.name || 'resume').replace(/[^A-Za-z0-9]+/g, '_') + '_Resume.doc';
        a.click();
        // Revoke on a later tick. Revoking immediately cancels the download in
        // some browsers before it has finished reading the blob.
        setTimeout(() => URL.revokeObjectURL(url), 8000);
    }

    // ── Resume upload ───────────────────────────────────────────────────────

    /*
     * The file is read in the browser and only its TEXT is sent. Someone asking
     * a question about their resume should not have to hand us the document to
     * get an answer, and we have no reason to hold it.
     */
    async handleFile(evt) {
        const input = evt.target;
        const file  = input.files && input.files[0];
        if (!file) { return; }

        // Clear immediately so choosing the SAME file again still fires change.
        input.value = '';

        const name  = file.name || 'resume';
        const lower = name.toLowerCase();
        const isPdf = file.type === 'application/pdf' || lower.endsWith('.pdf');
        const isTxt = /^text\//.test(file.type || '') ||
                      lower.endsWith('.txt') || lower.endsWith('.md');

        if (!isPdf && !isTxt) { this._resumeError(RES_WRONGTYPE); return; }
        if (file.size > 5 * 1024 * 1024) { this._resumeError(RES_TOOBIG); return; }

        this.errorMessage = null;
        this.isLoading    = true;
        this._suggestions = null;
        this._announce(RES_READING);

        // Show the veteran what they just did, without dumping the whole
        // resume into the transcript.
        this._messageCount++;
        this._appendMessage(RES_SENT + ': ' + name, 'user');
        this._scrollToBottom();

        let agentReply = null;
        try {
            const text = isPdf ? await this._pdfText(file) : await file.text();
            if (!text || !text.trim()) { this._resumeError(RES_NOTEXT); return; }
            this._canBuildResume = true;

            const result = await sendResume({
                sessionId: this._sessionId,
                resumeText: text,
                fileName: name,
                sourceUrl: this._sourceUrl
            });
            if (result && result.success) {
                agentReply = result.replyText;
                this._appendMessage(agentReply, 'agent');
                this._announce(agentReply);
                this._extractAgentData(agentReply);
                this._suggestions = this._suggestFor(agentReply);
            } else {
                this._resumeError((result && result.errorMessage) || RES_FAILED);
                return;
            }
        } catch (err) {
            this._resumeError(RES_FAILED);
            return;
        } finally {
            this.isLoading  = false;
            this._shouldFocus = true;
            this._appendTranscript(RES_SENT + ': ' + name, agentReply);
            this._logTurn();
        }
        this._scrollToBottom();
    }

    /*
     * Surface a resume problem the same way any other error is surfaced, and
     * ALWAYS announce it. A failure a screen-reader user cannot hear is a
     * dead end with no explanation.
     */
    _resumeError(msg) {
        this.errorMessage = msg;
        this.isLoading    = false;
        this._shouldFocus = true;
        this._announce(msg);
    }

    /*
     * Read the text out of a PDF with no library at all.
     *
     * pdf.js cannot work on this site. Its worker must load from a static
     * resource, and Lightning Web Security blocks that outright: "Cannot
     * request disallowed endpoint". Without a worker pdf.js falls back to
     * main-thread parsing that never resolves under LWS, so an upload sat on
     * the typing indicator forever with no error, while the same API call
     * worked perfectly from a script.
     *
     * So this parses the file directly. Page content lives in stream objects,
     * usually Flate-compressed, which the browser inflates natively with
     * DecompressionStream. Inside a content stream the text is in the arguments
     * to Tj, TJ, ' and ", and the positioning operators mark the line breaks.
     *
     * This reads text-based PDFs, which is what a resume is. It will not read a
     * scan, and does not pretend to; that gets an honest message telling them
     * to paste the text instead.
     */
    async _pdfText(file) {
        const bytes = new Uint8Array(await file.arrayBuffer());
        const streams = await this._pdfStreams(bytes);
        const pages = [];
        for (const stream of streams) {
            const t = this._textFromContentStream(stream);
            if (t.trim()) { pages.push(t.trim()); }
        }
        return pages.join('\n\n');
    }

    /* Every content stream in the file, inflated where necessary. */
    async _pdfStreams(bytes) {
        const latin = new TextDecoder('latin1');
        const raw = latin.decode(bytes);
        const out = [];
        let i = 0;
        while (out.length < 60) {
            const s = raw.indexOf('stream', i);
            if (s === -1) { break; }
            const dict = raw.slice(Math.max(0, raw.lastIndexOf('<<', s)), s);
            let from = s + 6;
            if (raw[from] === '\r') { from++; }
            if (raw[from] === '\n') { from++; }
            const e = raw.indexOf('endstream', from);
            if (e === -1) { break; }
            i = e + 9;

            // Fonts, images and metadata are not page text.
            if (/\/Subtype\s*\/Image|\/FontFile|\/Metadata/.test(dict)) { continue; }

            // The bytes just before "endstream" are an EOL belonging to the
            // syntax, not the data. Leaving them on makes the inflater report
            // "junk found after end of compressed data" and throw away a
            // stream it had already decoded correctly.
            let stop = e;
            while (stop > from && (bytes[stop - 1] === 0x0a || bytes[stop - 1] === 0x0d)) {
                stop--;
            }
            const slice = bytes.subarray(from, stop);
            if (/\/FlateDecode/.test(dict)) {
                try {
                    // eslint-disable-next-line no-await-in-loop
                    out.push(latin.decode(await this._inflate(slice)));
                } catch (err) {
                    // One unreadable stream should not lose the others.
                }
            } else if (!/\/Filter/.test(dict)) {
                out.push(latin.decode(slice));
            }
        }
        return out;
    }

    /*
     * Inflate one stream.
     *
     * Read the DecompressionStream by hand rather than with
     * `new Response(stream).arrayBuffer()`. Wrapping a stream in a Response
     * counts as a fetch, and this site blocks it: every stream came back
     * "TypeError: Failed to fetch" while the stream parsing itself was
     * perfect. A plain reader touches no network API at all.
     *
     * Producers are inconsistent about the zlib wrapper, so try both framings
     * rather than trust what the dictionary claims.
     */
    async _inflate(slice) {
        for (const format of ['deflate', 'deflate-raw']) {
            try {
                const ds = new DecompressionStream(format);
                const writer = ds.writable.getWriter();
                // Swallow the writer's own rejection. It rejects independently
                // of the reader, and an unhandled rejection surfaces as a page
                // error even though we handle the failure below.
                writer.write(slice).catch(() => {});
                writer.close().catch(() => {});

                const reader = ds.readable.getReader();
                const chunks = [];
                let total = 0;
                try {
                    for (;;) {
                        // eslint-disable-next-line no-await-in-loop
                        const { value, done } = await reader.read();
                        if (done) { break; }
                        chunks.push(value);
                        total += value.length;
                    }
                } catch (readErr) {
                    // A trailing-junk complaint arrives AFTER the real content
                    // has been handed over. Keep what we already decoded.
                }
                if (total > 0) {
                    const out = new Uint8Array(total);
                    let at = 0;
                    for (const c of chunks) { out.set(c, at); at += c.length; }
                    return out;
                }
            } catch (err) {
                // Wrong framing, or genuinely not deflate. Try the other one.
            }
        }
        throw new Error('could not inflate stream');
    }

    /*
     * One content stream to readable text. Tj and ' take a string, TJ takes an
     * array of strings and kerning numbers, and the positioning operators Td,
     * TD, T-star and ET are where the line breaks come from.
     */
    _textFromContentStream(content) {
        let out = '';
        let pending = '';
        let i = 0;

        const readString = () => {
            let depth = 1;
            let str = '';
            i++;
            while (i < content.length && depth > 0) {
                const c = content[i];
                if (c === '\\') {
                    const n = content[i + 1];
                    const oct = content.substr(i + 1, 3).match(/^[0-7]{1,3}/);
                    if (oct) {
                        str += String.fromCharCode(parseInt(oct[0], 8));
                        i += 1 + oct[0].length;
                        continue;
                    }
                    const map = { n: '\n', r: '', t: ' ', b: '', f: '' };
                    str += (n in map) ? map[n] : n;
                    i += 2;
                    continue;
                }
                if (c === '(') { depth++; }
                if (c === ')') { depth--; if (depth === 0) { i++; break; } }
                str += c;
                i++;
            }
            return str;
        };

        while (i < content.length) {
            const c = content[i];
            if (c === '(') { pending += readString(); continue; }
            if (c === '<' && content[i + 1] !== '<') {
                const close = content.indexOf('>', i);
                if (close > i) {
                    const hex = content.slice(i + 1, close).replace(/[^0-9a-fA-F]/g, '');
                    for (let h = 0; h + 1 < hex.length; h += 2) {
                        const code = parseInt(hex.substr(h, 2), 16);
                        if (code >= 32) { pending += String.fromCharCode(code); }
                    }
                    i = close + 1;
                    continue;
                }
            }
            if (content.startsWith('Td', i) || content.startsWith('TD', i) ||
                content.startsWith('T*', i) || content.startsWith('ET', i)) {
                if (pending.trim()) { out += pending.trim() + '\n'; pending = ''; }
                i += 2;
                continue;
            }
            i++;
        }
        if (pending.trim()) { out += pending.trim() + '\n'; }
        return out;
    }

    // ── Rendering helpers ───────────────────────────────────────────────────

    _appendMessage(text, role) {
        this.messages = [...this.messages, {
            id: ++_msgId,
            // Keep the original text. Blocks are a render structure with several
            // shapes (segments, list items, cards), and reconstructing the text
            // from them is guesswork that silently returns nothing.
            raw: text,
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
        return this._groupCards(blocks);
    }

    /*
     * Turn runs of consecutive role cards into a single list.
     *
     * Five sibling <article> elements gave a screen reader headings to jump
     * between but no sense of how many there were or where the user was. A real
     * <ul> gives AT its own "list, 5 items" count, and each card also carries a
     * spoken "Role 2 of 5" because that list count is not reliable across every
     * browser and screen reader pairing. Both, deliberately.
     *
     * Long runs also collapse after the third. A reply carrying five roles with
     * pay is fifteen figures in one announcement, which is a cognitive-load
     * barrier rather than a formatting preference; the rest stay one button away.
     */
    _groupCards(blocks) {
        const out = [];
        let run = [];
        const flush = () => {
            if (!run.length) { return; }
            if (run.length === 1) {
                out.push(run[0]);
            } else {
                const total = run.length;
                out.push({
                    key: 'cards' + (++_uid),
                    isCardList: true,
                    total,
                    collapsible: total > CARD_PREVIEW,
                    showAllLabel: 'Show the other ' + (total - CARD_PREVIEW) + ' roles',
                    cards: run.map((c, i) => ({
                        ...c,
                        position: 'Role ' + (i + 1) + ' of ' + total,
                        hidden: total > CARD_PREVIEW && i >= CARD_PREVIEW
                    }))
                });
            }
            run = [];
        };
        for (const b of blocks) {
            if (b.isCard) { run.push(b); continue; }
            flush();
            out.push(b);
        }
        flush();
        return out;
    }

    /* Reveal the rest of a collapsed role list. */
    handleShowAllCards(evt) {
        const key = evt.currentTarget.dataset.key;
        this.messages = this.messages.map(m => ({
            ...m,
            blocks: (m.blocks || []).map(b => b.key !== key ? b : {
                ...b,
                collapsible: false,
                cards: b.cards.map(c => ({ ...c, hidden: false }))
            })
        }));
        this._announce('Showing all roles.');
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
        // Right after a skills translation is when resume help lands best: they
        // have just seen their own work described in civilian words.
        if (/sound right|sounds right|resonate|anything you want to add/.test(t)) {
            return [SUG_RIGHT, SUG_RESUME, SUG_MENTOR];
        }
        // Once a figure is on screen, offering to fetch pay again is noise.
        const hasPay = /\$\s?\d/.test(reply);
        if (/\bcivilian (role|job)|truck driver|specialist|technician|manager\b/.test(t)) {
            return hasPay ? [SUG_MENTOR, SUG_SKILLS, SUG_MORE]
                          : [SUG_PAY, SUG_MENTOR, SUG_SKILLS];
        }
        return this._withRecap([SUG_ROLES, SUG_SKILLS, SUG_MENTOR]);
    }

    /*
     * Offer a recap once there is something to recap.
     *
     * The agent could already answer "what have we covered so far?" accurately.
     * Nothing told anyone it could, so the capability existed and no one could
     * find it. That is a discoverability failure, not a missing feature, and the
     * suggested actions are where it belongs.
     */
    _withRecap(list) {
        return this._messageCount >= 3 ? [...list, SUG_RECAP] : list;
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
