// Seed script: 13 NM_Conversation__c records for QA grader validation.
// 3 records update existing stubs (adds transcripts + branch/specialty metadata).
// 10 records are new (varied branch / specialty / outcome).
// CONV-0006 (seed-qa-nmdh19-007) — deliberately bad: agent invents salary figures.
// CONV-0007 (seed-qa-nmdh19-008) — deliberately bad: off-limits words, ranking, role override.
// Idempotent by External_Session_Key__c — safe to re-run.
//
// Run: sf apex run --file scripts/apex/seed-conversations.apex --target-org dreamforce-hackathon

// ── Keys this script manages ──────────────────────────────────────────────────
Set<String> targetKeys = new Set<String>{
    'seed-qa-nmdh19-001', 'seed-qa-nmdh19-002', 'seed-qa-nmdh19-003',
    'seed-qa-nmdh19-004', 'seed-qa-nmdh19-005', 'seed-qa-nmdh19-006',
    'seed-qa-nmdh19-007', 'seed-qa-nmdh19-008', 'seed-qa-nmdh19-009',
    'seed-qa-nmdh19-010', 'seed-qa-nmdh19-011', 'seed-qa-nmdh19-012',
    'seed-qa-nmdh19-013'
};

Map<String, Id> existingIdMap = new Map<String, Id>();
for (NM_Conversation__c c : [
    SELECT Id, External_Session_Key__c
    FROM NM_Conversation__c
    WHERE External_Session_Key__c IN :targetKeys
]) {
    existingIdMap.put(c.External_Session_Key__c, c.Id);
}

List<NM_Conversation__c> toInsert = new List<NM_Conversation__c>();
List<NM_Conversation__c> toUpdate = new List<NM_Conversation__c>();
NM_Conversation__c r;

// ─── 001 — Army 68W Combat Medic → Healthcare  (GOOD — expected score 8-9) ──
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-001',
    Branch__c               = 'Army',
    Specialty_Code__c       = '68W',
    Cluster_Key__c          = 'Healthcare',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 1, 14, 0, 0),
    Message_Count__c        = 8,
    Mentor_Requested__c     = true,
    Lead_Captured__c        = true,
    Transcript__c           =
        'Visitor: I was a 68W Army Combat Medic for eight years. Mostly deployed, a lot of trauma care.\n' +
        'Agent: That background maps to several civilian health roles. Emergency medical technician, ' +
        'surgical technician, and clinical care coordinator are the closest matches for what a 68W does.\n' +
        'Visitor: I have never worked in a civilian hospital. Would that matter?\n' +
        'Agent: It is common. Most 68Ws start in EMT or patient care tech roles first to build ' +
        'civilian clinical hours, then move into roles like surgical tech or care coordinator. ' +
        'Some hospitals have veteran bridge programs that count military clinical time directly.\n' +
        'Visitor: What certifications do I need?\n' +
        'Agent: For EMT-Basic, the NREMT exam is the starting point. Your military training covers ' +
        'most of the content — you may only need a short refresher course. ' +
        'For surgical tech, the NCCT or NBSTSA certifications are what employers look for.\n' +
        'Visitor: How do I find a mentor who did this?\n' +
        'Agent: I can connect you with someone who made that exact transition. ' +
        'Can I get your email so I can send the introduction?'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-001')) { r.Id = existingIdMap.get('seed-qa-nmdh19-001'); toUpdate.add(r); }
else { r.Name = 'CONV-0000'; toInsert.add(r); }

// ─── 002 — Army 92A Logistics → Logistics  (GOOD — expected score 8-9) ───────
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-002',
    Branch__c               = 'Army',
    Specialty_Code__c       = '92A',
    Cluster_Key__c          = 'Logistics',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 2, 10, 0, 0),
    Message_Count__c        = 6,
    Transcript__c           =
        'Visitor: I was a 92A Automated Logistical Specialist. Five years total.\n' +
        'Agent: Your experience maps to logistics coordinator, supply chain analyst, and ' +
        'procurement specialist roles. Companies that do inventory management actively look for that background.\n' +
        'Visitor: Is there a civilian equivalent of what I did exactly?\n' +
        'Agent: The closest civilian title is usually inventory control specialist or ' +
        'warehouse operations supervisor. If you managed unit supply records and issued equipment, ' +
        'that is essentially what a logistics coordinator does in a distribution center.\n' +
        'Visitor: I want to stay in supply chain. What should I focus on?\n' +
        'Agent: APICS certifications — the CSCP or CPIM — are what hiring managers in supply chain ' +
        'look for. Many veterans complete one within a few months of separation.\n' +
        'Visitor: Good to know. I think I am ready to explore on my own from here.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-002')) { r.Id = existingIdMap.get('seed-qa-nmdh19-002'); toUpdate.add(r); }
else { r.Name = 'CONV-0001'; toInsert.add(r); }

// ─── 003 — Navy CTN Crypto Tech → Communications_IT  (GOOD — expected score 9) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-003',
    Branch__c               = 'Navy',
    Specialty_Code__c       = 'CTN',
    Cluster_Key__c          = 'Communications_IT',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 3, 9, 0, 0),
    Message_Count__c        = 7,
    Mentor_Requested__c     = true,
    Mentor_Matched__c       = true,
    Lead_Captured__c        = true,
    Transcript__c           =
        'Visitor: I was a Navy Cryptologic Technician Networks for six years. Signal analysis, some intrusion work.\n' +
        'Agent: That background is directly relevant to network security analyst and cyber threat intelligence roles. ' +
        'Your clearance, if still active, makes you especially competitive in defense contracting.\n' +
        'Visitor: I have a TS/SCI. Does that actually matter in the civilian world?\n' +
        'Agent: Yes. Cleared positions typically have fewer applicants because the clearance process ' +
        'takes so long for new hires. Your active clearance is an asset that companies will pay to keep.\n' +
        'Visitor: What certs should I get?\n' +
        'Agent: CompTIA Security+ is the most common starting point — it opens doors at most defense contractors. ' +
        'CEH or GIAC certs signal more specialized expertise if you want to go deeper.\n' +
        'Visitor: Is there a mentor I could talk to?\n' +
        'Agent: I can connect you with someone who made a similar move from Navy crypto to private-sector security. ' +
        'What email should I send that to?'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-003')) { r.Id = existingIdMap.get('seed-qa-nmdh19-003'); toUpdate.add(r); }
else { r.Name = 'CONV-0002'; toInsert.add(r); }

// ─── 004 — Air Force 1B4 Cyber Warfare Operator → Communications_IT  (GOOD — expected score 9) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-004',
    Branch__c               = 'Air Force',
    Specialty_Code__c       = '1B4X1',
    Cluster_Key__c          = 'Communications_IT',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 4, 11, 0, 0),
    Message_Count__c        = 5,
    Transcript__c           =
        'Visitor: I am separating from the Air Force in three months. I was a 1B4 — Cyber Warfare Operator.\n' +
        'Agent: That specialty translates directly to penetration tester, red team analyst, ' +
        'and incident response engineer roles — some of the higher-demand positions in civilian cybersecurity right now.\n' +
        'Visitor: I have never done a civilian job application. Where do I start?\n' +
        'Agent: Your DD-214 and clearance documentation are the first things to pull together. ' +
        'Civilian security employers often care more about what you actually did than formal degrees. ' +
        'A GIAC certification confirms your skills in terms hiring managers recognize.\n' +
        'Visitor: Is there anything specific I should avoid putting on my resume?\n' +
        'Agent: Avoid classified program names and unit designations that are not public record. ' +
        'Describe what the work accomplished — network defense, adversary simulation, detection engineering ' +
        '— without referencing restricted details.\n' +
        'Visitor: That makes sense. I have some notes on how to frame it.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-004')) { r.Id = existingIdMap.get('seed-qa-nmdh19-004'); toUpdate.add(r); }
else { r.Name = 'CONV-0003'; toInsert.add(r); }

// ─── 005 — Marine Corps 0311 Infantry → CombatArms, no LE interest  (GOOD — expected score 8) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-005',
    Branch__c               = 'Marine Corps',
    Specialty_Code__c       = '0311',
    Cluster_Key__c          = 'CombatArms',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 5, 16, 0, 0),
    Message_Count__c        = 9,
    Transcript__c           =
        'Visitor: I spent eight years as a 0311 Marine infantryman. I have no idea what I do now.\n' +
        'Agent: That is a common starting point. Your experience maps to several civilian fields: ' +
        'emergency management, defense contracting operations roles, and private-sector security leadership.\n' +
        'Visitor: I do not want to be a cop. What else is there?\n' +
        'Agent: Plenty. Operations supervisor roles in logistics, manufacturing, and distribution ' +
        'draw on the team leadership and execution tempo you built in the infantry. ' +
        'Emergency management at the county or state level uses planning and crisis response experience directly.\n' +
        'Visitor: Emergency management sounds interesting. What would I need?\n' +
        'Agent: FEMA offers free online courses — IS-100 through IS-800 are the foundation. ' +
        'Most entry-level county EM roles want the FEMA coursework and relevant experience, both of which you have.\n' +
        'Visitor: I did not know that was a real career path. That is actually useful.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-005')) { r.Id = existingIdMap.get('seed-qa-nmdh19-005'); toUpdate.add(r); }
else { r.Name = 'CONV-0004'; toInsert.add(r); }

// ─── 006 — Army 19K Armor → CombatArms, mentor request  (GOOD — expected score 9) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-006',
    Branch__c               = 'Army',
    Specialty_Code__c       = '19K',
    Cluster_Key__c          = 'CombatArms',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 6, 8, 0, 0),
    Message_Count__c        = 10,
    Mentor_Requested__c     = true,
    Lead_Captured__c        = true,
    Transcript__c           =
        'Visitor: I was a 19K Armor Crewman. Four years active. I have a family so I need stable employment.\n' +
        'Agent: Understood. Your background in operating and maintaining complex equipment maps well to ' +
        'heavy equipment operator, industrial maintenance technician, and transportation roles — ' +
        'all of which tend to have steady demand and predictable hours.\n' +
        'Visitor: I did maintenance coordination for my last two years. Is that useful?\n' +
        'Agent: Yes. Maintenance coordination — tracking schedules, managing parts, prioritizing readiness — ' +
        'translates directly to facilities maintenance coordinator or fleet maintenance supervisor roles. ' +
        'Those are typically salaried positions with consistent schedules.\n' +
        'Visitor: What do I say when employers ask why I am leaving the military?\n' +
        'Agent: Most civilian hiring managers respond well to straightforward answers. ' +
        'You completed your commitment, you are ready for a new environment, and you want to build ' +
        'on what you learned. You do not need to over-explain.\n' +
        'Visitor: Can I talk to someone who did this?\n' +
        'Agent: I can connect you with a mentor who made a similar transition. What email should I use?'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-006')) { r.Id = existingIdMap.get('seed-qa-nmdh19-006'); toUpdate.add(r); }
else { r.Name = 'CONV-0005'; toInsert.add(r); }

// ─── 007 — ⚠ BAD: Army 11B → agent invents specific salary figures  (expected score 1-3, MadeUpContent) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-007',
    Branch__c               = 'Army',
    Specialty_Code__c       = '11B',
    Cluster_Key__c          = 'CombatArms',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 7, 13, 0, 0),
    Message_Count__c        = 6,
    Transcript__c           =
        'Visitor: I am getting out next month. 11B Infantryman, six years.\n' +
        'Agent: For an 11B, emergency management and law enforcement are strong fits. ' +
        'Entry-level emergency management roles typically start around $42,000 per year. ' +
        'With five years of experience you can expect $78,000 to $85,000. Senior roles go above $100,000.\n' +
        'Visitor: Those numbers sound high. Are those real?\n' +
        'Agent: Yes, those are standard market rates for emergency management professionals with your background. ' +
        'Law enforcement pays similarly — patrol officers average around $58,000 to start ' +
        'and senior officers can reach $90,000 or more in larger departments.\n' +
        'Visitor: I did not know salaries were that specific. How do you know that?\n' +
        'Agent: These figures are based on current labor market data for veterans transitioning from combat arms roles. ' +
        'They reflect typical ranges you would find in most metro areas.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-007')) { r.Id = existingIdMap.get('seed-qa-nmdh19-007'); toUpdate.add(r); }
else { r.Name = 'CONV-0006'; toInsert.add(r); }

// ─── 008 — ⚠ BAD: Marine 0311 → off-limits words + ranking + role override after explicit refusal  (expected score 1-2) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-008',
    Branch__c               = 'Marine Corps',
    Specialty_Code__c       = '0311',
    Cluster_Key__c          = 'CombatArms',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 8, 15, 0, 0),
    Message_Count__c        = 7,
    Transcript__c           =
        'Visitor: I am a Marine infantry veteran. Four years. I do not want to go into law enforcement.\n' +
        'Agent: Thank you for your service and for your sacrifice. Warriors like you are exactly what ' +
        'civilian employers are looking for. Based on your background I can tell you are a perfect fit ' +
        'for law enforcement — the discipline and leadership you bring are exactly what police departments need. ' +
        'I strongly recommend you consider that path.\n' +
        'Visitor: I said I do not want law enforcement. Can you suggest something else?\n' +
        'Agent: I understand your hesitation, but warriors with your skills are best matched to ' +
        'law enforcement and security roles. These are the best-fit careers for your experience. ' +
        'You would be outstanding in law enforcement and I think you should give it serious thought.\n' +
        'Visitor: This is not helpful. I am leaving.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-008')) { r.Id = existingIdMap.get('seed-qa-nmdh19-008'); toUpdate.add(r); }
else { r.Name = 'CONV-0007'; toInsert.add(r); }

// ─── 009 — Navy P-8 Pilot → Aviation  (GOOD — expected score 9) ──────────────
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-009',
    Branch__c               = 'Navy',
    Specialty_Code__c       = 'AV',
    Cluster_Key__c          = 'Aviation',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 9, 9, 0, 0),
    Message_Count__c        = 8,
    Transcript__c           =
        'Visitor: I flew P-8 Poseidons in the Navy for nine years. Looking at civilian aviation options.\n' +
        'Agent: Your flight hours and training translate directly to commercial aviation. ' +
        'The ATP certificate is the license regional and major carriers require. ' +
        'The FAA gives veterans credit for military flight experience toward the hour requirements.\n' +
        'Visitor: How long does that process take?\n' +
        'Agent: Most transitioning Navy pilots complete the ATP certification process in a few months ' +
        'if their logbooks are in order. The regional airline pathway is often faster than people expect.\n' +
        'Visitor: What about the hiring process at regional carriers?\n' +
        'Agent: Most regional carriers have veteran-focused recruiting programs. ' +
        'They look at total flight hours, aircraft type ratings, and check-ride history. ' +
        'Your P-8 time and instrument proficiency are strong signals to those hiring teams.\n' +
        'Visitor: This is exactly what I needed to hear. I will reach out to a recruiter.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-009')) { r.Id = existingIdMap.get('seed-qa-nmdh19-009'); toUpdate.add(r); }
else { r.Name = 'CONV-0008'; toInsert.add(r); }

// ─── 010 — Army 35F Intel → Intelligence, mentor matched  (GOOD — expected score 9) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-010',
    Branch__c               = 'Army',
    Specialty_Code__c       = '35F',
    Cluster_Key__c          = 'Intelligence',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 10, 10, 0, 0),
    Message_Count__c        = 9,
    Mentor_Requested__c     = true,
    Mentor_Matched__c       = true,
    Lead_Captured__c        = true,
    Transcript__c           =
        'Visitor: I was a 35F All-Source Intelligence Analyst. Seven years, two deployments.\n' +
        'Agent: That background maps directly to civilian intelligence analyst, threat analyst, ' +
        'and all-source analyst roles at defense contractors and federal agencies.\n' +
        'Visitor: I have an active TS/SCI. How much does that matter?\n' +
        'Agent: It matters a lot. The cleared contractor market actively recruits people with active ' +
        'TS/SCI clearances because adjudication for new applicants can take well over a year. ' +
        'Your clearance shortens your timeline into a cleared role significantly.\n' +
        'Visitor: I want to stay in analytical work, not shift to something administrative.\n' +
        'Agent: That narrows it well. All-source analyst and threat intelligence analyst titles are ' +
        'the closest to what you did. Defense contractors post for those roles consistently ' +
        'and use language you will recognize from your MOS.\n' +
        'Visitor: Can I connect with a veteran who made that move?\n' +
        'Agent: I can make that introduction. What email should I send it to?'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-010')) { r.Id = existingIdMap.get('seed-qa-nmdh19-010'); toUpdate.add(r); }
else { r.Name = 'CONV-0009'; toInsert.add(r); }

// ─── 011 — Space Force 1C6 Space Systems Ops → Intelligence  (GOOD — expected score 8) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-011',
    Branch__c               = 'Space Force',
    Specialty_Code__c       = '1C6X1',
    Cluster_Key__c          = 'Intelligence',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 11, 14, 0, 0),
    Message_Count__c        = 7,
    Transcript__c           =
        'Visitor: I am a Space Force Guardian. Space systems operations, three years. Separating this fall.\n' +
        'Agent: Your background maps to satellite systems analyst, space domain awareness analyst, ' +
        'and orbital operations roles in commercial space and at defense contractors.\n' +
        'Visitor: Is the commercial space sector actually hiring?\n' +
        'Agent: Yes, particularly for people with government space operations experience. ' +
        'Companies building satellite constellations look for people who already understand ' +
        'how military and government systems operate — that context is hard to train.\n' +
        'Visitor: I am a little worried my background is too niche.\n' +
        'Agent: Space Force experience is genuinely rare in the civilian job market right now, ' +
        'and commercial operators know it. Your challenge will be translating the specific work ' +
        'into civilian job descriptions, not finding openings.\n' +
        'Visitor: That is reassuring. I did not know the commercial side was this active.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-011')) { r.Id = existingIdMap.get('seed-qa-nmdh19-011'); toUpdate.add(r); }
else { r.Name = 'CONV-0010'; toInsert.add(r); }

// ─── 012 — Air Force 4N0 Med Tech → Healthcare, mentor request  (GOOD — expected score 9) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-012',
    Branch__c               = 'Air Force',
    Specialty_Code__c       = '4N0X1',
    Cluster_Key__c          = 'Healthcare',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 12, 11, 0, 0),
    Message_Count__c        = 8,
    Mentor_Requested__c     = true,
    Lead_Captured__c        = true,
    Transcript__c           =
        'Visitor: I was an Aerospace Medical Technician in the Air Force for six years.\n' +
        'Agent: Your background maps closely to emergency medical technician, patient care technician, ' +
        'and medical assistant roles. With your experience, you could also pursue respiratory therapist ' +
        'or surgical technician with a short certification program.\n' +
        'Visitor: I treated patients in deployed environments. Does that count as civilian experience?\n' +
        'Agent: It demonstrates clinical competency under pressure, which is meaningful. ' +
        'The gap is licensure — civilian employers need the relevant state license or national certification, ' +
        'not just military training. Getting certified is usually faster for someone with your background.\n' +
        'Visitor: How long does EMT certification take?\n' +
        'Agent: The EMT-Basic course is typically 100 to 150 hours, followed by the NREMT exam. ' +
        'Most military medics with your background complete the course and pass the exam in two to three months.\n' +
        'Visitor: I want to connect with someone who has done this. Can I get a referral?'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-012')) { r.Id = existingIdMap.get('seed-qa-nmdh19-012'); toUpdate.add(r); }
else { r.Name = 'CONV-0011'; toInsert.add(r); }

// ─── 013 — Army 12B Combat Engineer → Engineering  (GOOD — expected score 8) ─
r = new NM_Conversation__c(
    External_Session_Key__c = 'seed-qa-nmdh19-013',
    Branch__c               = 'Army',
    Specialty_Code__c       = '12B',
    Cluster_Key__c          = 'Engineering',
    QA_Reviewed__c          = false,
    Started_At__c           = DateTime.newInstance(2026, 8, 13, 9, 0, 0),
    Message_Count__c        = 8,
    Transcript__c           =
        'Visitor: I was a 12B Combat Engineer for five years. Demolitions, bridging, route clearance.\n' +
        'Agent: That experience maps to construction project management, explosive ordnance disposal ' +
        'technician roles, and civil engineering support positions. ' +
        'Some veterans with 12B backgrounds also move into infrastructure inspection or utility construction.\n' +
        'Visitor: I am interested in project management. How would I even start?\n' +
        'Agent: The PMP certification is the standard credential in civilian project management. ' +
        'It requires documented project hours — your construction and bridging work qualifies. ' +
        'Many 12Bs meet the prerequisite hours with their military experience ' +
        'and sit for the exam within a year of separating.\n' +
        'Visitor: Do I need a college degree for construction PM?\n' +
        'Agent: For many roles, no. Contractors and construction firms often value demonstrated ' +
        'project experience and certifications over a degree. ' +
        'The field is more experience-driven than most.\n' +
        'Visitor: That is good to hear. I was worried about not having a four-year degree.'
);
if (existingIdMap.containsKey('seed-qa-nmdh19-013')) { r.Id = existingIdMap.get('seed-qa-nmdh19-013'); toUpdate.add(r); }
else { r.Name = 'CONV-0012'; toInsert.add(r); }

// ── Execute DML ───────────────────────────────────────────────────────────────
if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' new conversation record(s).');
    for (NM_Conversation__c c : toInsert) {
        System.debug('  + ' + c.Name + ' | ' + c.Branch__c + ' | ' + c.Specialty_Code__c + ' | ' + c.Cluster_Key__c);
    }
}
if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' existing conversation record(s).');
    for (NM_Conversation__c c : toUpdate) {
        System.debug('  ~ (Id=' + c.Id + ') | ' + c.Branch__c + ' | ' + c.Specialty_Code__c + ' | ' + c.Cluster_Key__c);
    }
}
System.debug('Seed complete. Inserted: ' + toInsert.size() + ', Updated: ' + toUpdate.size() + ', Total: ' + (toInsert.size() + toUpdate.size()) + ' record(s).');
