import { LightningElement } from 'lwc';

export default class NmHero extends LightningElement {
    // Counts are stated on the page because grounding is the differentiator.
    // Update these if the O*NET load changes.
    stats = [
        { key: 'codes', num: '8,179', label: 'military specialty codes' },
        { key: 'occs',  num: '1,016', label: 'civilian occupations' },
        { key: 'wage',  num: '968',   label: 'occupations with federal wage data' },
        { key: 'br',    num: '6',     label: 'service branches' }
    ];
}
