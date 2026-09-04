import { LightningElement } from 'lwc';

/*
 * The hero art used to be a decorative road. It is now the actual claim the
 * product makes: one specialty code fanning out into named civilian
 * occupations with real federal wage figures.
 *
 * ONE source for the data. The standalone HTML version kept a second, hand
 * written copy of every figure for screen readers, with a comment warning that
 * it goes stale silently. It would have. Here the visible scenes and the
 * screen-reader list are rendered from this same array, so they cannot drift.
 *
 * EVERY FIGURE HERE MUST EXIST IN NM_Wage__c. The graphic sits on the same page
 * as the agent, and the agent is required to name the Bureau of Labor Statistics
 * with every figure it gives. A hero quoting a different number for the same
 * occupation makes both of them look invented. These were taken from the org,
 * not from a web page: BLS OEWS May 2024, the release the agent actually holds.
 * scripts/hero_truth.py checks them and will fail if they drift.
 */
const SOURCE = 'BLS OEWS May 2024';

export default class NmHero extends LightningElement {

    // Counts are stated on the page because grounding is the differentiator.
    // Update these if the O*NET load changes.
    stats = [
        { key: 'codes', num: '8,179', label: 'military specialty codes' },
        { key: 'occs',  num: '1,016', label: 'civilian occupations' },
        { key: 'wage',  num: '968',   label: 'occupations with federal wage data' },
        { key: 'br',    num: '6',     label: 'service branches' }
    ];

    scenes = [
        {
            key: 'usmc3531', cls: 'nm-scene nm-scene-1',
            branch: 'U.S. Marine Corps', code: '3531', mos: 'Motor Vehicle Operator',
            heading: 'Marine Corps 3531, Motor Vehicle Operator',
            roles: [
                { key: 'r1', title: 'Transportation & Distribution Manager', wage: '$102,010',
                  sr: 'Transportation, Storage and Distribution Manager. Median annual wage $102,010.' },
                { key: 'r2', title: 'Logistician', wage: '$80,880',
                  sr: 'Logistician. Median annual wage $80,880.' },
                { key: 'r3', title: 'Heavy & Tractor-Trailer Truck Driver', wage: '$57,440',
                  sr: 'Heavy and Tractor-Trailer Truck Driver. Median annual wage $57,440.' }
            ]
        },
        {
            key: 'usnhm', cls: 'nm-scene nm-scene-2',
            branch: 'U.S. Navy', code: 'HM', mos: 'Hospital Corpsman',
            heading: 'Navy HM, Hospital Corpsman',
            roles: [
                { key: 'r1', title: 'Registered Nurse', wage: '$93,600',
                  sr: 'Registered Nurse. Median annual wage $93,600.' },
                { key: 'r2', title: 'Surgical Technologist', wage: '$62,830',
                  sr: 'Surgical Technologist. Median annual wage $62,830.' },
                { key: 'r3', title: 'Paramedic', wage: '$58,410',
                  sr: 'Paramedic. Median annual wage $58,410.' }
            ]
        },
        {
            key: 'usa25b', cls: 'nm-scene nm-scene-3',
            branch: 'U.S. Army', code: '25B', mos: 'Information Technology Specialist',
            heading: 'Army 25B, Information Technology Specialist',
            roles: [
                { key: 'r1', title: 'Information Security Analyst', wage: '$124,910',
                  sr: 'Information Security Analyst. Median annual wage $124,910.' },
                { key: 'r2', title: 'Network & Systems Administrator', wage: '$96,800',
                  sr: 'Network and Computer Systems Administrator. Median annual wage $96,800.' },
                { key: 'r3', title: 'Computer User Support Specialist', wage: '$60,340',
                  sr: 'Computer User Support Specialist. Median annual wage $60,340.' }
            ]
        }
    ];

    source = SOURCE;
    motion = 'paused';
    toggleLabel = 'Play animation';
    _mq;

    get isPlaying() { return this.motion === 'on'; }
    get artClass()  { return 'nm-art nm-motion-' + this.motion; }

    /*
     * Motion never starts uninvited for someone whose system asks for less of
     * it (WCAG 2.3.3), and because the loop runs longer than five seconds there
     * is always a real control to stop it (WCAG 2.2.2). Doing this in the
     * component rather than an inline script is also why this is an LWC: a
     * <script> pasted into an Experience Builder HTML component can be stripped,
     * which would leave a Play button that does nothing at all.
     */
    connectedCallback() {
        if (typeof window === 'undefined' || !window.matchMedia) {
            this._setMotion(true);
            return;
        }
        this._mq = window.matchMedia('(prefers-reduced-motion: reduce)');
        this._setMotion(!this._mq.matches);
        this._onPrefChange = (e) => this._setMotion(!e.matches);
        if (this._mq.addEventListener) this._mq.addEventListener('change', this._onPrefChange);
        else if (this._mq.addListener) this._mq.addListener(this._onPrefChange);
    }

    disconnectedCallback() {
        if (!this._mq || !this._onPrefChange) return;
        if (this._mq.removeEventListener) this._mq.removeEventListener('change', this._onPrefChange);
        else if (this._mq.removeListener) this._mq.removeListener(this._onPrefChange);
    }

    handleToggle() { this._setMotion(this.motion !== 'on'); }

    _setMotion(on) {
        this.motion = on ? 'on' : 'paused';
        this.toggleLabel = on ? 'Pause animation' : 'Play animation';
    }
}
