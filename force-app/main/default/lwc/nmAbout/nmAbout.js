import { LightningElement } from 'lwc';

export default class NmAbout extends LightningElement {

    steps = [
        { key: 's1', n: '1', title: 'Tell it what you did',
          body: 'Give your branch and specialty code, MOS, AFSC, Rating or NEC. No code, or a code we do not hold? Describe the work in your own words instead and it will still place you.' },
        { key: 's2', n: '2', title: 'See it in civilian terms',
          body: 'It names the civilian occupations your code actually maps to, with what the work involves and any licence or certification you would need.' },
        { key: 's3', n: '3', title: 'Talk to someone who did it',
          body: 'It matches you to a mentor who made a similar move, and sends an introduction only after you say yes and give an email address.' }
    ];

    tries = [
        { key: 't1', input: 'Army 68W',      output: 'Paramedic' },
        { key: 't2', input: 'Army 68G',      output: 'Medical Records Specialist, a different answer from the same old cluster' },
        { key: 't3', input: 'Army 88M',      output: 'Heavy and Tractor-Trailer Truck Driver, CDL required' },
        { key: 't4', input: 'Navy V25C',     output: 'Artillery and Missile Crew Members, a code most models have never seen' },
        { key: 't5', input: 'Air Force 2A552E', output: 'Aviation maintenance roles, full AFSC with skill level' },
        { key: 't6', input: 'I fixed helicopters in the Marines', output: 'Aviation roles, with no code given at all' }
    ];

    sources = [
        { key: 'x1', title: 'O*NET Military Crosswalk',
          body: 'Maps military specialty codes to civilian occupations. Maintained by the U.S. Department of Labor and free to use.',
          meta: '8,179 codes loaded across all six branches' },
        { key: 'x2', title: 'O*NET Occupations',
          body: 'The federal occupation database behind CareerOneStop, supplying the description of what each civilian role actually involves.',
          meta: '1,016 occupations loaded' },
        { key: 'x3', title: 'Kept current, on purpose',
          body: 'A scheduled job checks weekly for a newer O*NET release and flags the data as stale rather than letting it drift silently out of date.',
          meta: 'Runs Sundays, verified against CronTrigger' }
    ];

    guardrails = [
        { key: 'g1', title: 'It never invents a salary. ',
          body: 'We hold no wage data, so it says so and points to the Bureau of Labor Statistics instead of guessing a number someone might plan a career around.' },
        { key: 'g2', title: 'Introductions require consent. ',
          body: 'A mentor is only contacted after an explicit yes and an email address. Nothing is sent automatically, and a mentor email is never shown.' },
        { key: 'g3', title: 'Sensitive disclosures are not repeated. ',
          body: 'If someone mentions a discharge type, disability rating or VA status, it acknowledges them like a colleague would and moves on. It does not restate it, summarise it, or bring it up again.' },
        { key: 'g4', title: 'An unknown code is our gap, not your mistake. ',
          body: 'The crosswalk is large but not exhaustive. When a code is missing it says so plainly and switches to asking what you did, rather than implying you typed it wrong.' },
        { key: 'g5', title: 'It only says what the data returned. ',
          body: 'Occupations come from the crosswalk, never from the model. It does not claim an introduction was sent unless the record was actually created.' }
    ];
}
