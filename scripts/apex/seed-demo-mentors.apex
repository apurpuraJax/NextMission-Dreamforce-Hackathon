// Seed script: 5 anonymized demo mentor records for hackathon demo
// Run: sf apex run --file scripts/apex/seed-demo-mentors.apex --target-org dreamforce-hackathon
// Safe to re-run: checks for existing records by Name before inserting

List<NM_Mentor__c> toInsert = new List<NM_Mentor__c>();

Map<String, NM_Mentor__c> existing = new Map<String, NM_Mentor__c>();
for (NM_Mentor__c m : [SELECT Name FROM NM_Mentor__c WHERE Name IN ('Alex R.','Jordan M.','Morgan T.','Casey W.','Taylor B.')]) {
    existing.put(m.Name, m);
}

List<NM_Mentor__c> desired = new List<NM_Mentor__c>{
    new NM_Mentor__c(
        Name = 'Alex R.',
        Branch__c = 'Army',
        Specialty_Cluster__c = 'Logistics',
        Civilian_Role__c = 'Supply Chain Manager',
        Employer__c = 'Meridian Distribution Co.',
        Years_Since_Transition__c = 4,
        Bio__c = 'I spent 9 years managing logistics for a forward support battalion. When I got out, I moved into civilian supply chain and never looked back. The planning and problem-solving skills transferred directly. Happy to talk through what that shift looks like.',
        Contact_Email__c = 'alex.r.demo@example.com',
        Active__c = true
    ),
    new NM_Mentor__c(
        Name = 'Jordan M.',
        Branch__c = 'Navy',
        Specialty_Cluster__c = 'Communications_IT',
        Civilian_Role__c = 'Network Security Engineer',
        Employer__c = 'Halcyon Systems',
        Years_Since_Transition__c = 6,
        Bio__c = 'I was a Cryptologic Technician for eight years. After separating I earned a CompTIA Security+ and landed a network security role within six months. The hardest part was learning to describe what I did in civilian terms — that is exactly what I can help with.',
        Contact_Email__c = 'jordan.m.demo@example.com',
        Active__c = true
    ),
    new NM_Mentor__c(
        Name = 'Morgan T.',
        Branch__c = 'Air Force',
        Specialty_Cluster__c = 'Healthcare',
        Civilian_Role__c = 'Respiratory Therapist',
        Employer__c = 'Westbrook Regional Medical Center',
        Years_Since_Transition__c = 3,
        Bio__c = 'I worked as an aerospace medical technician for 6 years. Getting a civilian license took some extra coursework, but the clinical experience I had from the Air Force gave me a real head start. I can walk you through how that licensure path works.',
        Contact_Email__c = 'morgan.t.demo@example.com',
        Active__c = true
    ),
    new NM_Mentor__c(
        Name = 'Casey W.',
        Branch__c = 'Marine Corps',
        Specialty_Cluster__c = 'CombatArms',
        Civilian_Role__c = 'Law Enforcement Officer',
        Employer__c = 'Ashford County Sheriff\'s Office',
        Years_Since_Transition__c = 5,
        Bio__c = 'I was an 0311 infantry rifleman. When I got out, law enforcement was a natural fit — the discipline, judgment under pressure, and team dynamic were already there. I went through the academy and made sergeant in three years. Let me know if you want to talk through how that transition looks.',
        Contact_Email__c = 'casey.w.demo@example.com',
        Active__c = true
    ),
    new NM_Mentor__c(
        Name = 'Taylor B.',
        Branch__c = 'Space Force',
        Specialty_Cluster__c = 'Intelligence',
        Civilian_Role__c = 'Intelligence Analyst',
        Employer__c = 'Clearpath Analytics Group',
        Years_Since_Transition__c = 2,
        Bio__c = 'I was a Space Systems Operations specialist. After separating I moved into an intelligence analyst role at a defense contractor — my clearance and analytical background made me a strong candidate. I am still pretty new to the civilian side but happy to share what the first two years have looked like.',
        Contact_Email__c = 'taylor.b.demo@example.com',
        Active__c = true
    )
};

for (NM_Mentor__c m : desired) {
    if (!existing.containsKey(m.Name)) {
        toInsert.add(m);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' demo mentor records.');
} else {
    System.debug('All demo mentor records already exist — no inserts needed.');
}
