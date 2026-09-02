import { LightningElement } from 'lwc';

export default class NmAbout extends LightningElement {

    steps = [
        { key: 's1', n: '1', title: 'Tell it what you did',
          body: 'Give your branch and specialty code, MOS, AFSC, Rating or NEC. No code, or a code we do not hold? Describe the work in your own words, or attach your resume. Your resume is read in your browser and never uploaded; only the text is sent.' },
        { key: 's2', n: '2', title: 'See it in civilian terms',
          body: 'It names the civilian occupations your code actually maps to, with what the work involves and any licence or certification you would need. Where a code maps to only one role, or to a catch-all category, it also shows the wider set people with that background move into, kept clearly separate from the direct match.' },
        { key: 's3', n: '3', title: 'Find out what they pay',
          body: 'Ask what any of them pay and it gives the national median, the range most people earn, and how many hold the job, from the Bureau of Labor Statistics. It will not estimate a figure it does not hold, and it says so when none is published.' },
        { key: 's3b', n: '4', title: 'Get your resume rewritten',
          body: 'Attach the resume you already have. It is read in your browser and never uploaded. Next Mission turns NCOIC into supervised a 12-person team, PMCS into preventive maintenance and inspection, and hands you back a Word document you can edit and send.' },
        { key: 's4', n: '5', title: 'Talk to someone who did it',
          body: 'It matches you to a mentor who made a similar move, and sends an introduction only after you say yes and give an email address.' }
    ];

    tries = [
        { key: 't1', input: 'Army 68W',      output: 'Paramedic' },
        { key: 't2', input: 'Army 68G',      output: 'Medical Records Specialist, a different answer from the same old cluster' },
        { key: 't3', input: 'Army 88M',      output: 'Heavy and Tractor-Trailer Truck Driver, CDL required' },
        { key: 't4', input: 'Navy V25C',     output: 'A code most models have never seen. It maps to a military job with no civilian equivalent, and it says so rather than inventing one' },
        { key: 't7', input: 'Army 92Y then \u201cwhat do those pay?\u201d', output: 'Stockers and Order Fillers at $37,090, and the logistics roles that background also reaches at $80,880' },
        { key: 't5', input: 'Air Force 2A552E', output: 'Aviation maintenance roles, full AFSC with skill level' },
        { key: 't6', input: 'I fixed helicopters in the Marines', output: 'Aviation roles, with no code given at all' }
    ];

    sources = [
        { key: 'x1', title: 'O*NET Military Crosswalk',
          body: 'Maps military specialty codes to civilian occupations. Maintained by the U.S. Department of Labor and free to use.',
          meta: '8,179 codes loaded across all six branches' },
        { key: 'x3', title: 'BLS Occupational Employment and Wage Statistics',
          body: 'National wage figures by occupation, published by the U.S. Bureau of Labor Statistics. Every pay figure shown comes from here; none is estimated.',
          meta: '968 of 1,016 occupations priced, May 2024 release' },
        { key: 'x2', title: 'O*NET Occupations',
          body: 'The federal occupation database behind CareerOneStop, supplying the description of what each civilian role actually involves.',
          meta: '1,016 occupations loaded' },
        { key: 'x3', title: 'Kept current, on purpose',
          body: 'A scheduled job checks weekly for a newer O*NET release and flags the data as stale rather than letting it drift silently out of date.',
          meta: 'Runs Sundays, verified against CronTrigger' }
    ];

    // Every figure here is reproducible: scripts/a11y-scan for the axe results,
    // scripts/check_contrast.py for the ratios. Do not change a number on this
    // page without re-running the thing that produced it.
    access = [
        { key: 'a1', title: 'Scanned against the WCAG standard',
          body: 'Checked with axe-core, the same engine behind Lighthouse, running against this live site in two states: the page as you first see it, and mid-conversation once results have loaded.',
          meta: '0 violations, 53 checks passed, WCAG 2.0 A and AA plus WCAG 2.1 A and AA' },
        { key: 'a2', title: 'Readable, and measured rather than guessed',
          body: 'Every text and background pairing on the site was measured for contrast, not eyeballed. Nothing depends on colour alone to make sense, so the checkmarks, badges and error messages all carry a shape or a word as well.',
          meta: '35 colour pairs measured, 0 below the AA threshold' },
        { key: 'a3', title: 'Usable without a mouse',
          body: 'Every control can be reached and operated with the Tab and Enter keys, each one shows a visible ring when focused, and you can always tab back out of the chat to the rest of the page.',
          meta: 'Keyboard path confirmed by hand, no keyboard trap' },
        { key: 'a4', title: 'Works with a screen reader',
          body: 'Replies from the assistant are announced as they arrive rather than sitting silently on screen, the message box and buttons are properly named, and decorative graphics are hidden so they are not read aloud as noise.',
          meta: 'Announcements verified with VoiceOver' },
        { key: 'a5', title: 'Respects how you have set up your device',
          body: 'If you have asked your system to reduce motion, the animations turn themselves off. Text is sized in relative units so it grows when you increase your browser or system text size.',
          meta: 'prefers-reduced-motion honoured' },
        { key: 'a6', title: 'Touch targets sized for real hands',
          body: 'Buttons and suggestion chips are large enough to hit reliably on a phone, including with a tremor or limited fine motor control.',
          meta: 'Minimum 44 by 44 pixels on every control' }
    ];

    guardrails = [
        { key: 'g1', title: 'It never invents a salary. ',
          body: 'Every pay figure is read from Bureau of Labor Statistics wage data we hold. It will not estimate, round from memory, or convert a figure itself, and where BLS publishes no median for a role it says so rather than implying the job pays nothing.' },
        { key: 'g1b', title: 'It shows the numbers it ranked on. ',
          body: 'If you ask which pays most it will tell you, and print what each one pays so you can see what the answer rests on. A ranking you cannot check is just an opinion with a number attached.' },
        { key: 'g1c', title: 'Your resume stays on your machine. ',
          body: 'A resume is read in your browser and only the text is sent. The file is never uploaded and never stored, because you should not have to hand over a document to ask a question about it.' },
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
