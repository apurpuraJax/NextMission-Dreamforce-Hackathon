// Seed script: demo mentor records for hackathon — one per cluster minimum,
// two or three for clusters most likely to appear in a live demo
// (Communications_IT, Engineering, Healthcare, Intelligence, Logistics).
//
// Run:    sf apex run --file scripts/apex/seed-demo-mentors.apex --target-org dreamforce-hackathon
// Safe to re-run: idempotent by Name — existing records are skipped.
//
// TO ADD THE 9TH CLUSTER (Law Enforcement / Security):
//   1. Add the CMDT record for LawEnforcement_Security in NM_Specialty_Cluster__mdt.
//   2. Append the Name to the existing.containsKey check list below.
//   3. Copy one of the example blocks below the "9TH CLUSTER" marker, un-comment it,
//      and populate the fields.  Re-run.  Done.

List<NM_Mentor__c> toInsert = new List<NM_Mentor__c>();

// ── Names we need to guard against duplicate inserts ───────────────────────
Set<String> targetNames = new Set<String>{
    // Original five
    'Alex R.', 'Jordan M.', 'Morgan T.', 'Casey W.', 'Taylor B.',
    // Expanded coverage
    'Devon S.', 'Riley K.', 'Quinn A.', 'Sage P.', 'Avery L.',
    'Cameron J.', 'Parker N.', 'Reese H.'
};

Map<String, NM_Mentor__c> existing = new Map<String, NM_Mentor__c>();
for (NM_Mentor__c m : [SELECT Name FROM NM_Mentor__c WHERE Name IN :targetNames]) {
    existing.put(m.Name, m);
}

// ── Helper: only insert if not already present ─────────────────────────────
List<NM_Mentor__c> desired = new List<NM_Mentor__c>();

// ── AVIATION (1) ───────────────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Devon S.',
    Branch__c          = 'Navy',
    Specialty_Cluster__c = 'Aviation',
    Civilian_Role__c   = 'Airline First Officer',
    Employer__c        = 'Cascade Regional Airways',
    Years_Since_Transition__c = 3,
    Bio__c             = 'I flew P-8 Poseidons for seven years. The ATP certificate process was straightforward — the FAA gives veterans significant credit for military flight hours. I can walk you through exactly how that translates and what the regional airline hiring pipeline looks like right now.',
    Contact_Email__c   = 'devon.s.demo@example.com',
    Active__c          = true
));

// ── COMBAT ARMS (1) ────────────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Casey W.',
    Branch__c          = 'Marine Corps',
    Specialty_Cluster__c = 'CombatArms',
    Civilian_Role__c   = 'Law Enforcement Officer',
    Employer__c        = 'Ashford County Sheriff\'s Office',
    Years_Since_Transition__c = 5,
    Bio__c             = 'I was an 0311 infantry rifleman. When I got out, law enforcement was a natural fit — the discipline, judgment under pressure, and team dynamic were already there. I went through the academy and made sergeant in three years. Let me know if you want to talk through how that transition looks.',
    Contact_Email__c   = 'casey.w.demo@example.com',
    Active__c          = true
));

// ── COMMUNICATIONS / IT (2) ────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Jordan M.',
    Branch__c          = 'Navy',
    Specialty_Cluster__c = 'Communications_IT',
    Civilian_Role__c   = 'Network Security Engineer',
    Employer__c        = 'Halcyon Systems',
    Years_Since_Transition__c = 6,
    Bio__c             = 'I was a Cryptologic Technician for eight years. After separating I earned a CompTIA Security+ and landed a network security role within six months. The hardest part was learning to describe what I did in civilian terms — that is exactly what I can help with.',
    Contact_Email__c   = 'jordan.m.demo@example.com',
    Active__c          = true
));
desired.add(new NM_Mentor__c(
    Name               = 'Riley K.',
    Branch__c          = 'Air Force',
    Specialty_Cluster__c = 'Communications_IT',
    Civilian_Role__c   = 'Cloud Infrastructure Engineer',
    Employer__c        = 'Meridian Cloud Partners',
    Years_Since_Transition__c = 4,
    Bio__c             = 'I was a Cyber Systems Operations specialist. My AWS certs from my last two years of service made me competitive right out of the gate. I can help you figure out which civilian certs map best to your MOS and which ones actually move the needle with hiring managers.',
    Contact_Email__c   = 'riley.k.demo@example.com',
    Active__c          = true
));

// ── ENGINEERING (2) ────────────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Quinn A.',
    Branch__c          = 'Army',
    Specialty_Cluster__c = 'Engineering',
    Civilian_Role__c   = 'Construction Project Manager',
    Employer__c        = 'Vantage Civil Group',
    Years_Since_Transition__c = 5,
    Bio__c             = 'I was a Combat Engineer officer. The jump to civilian construction PM was surprisingly direct — the planning cycles, subcontractor coordination, and safety culture overlap heavily with what I did in the Corps of Engineers. I can help you map your military projects to a civilian resume that PMs and superintendents actually recognize.',
    Contact_Email__c   = 'quinn.a.demo@example.com',
    Active__c          = true
));
desired.add(new NM_Mentor__c(
    Name               = 'Sage P.',
    Branch__c          = 'Navy',
    Specialty_Cluster__c = 'Engineering',
    Civilian_Role__c   = 'Nuclear Plant Operator',
    Employer__c        = 'Bridgewater Power Group',
    Years_Since_Transition__c = 2,
    Bio__c             = 'I was a Nuclear Machinist\'s Mate. Civilian nuclear utilities actively recruit Navy nuke vets — my background let me skip the entry-level pipeline entirely and go straight to licensed operator training. If that path interests you, I can explain exactly how hiring at commercial plants works.',
    Contact_Email__c   = 'sage.p.demo@example.com',
    Active__c          = true
));

// ── FINANCE / ADMIN (1) ───────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Avery L.',
    Branch__c          = 'Air Force',
    Specialty_Cluster__c = 'FinanceAdmin',
    Civilian_Role__c   = 'Financial Analyst',
    Employer__c        = 'Northgate Capital Advisors',
    Years_Since_Transition__c = 4,
    Bio__c             = 'I was a Financial Management specialist for eight years. I came out with a solid foundation in government contracting and budgeting, and added a CFA Level 1 during my last deployment. The transition to a civilian financial analyst role took about four months of targeted networking. Happy to share what worked.',
    Contact_Email__c   = 'avery.l.demo@example.com',
    Active__c          = true
));

// ── HEALTHCARE (2) ────────────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Morgan T.',
    Branch__c          = 'Air Force',
    Specialty_Cluster__c = 'Healthcare',
    Civilian_Role__c   = 'Respiratory Therapist',
    Employer__c        = 'Westbrook Regional Medical Center',
    Years_Since_Transition__c = 3,
    Bio__c             = 'I worked as an aerospace medical technician for 6 years. Getting a civilian license took some extra coursework, but the clinical experience I had from the Air Force gave me a real head start. I can walk you through how that licensure path works.',
    Contact_Email__c   = 'morgan.t.demo@example.com',
    Active__c          = true
));
desired.add(new NM_Mentor__c(
    Name               = 'Cameron J.',
    Branch__c          = 'Army',
    Specialty_Cluster__c = 'Healthcare',
    Civilian_Role__c   = 'Physician Assistant',
    Employer__c        = 'Lakeside Family Health Network',
    Years_Since_Transition__c = 7,
    Bio__c             = 'I was a Special Forces Medical Sergeant (18D) for ten years. The bridge programs for veteran medics have expanded a lot — I went through one of the early PA programs and I am happy to explain what options exist now and which ones are the fastest path to licensure for different MOS backgrounds.',
    Contact_Email__c   = 'cameron.j.demo@example.com',
    Active__c          = true
));

// ── INTELLIGENCE (2) ──────────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Taylor B.',
    Branch__c          = 'Space Force',
    Specialty_Cluster__c = 'Intelligence',
    Civilian_Role__c   = 'Intelligence Analyst',
    Employer__c        = 'Clearpath Analytics Group',
    Years_Since_Transition__c = 2,
    Bio__c             = 'I was a Space Systems Operations specialist. After separating I moved into an intelligence analyst role at a defense contractor — my clearance and analytical background made me a strong candidate. I am still pretty new to the civilian side but happy to share what the first two years have looked like.',
    Contact_Email__c   = 'taylor.b.demo@example.com',
    Active__c          = true
));
desired.add(new NM_Mentor__c(
    Name               = 'Parker N.',
    Branch__c          = 'Army',
    Specialty_Cluster__c = 'Intelligence',
    Civilian_Role__c   = 'Senior Threat Analyst',
    Employer__c        = 'Redstone Federal Solutions',
    Years_Since_Transition__c = 8,
    Bio__c             = 'I was a 35F All-Source Intelligence Analyst. After leaving the Army I moved into the defense contractor world and stayed there. I can help you understand the cleared contractor hiring market, how to protect and leverage your clearance, and what the difference looks like between government and contractor analyst roles.',
    Contact_Email__c   = 'parker.n.demo@example.com',
    Active__c          = true
));

// ── LOGISTICS (2) ─────────────────────────────────────────────────────────
desired.add(new NM_Mentor__c(
    Name               = 'Alex R.',
    Branch__c          = 'Army',
    Specialty_Cluster__c = 'Logistics',
    Civilian_Role__c   = 'Supply Chain Manager',
    Employer__c        = 'Meridian Distribution Co.',
    Years_Since_Transition__c = 4,
    Bio__c             = 'I spent 9 years managing logistics for a forward support battalion. When I got out, I moved into civilian supply chain and never looked back. The planning and problem-solving skills transferred directly. Happy to talk through what that shift looks like.',
    Contact_Email__c   = 'alex.r.demo@example.com',
    Active__c          = true
));
desired.add(new NM_Mentor__c(
    Name               = 'Reese H.',
    Branch__c          = 'Marine Corps',
    Specialty_Cluster__c = 'Logistics',
    Civilian_Role__c   = 'Operations Director',
    Employer__c        = 'Pacific Freight Alliance',
    Years_Since_Transition__c = 6,
    Bio__c             = 'I was a 0411 Maintenance Management Specialist. The move into freight and distribution operations felt natural — my Marines ran 24-hour maintenance cycles and I was already managing large asset inventories under pressure. I can help you identify which civilian ops titles actually match what you did and how to frame that on a resume.',
    Contact_Email__c   = 'reese.h.demo@example.com',
    Active__c          = true
));

// ─────────────────────────────────────────────────────────────────────────
// 9TH CLUSTER — LAW ENFORCEMENT / SECURITY
// When NM_Specialty_Cluster__mdt gains a LawEnforcement_Security record,
// un-comment the block below, add the Name to targetNames above, and re-run.
// ─────────────────────────────────────────────────────────────────────────
//
// desired.add(new NM_Mentor__c(
//     Name               = 'Finley O.',
//     Branch__c          = 'Marine Corps',
//     Specialty_Cluster__c = 'LawEnforcement_Security',
//     Civilian_Role__c   = 'Federal Police Officer',
//     Employer__c        = 'Department of Homeland Security',
//     Years_Since_Transition__c = 3,
//     Bio__c             = 'I was a Military Police officer. The federal law enforcement hiring process is ...',
//     Contact_Email__c   = 'finley.o.demo@example.com',
//     Active__c          = true
// ));
// ─────────────────────────────────────────────────────────────────────────

for (NM_Mentor__c m : desired) {
    if (!existing.containsKey(m.Name)) {
        toInsert.add(m);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('SUCCESS: Inserted ' + toInsert.size() + ' demo mentor record(s).');
    for (NM_Mentor__c m : toInsert) {
        System.debug('  + ' + m.Name + ' | ' + m.Specialty_Cluster__c + ' | ' + m.Branch__c);
    }
} else {
    System.debug('All demo mentor records already exist — no inserts needed.');
}
